pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { BridgeRouter } from "../../contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol";
import { XDaiBridgePeripheral } from "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol";
import { MockContractReceiver } from "../../contracts/mocks/MockContractReceiver.sol";
import { IOmnibridge } from "./interfaces/IOmnibridge.sol";
import { SetupTest } from "./Setup.t.sol";



contract BridgeRouterTest is SetupTest {
    BridgeRouter router;
    XDaiBridgePeripheral peripheral;
    TransparentUpgradeableProxy routerProxy;
    address public FOREIGN_OMNIBRIDGE = 0x88ad09518695c6c3712AC10a214bE5109a655671;
    address public FOREIGN_AMB = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
    address public FOREIGN_XDAIBRIDGE = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public payable override {
        super.setUp();
        vm.startPrank(bridgeOwner);
        router = new BridgeRouter();
       
        routerProxy = new TransparentUpgradeableProxy(
            address(router),
            bridgeOwner,
            abi.encodeWithSignature("initialize()")
        );
        router = BridgeRouter(address(routerProxy));
        assertEq(router.owner(), bridgeOwner);

        peripheral = new XDaiBridgePeripheral(address(routerProxy));

        router.setRoute(address(DAI), address(peripheral));
        router.setRoute(address(USDS), FOREIGN_XDAIBRIDGE);

        upgradeAndInitializeInterest();
        vm.stopPrank();
    }

    function testRouteMetadata() public {
        assertEq(router.tokenRoutes(address(DAI)), address(peripheral));
        assertEq(router.tokenRoutes(address(USDS)), FOREIGN_XDAIBRIDGE);
    }

    function testFuzzRelayDaiToken(uint256 amount) public {
        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx());
        vm.assume(bridge.withinLimit(amount));

        deal(address(DAI), alice, amount);

        uint256 aliceInitialDaiBalance = DAI.balanceOf(alice);
        uint256 bridgeInitialDaiBalance = DAI.balanceOf(bridgeAddress);
        uint256 bridgeInitialUsdsBalance = USDS.balanceOf(bridgeAddress);

        vm.startPrank(alice);

        DAI.approve(address(router), amount);
        router.relayTokens(address(DAI), bob, amount);

        vm.stopPrank();

        assertEq(DAI.balanceOf(alice), aliceInitialDaiBalance - amount);
        assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalance);
        assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalance + amount);

    }

    function testFuzzRelayUSDSToken(uint256 amount) public {
        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx());
        vm.assume(bridge.withinLimit(amount));
        
        deal(address(USDS), alice, amount);

        uint256 aliceInitialUsdsBalance = USDS.balanceOf(alice);
        uint256 bridgeInitialUsdsBalance = USDS.balanceOf(bridgeAddress);

        vm.startPrank(alice);

        USDS.approve(address(router), amount);
        router.relayTokens(address(USDS), bob, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), aliceInitialUsdsBalance - amount);
        assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalance + amount);

    }

    function testFuzzRelayGNO(uint256 amount) public {

        amount = bound(amount, 1 ether, 1e30);
        vm.assume(IOmnibridge(FOREIGN_OMNIBRIDGE).withinLimit(address(GNO), amount));
        deal(address(GNO), alice, amount);
        uint256 aliceInitialGNOBalance = GNO.balanceOf(alice);
        uint256 omnibridgeInitialGNOBalance = GNO.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.startPrank(alice);

        GNO.approve(address(router), amount);
        router.relayTokens(address(GNO), bob, amount);

        vm.stopPrank();

        assertEq(GNO.balanceOf(alice), aliceInitialGNOBalance - amount);
        assertEq(GNO.balanceOf(FOREIGN_OMNIBRIDGE), omnibridgeInitialGNOBalance + amount);

    }

    function testFuzzRelayETH(uint256 amount) public payable {

        amount = bound(amount, 1, IOmnibridge(FOREIGN_OMNIBRIDGE).dailyLimit(address(WETH)));
        vm.assume(IOmnibridge(FOREIGN_OMNIBRIDGE).withinLimit(address(WETH), amount));

        deal(alice, amount);
        IERC20 weth = IERC20(WETH);

        uint256 aliceInitialBalance = amount;
        uint256 omnibridgeInitialBalance = weth.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.prank(alice);
        router.relayTokens{value: amount}(address(0), bob, amount);

        assertEq(alice.balance, aliceInitialBalance - amount);
        assertEq(weth.balanceOf(FOREIGN_OMNIBRIDGE),  omnibridgeInitialBalance + amount);


    }

    function testFuzzExecuteSignature(uint256 amount) public {
        amount = bound(amount, 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));
        addMockValidator();
        
        bytes32 xdaiBridgeNonce = bytes32(uint256(20000000));

        uint256 aliceInitialUsdsBalance = USDS.balanceOf(alice);
        uint256 bridgeInitialUsdsBalance = USDS.balanceOf(bridgeAddress);

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            xdaiBridgeNonce,
            bridgeAddress,
            validatorPk
        );

        vm.prank(alice);
        router.executeSignatures(message, signatures);

        assertEq(USDS.balanceOf(alice), aliceInitialUsdsBalance + amount);
        if (amount > bridge.minCashThreshold(address(USDS))) {
            assertEq(USDS.balanceOf(bridgeAddress), bridge.minCashThreshold(address(USDS)));

        } else {
            assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalance - amount);

        }

    }

    function testFuzzExecuteSignatureAndGetDai(uint256 amount) public {
        amount = bound(amount, 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));
        addMockValidator();
         
        bytes32 xdaiBridgeNonce = bytes32(uint256(20000000));
        uint256 aliceInitialDaiBalance = DAI.balanceOf(alice);

       

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            alice,
            amount,
            xdaiBridgeNonce,
            bridgeAddress,
            validatorPk
        );

        uint256 nonce = USDS.nonces(alice);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                USDS.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        USDS.PERMIT_TYPEHASH(),
                        alice,
                        address(peripheral),
                        amount,
                        nonce,
                        block.timestamp + 1 days
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        bytes memory permitSignatures = abi.encodePacked(r, s, v);

        router.executeSignaturesAndSwapToDai(message, signatures, permitSignatures);

        assertEq(DAI.balanceOf(alice), aliceInitialDaiBalance + amount);

    }


    function testFuzzExecuteSignatureAndGetDaiWithSmartContractWallet(uint256 amount) public {
        amount = bound(amount, 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));
        addMockValidator();

        MockContractReceiver mockContractReceiver = new MockContractReceiver();
        uint256 receiverInitialDaiBalance = 1e20;

        deal(address(DAI), address(mockContractReceiver), receiverInitialDaiBalance);

        bytes32 xdaiBridgeNonce = bytes32(uint256(20000000));

        (bytes memory message, bytes memory signatures) = getMessageAndSignatures(
            address(mockContractReceiver),
            amount,
            xdaiBridgeNonce,
            bridgeAddress,
            validatorPk
        );

        uint256 nonce = USDS.nonces(address(mockContractReceiver));

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                USDS.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        USDS.PERMIT_TYPEHASH(),
                        address(mockContractReceiver),
                        address(peripheral),
                        amount,
                        nonce,
                        block.timestamp + 1 days
                    )
                )
            )
        );

        bytes memory permitSignatures = '0x00'; 

        router.executeSignaturesAndSwapToDai(message, signatures, permitSignatures);

        assertEq(DAI.balanceOf(address(mockContractReceiver)), receiverInitialDaiBalance + amount);

    }

    function testRecoverLockedFund(uint256 amount) public{

        vm.assume(amount>0);
        deal(address(USDS), alice, amount);
        vm.deal(alice, amount);

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

}
