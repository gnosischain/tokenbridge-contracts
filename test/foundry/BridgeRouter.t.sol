// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {SetupTest} from "./Setup.t.sol";
import {BridgeRouter} from "../../contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol";
import {XDaiBridgePeripheral} from "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol";
import {XDaiBridgePeripheralForDaiPreUsdsUpgrade} from
    "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol";
import {XDaiBridgePeripheralForUsdsPreUsdsUpgrade} from
    "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol";
import {IOmnibridge} from "./interfaces/IOmnibridge.sol";

// Require fork-url to run the test on Ethereum
// Run forge test --match-contract BridgeRouterTest --fork-url $RPC_MAINNET
contract BridgeRouterTest is SetupTest {
    BridgeRouter router;
    XDaiBridgePeripheral peripheral;
    XDaiBridgePeripheralForDaiPreUsdsUpgrade peripheralForDAIPreUSDSUpgrade;
    XDaiBridgePeripheralForUsdsPreUsdsUpgrade peripheralForUSDSPreUSDSUpgrade;
    TransparentUpgradeableProxy routerProxy;
    ProxyAdmin proxyAdmin;
    address public FOREIGN_OMNIBRIDGE = 0x88ad09518695c6c3712AC10a214bE5109a655671;
    address public FOREIGN_AMB = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
    address public FOREIGN_XDAIBRIDGE = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    bytes32 implementationSlot = vm.load(address(routerProxy), ERC1967Utils.IMPLEMENTATION_SLOT);
    bytes32 adminSlot = vm.load(address(routerProxy), ERC1967Utils.ADMIN_SLOT);

    function setUp() public payable override {
        super.setUp();
        vm.startPrank(bridgeOwner);
        router = new BridgeRouter();
        address routerImplAddress = address(router);

        routerProxy = new TransparentUpgradeableProxy(
            address(router), bridgeOwner, abi.encodeWithSignature("initialize(address)", bridgeOwner)
        );
        router = BridgeRouter(address(routerProxy));
        implementationSlot = vm.load(address(routerProxy), ERC1967Utils.IMPLEMENTATION_SLOT);
        adminSlot = vm.load(address(routerProxy), ERC1967Utils.ADMIN_SLOT);
        // dev: new proxy Admin contract that is deployed during TransparentUpgradeableProxy contract deployment
        proxyAdmin = ProxyAdmin(0xb1d655Ab5C2CDF913979a399836aAE18DD711Faa);

        assertEq(router.owner(), bridgeOwner, "invalid router owner");
        assertEq(address(uint160(uint256(implementationSlot))), routerImplAddress, "invalid implementation");
        assertEq(proxyAdmin.owner(), bridgeOwner, "invalid proxy admin owner ");
        assertEq(address(uint160(uint256(adminSlot))), address(proxyAdmin), "invalid admin slot");

        peripheral = new XDaiBridgePeripheral(address(routerProxy));
        peripheralForDAIPreUSDSUpgrade = new XDaiBridgePeripheralForDaiPreUsdsUpgrade(address(routerProxy));
        peripheralForUSDSPreUSDSUpgrade = new XDaiBridgePeripheralForUsdsPreUsdsUpgrade(address(routerProxy));

        vm.startPrank(bridgeOwner);
        router.setRoute(address(DAI), address(peripheralForDAIPreUSDSUpgrade));
        router.setRoute(address(USDS), address(peripheralForUSDSPreUSDSUpgrade));
        vm.stopPrank();
    }


    function testRouterMetadata() public {
        // Pre USDS bridge upgrade
        assertEq(router.tokenRoutes(address(DAI)), address(peripheralForDAIPreUSDSUpgrade));
        assertEq(router.tokenRoutes(address(USDS)), address(peripheralForUSDSPreUSDSUpgrade));

        upgradeBridgeAndSetupRoute();

        // Post USDS bridge upgrade
        assertEq(router.tokenRoutes(address(DAI)), address(peripheral));
        assertEq(router.tokenRoutes(address(USDS)), FOREIGN_XDAIBRIDGE);
    }

    function testRouterUpgrade() public {
        upgradeBridgeAndSetupRoute();
        BridgeRouter newRouterImpl = new BridgeRouter();

        vm.prank(bridgeOwner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(routerProxy)), address(newRouterImpl), "");

        // To make sure the same address can be used for proxy owner and the router owner
        vm.prank(bridgeOwner);
        router.setRoute(address(DAI), address(peripheralForDAIPreUSDSUpgrade));

        implementationSlot = vm.load(address(routerProxy), ERC1967Utils.IMPLEMENTATION_SLOT);
        adminSlot = vm.load(address(routerProxy), ERC1967Utils.ADMIN_SLOT);

        assertEq(router.owner(), bridgeOwner, "invalid router owner");
        assertEq(proxyAdmin.owner(), bridgeOwner, "invalid proxy admin owner ");
        assertEq(address(uint160(uint256(adminSlot))), address(proxyAdmin), "invalid admin slot");
        assertEq(address(uint160(uint256(implementationSlot))), address(newRouterImpl), "invalid implementation");
    }

    function testFuzzRelayDAIToken(uint256 amount) public {
        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx());
        vm.assume(bridge.withinLimit(amount));

        deal(address(DAI), alice, amount * 2);

        // Pre USDS Upgrade

        uint256 initialAliceDAIBalancePre = DAI.balanceOf(alice);
        uint256 initialBridgeDAIBalancePre = DAI.balanceOf(bridgeAddress);
        uint256 initialBridgeUSDSBalancePre = USDS.balanceOf(bridgeAddress);

        vm.startPrank(alice);

        DAI.approve(address(router), amount);
        router.relayTokens(address(DAI), bob, amount);

        vm.stopPrank();

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalancePre - amount);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalancePre + amount);
        assertEq(USDS.balanceOf(bridgeAddress), initialBridgeUSDSBalancePre);

        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBridgeAndSetupRoute();
        // Post USDS Upgrade

        uint256 initialAliceDAIBalancePost = DAI.balanceOf(alice);
        uint256 initialBridgeDAIBalancePost = DAI.balanceOf(bridgeAddress);
        uint256 initialBridgeUSDSBalancePost = USDS.balanceOf(bridgeAddress);

        vm.startPrank(alice);

        DAI.approve(address(router), amount);
        router.relayTokens(address(DAI), bob, amount);

        vm.stopPrank();

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalancePost - amount);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalancePost);
        assertEq(USDS.balanceOf(bridgeAddress), initialBridgeUSDSBalancePost + amount);
    }

    function testFuzzRelayUSDSToken(uint256 amount) public {
        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx());
        vm.assume(bridge.withinLimit(amount));

        deal(address(USDS), alice, amount * 2);

        // Pre USDS upgrade
        // Route for USDS is not set yet, peripheral contract will swap USDS to DAI and send to xDAI Bridge
        uint256 initialAliceUSDSBalancePre = USDS.balanceOf(alice);
        uint256 initialBridgeUSDSBalancePre = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalancePre = DAI.balanceOf(bridgeAddress);
        uint256 routerInitialUSDSBalancePre = USDS.balanceOf(address(router));
        uint256 routerInitialDAIBalancePre = DAI.balanceOf(address(router));

        vm.startPrank(alice);

        USDS.approve(address(router), amount);
        router.relayTokens(address(USDS), bob, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalancePre - amount);
        assertEq(USDS.balanceOf(bridgeAddress), initialBridgeUSDSBalancePre);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalancePre + amount);
        assertEq(USDS.balanceOf(address(router)), routerInitialUSDSBalancePre);
        assertEq(DAI.balanceOf(address(router)), routerInitialDAIBalancePre);

        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBridgeAndSetupRoute();

        uint256 initialAliceUSDSBalancePost = USDS.balanceOf(alice);
        uint256 initialBridgeUSDSBalancePost = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalancePost = DAI.balanceOf(bridgeAddress);
        uint256 routerInitialUSDSBalancePost = USDS.balanceOf(address(router));
        uint256 routerInitialDAIBalancePost = DAI.balanceOf(address(router));

        vm.startPrank(alice);

        USDS.approve(address(router), amount);
        router.relayTokens(address(USDS), bob, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalancePost - amount);
        assertEq(USDS.balanceOf(bridgeAddress), initialBridgeUSDSBalancePost + amount);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalancePost);
        assertEq(USDS.balanceOf(address(router)), routerInitialUSDSBalancePost);
        assertEq(DAI.balanceOf(address(router)), routerInitialDAIBalancePost);
    }

    function testFuzzRelayGNO(uint256 amount) public {
        amount = bound(amount, 1 ether, 1e30);
        vm.assume(IOmnibridge(FOREIGN_OMNIBRIDGE).withinLimit(address(GNO), amount));
        deal(address(GNO), alice, amount * 2);

        // Pre USDS upgrade
        uint256 initialAliceGNOBalancePre = GNO.balanceOf(alice);
        uint256 omniinitialBridgeGNOBalancePre = GNO.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.startPrank(alice);

        GNO.approve(address(router), amount);
        router.relayTokens(address(GNO), bob, amount);

        vm.stopPrank();

        assertEq(GNO.balanceOf(alice), initialAliceGNOBalancePre - amount);
        assertEq(GNO.balanceOf(FOREIGN_OMNIBRIDGE), omniinitialBridgeGNOBalancePre + amount);

        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBridgeAndSetupRoute();

        // Post USDS upgrade
        uint256 initialAliceGNOBalancePost = GNO.balanceOf(alice);
        uint256 omniinitialBridgeGNOBalancePost = GNO.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.startPrank(alice);

        GNO.approve(address(router), amount);
        router.relayTokens(address(GNO), bob, amount);

        vm.stopPrank();

        assertEq(GNO.balanceOf(alice), initialAliceGNOBalancePost - amount);
        assertEq(GNO.balanceOf(FOREIGN_OMNIBRIDGE), omniinitialBridgeGNOBalancePost + amount);
    }

    function testFuzzRelayETH(uint256 amount) public payable {
        amount = bound(amount, 1, IOmnibridge(FOREIGN_OMNIBRIDGE).dailyLimit(address(WETH)));
        vm.assume(IOmnibridge(FOREIGN_OMNIBRIDGE).withinLimit(address(WETH), amount));

        deal(alice, amount * 2);
        IERC20 weth = IERC20(WETH);

        // Pre USDS Upgrade

        uint256 initialAliceBalancePre = alice.balance;
        uint256 omniinitialBridgeBalancePre = weth.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.prank(alice);
        router.relayTokens{value: amount}(address(0), bob, amount);

        assertEq(alice.balance, initialAliceBalancePre - amount);
        assertEq(weth.balanceOf(FOREIGN_OMNIBRIDGE), omniinitialBridgeBalancePre + amount);

        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBridgeAndSetupRoute();

        // Post USDS upgrade

        uint256 initialAliceBalancePost = alice.balance;
        uint256 omniinitialBridgeBalancePost = weth.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.prank(alice);
        router.relayTokens{value: amount}(address(0), bob, amount);

        assertEq(alice.balance, initialAliceBalancePost - amount);
        assertEq(weth.balanceOf(FOREIGN_OMNIBRIDGE), omniinitialBridgeBalancePost + amount);
    }

    function testFuzzExecuteSignaturesForDAIAmountLeBridgeBalance(uint256 amount) public {
        upgradeBridgeAndSetupRoute();
        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeUSDSBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);

        amount = bound(amount, 1 ether, initialBridgeUSDSBalance);
        vm.assume(bridge.withinExecutionLimit(amount));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            address(DAI),
            validatorPk,
            true
        );

        vm.prank(alice);
        router.executeSignatures(message, signatures);

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance + amount);
        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalance);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance);
        assertEq(USDS.balanceOf(bridgeAddress), initialBridgeUSDSBalance - amount);
    }

    function testFuzzExecuteSignaturesForDAIWithOldXdaiMsgAmountLeBridgeBalance(uint256 amount) public {
        upgradeBridgeAndSetupRoute();
        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeUSDSBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);

        amount = bound(amount, 1 ether, initialBridgeUSDSBalance);
        vm.assume(bridge.withinExecutionLimit(amount));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            address(0),
            validatorPk,
            true
        );

        vm.prank(alice);
        router.executeSignatures(message, signatures);

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance + amount);
        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalance);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance);
        assertEq(USDS.balanceOf(bridgeAddress), initialBridgeUSDSBalance - amount);
    }

    function testFuzzExecuteSignaturesForUSDSAmountLeBridgeBalance(uint256 amount) public {
        upgradeBridgeAndSetupRoute();
        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeUSDSBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);

        amount = bound(amount, 1 ether, initialBridgeUSDSBalance);
        vm.assume(bridge.withinExecutionLimit(amount));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            address(USDS),
            validatorPk,
            true
        );

        vm.prank(alice);
        router.executeSignatures(message, signatures);

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance);
        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalance + amount);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance);
        assertEq(USDS.balanceOf(bridgeAddress), initialBridgeUSDSBalance - amount);
    }

    function testFuzzExecuteSignaturesForDAIAmountGtBridgeBalance(uint256 amount) public {
        upgradeBridgeAndSetupRoute();
        uint256 minCashThreshold = bridge.minCashThreshold(address(USDS));
        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeUSDSBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);

        amount = bound(
            amount, initialBridgeUSDSBalance + 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress)
        );
        vm.assume(bridge.withinExecutionLimit(amount));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            address(DAI),
            validatorPk,
            true
        );

        vm.prank(alice);
        router.executeSignatures(message, signatures);

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance + amount);
        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalance);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance);
        assertEq(USDS.balanceOf(bridgeAddress), minCashThreshold);
    }

    function testFuzzExecuteSignaturesForDAIWithOldXdaiMsgAmountGtBridgeBalance(uint256 amount) public {
        upgradeBridgeAndSetupRoute();
        uint256 minCashThreshold = bridge.minCashThreshold(address(USDS));
        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeUSDSBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);

        amount = bound(
            amount, initialBridgeUSDSBalance + 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress)
        );
        vm.assume(bridge.withinExecutionLimit(amount));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            address(0),
            validatorPk,
            true
        );

        vm.prank(alice);
        router.executeSignatures(message, signatures);

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance + amount);
        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalance);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance);
        assertEq(USDS.balanceOf(bridgeAddress), minCashThreshold);
    }

    function testFuzzExecuteSignaturesForUSDSAmountGtBridgeBalance(uint256 amount) public {
        upgradeBridgeAndSetupRoute();
        uint256 minCashThreshold = bridge.minCashThreshold(address(USDS));
        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeUSDSBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);

        amount = bound(
            amount, initialBridgeUSDSBalance + 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress)
        );
        vm.assume(bridge.withinExecutionLimit(amount));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            address(USDS),
            validatorPk,
            true
        );
        require(message.length == 124);

        vm.prank(alice);
        router.executeSignatures(message, signatures);

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance, "1");
        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalance + amount, "2");
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance, "3");
        assertEq(USDS.balanceOf(bridgeAddress), minCashThreshold, "4");
    }

    function testRevertIfExecuteSignaturesWithUnsupportedToken(uint256 amount) public {
        upgradeBridgeAndSetupRoute();

        uint256 initialBridgeUSDSBalance = USDS.balanceOf(bridgeAddress);

        amount = bound(
            amount, initialBridgeUSDSBalance + 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress)
        );
        vm.assume(bridge.withinExecutionLimit(amount));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            makeAddr("Token"),
            validatorPk,
            true
        );

        vm.prank(alice);
        vm.expectRevert();
        router.executeSignatures(message, signatures);
    }

    function testRecoverLockedFund(uint256 amount) public {
        vm.assume(amount > 0);
        deal(address(USDS), alice, amount);
        deal(address(DAI), alice, amount);
        vm.deal(alice, amount);

        // Pre USDS Upgrade

        vm.startPrank(alice);
        USDS.transfer(address(router), amount);
        // router is not payable
        vm.expectRevert();
        payable(address(router)).transfer(amount);
        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), 0);
        assertEq(USDS.balanceOf(address(router)), amount);

        assertEq(alice.balance, amount);
        assertEq(address(router).balance, 0);

        vm.prank(alice);
        vm.expectRevert();
        router.recoverLockedFund(address(USDS), alice, amount);

        vm.startPrank(bridgeOwner);
        router.recoverLockedFund(address(USDS), alice, amount);
        vm.expectRevert(bytes("no enough balance to withdraw"));
        router.recoverLockedFund(address(USDS), alice, amount);
        vm.expectRevert(bytes("no enough ETH to withdraw"));
        router.recoverLockedFund(address(0), alice, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), amount);
        assertEq(USDS.balanceOf(address(router)), 0);
        assertEq(alice.balance, amount);
        assertEq(address(router).balance, 0);

        upgradeBridgeAndSetupRoute();
        // Post USDS Upgrade
        // Works as the same as pre USDS upgrade

        vm.startPrank(alice);
        USDS.transfer(address(router), amount);
        // router is not payable
        vm.expectRevert();
        payable(address(router)).transfer(amount);
        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), 0);
        assertEq(USDS.balanceOf(address(router)), amount);

        assertEq(alice.balance, amount);
        assertEq(address(router).balance, 0);

        vm.prank(alice);
        vm.expectRevert();
        router.recoverLockedFund(address(USDS), alice, amount);

        vm.startPrank(bridgeOwner);
        router.recoverLockedFund(address(USDS), alice, amount);
        vm.expectRevert(bytes("no enough balance to withdraw"));
        router.recoverLockedFund(address(USDS), alice, amount);
        vm.expectRevert(bytes("no enough ETH to withdraw"));
        router.recoverLockedFund(address(0), alice, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), amount);
        assertEq(USDS.balanceOf(address(router)), 0);
        assertEq(alice.balance, amount);
        assertEq(address(router).balance, 0);
    }

    /// The following function calls during the upgrade is a bundled Safe transaction,
    /// that will be signed and executed by [bridge governors](https://docs.gnosischain.com/bridges/management/#bridge-governance)
    function upgradeBridgeAndSetupRoute() public {
        vm.startPrank(bridgeOwner);
        router.setRoute(address(DAI), address(peripheral));
        router.setRoute(address(USDS), FOREIGN_XDAIBRIDGE);
        vm.stopPrank();

        upgradeAndInitializeInterest();
        // In production, the upgrade stops here
        // Adding mock validator here for testing purpose.
        // In production, the tx need to be signed by 4/7 [validators](https://docs.gnosischain.com/bridges/management/validators).
        addMockValidator();
    }
}
