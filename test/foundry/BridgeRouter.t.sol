pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import { TransparentUpgradeableProxy, ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { BridgeRouter } from "../../contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol";
import { XDaiBridgePeripheral } from "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol";
import { XDaiBridgePeripheralForDaiPreUsdsUpgrade } from "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol";
import { XDaiBridgePeripheralForUsdsPreUsdsUpgrade } from "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol";
import { MockContractReceiver } from "../../contracts/mocks/MockContractReceiver.sol";
import { IOmnibridge } from "./interfaces/IOmnibridge.sol";
import { SetupTest } from "./Setup.t.sol";



contract BridgeRouterTest is SetupTest {
    BridgeRouter router;
    XDaiBridgePeripheral peripheral;
    XDaiBridgePeripheralForDaiPreUsdsUpgrade peripheralForDaiPreUsdsUpgrade;
    XDaiBridgePeripheralForUsdsPreUsdsUpgrade peripheralForUsdsPreUsdsUpgrade;
    TransparentUpgradeableProxy routerProxy;
    ProxyAdmin proxyAdmin;
    address proxyAdminOwner = makeAddr("proxyAdminOwner");
    address public FOREIGN_OMNIBRIDGE = 0x88ad09518695c6c3712AC10a214bE5109a655671;
    address public FOREIGN_AMB = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
    address public FOREIGN_XDAIBRIDGE = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    bytes32 implementationSlot = vm.load(address(routerProxy), ERC1967Utils.IMPLEMENTATION_SLOT);
    bytes32 adminSlot = vm.load(address(routerProxy), ERC1967Utils.ADMIN_SLOT);
    error ClaimUsdsNotSupported();

    function setUp() public payable override {
        super.setUp();
        vm.startPrank(bridgeOwner);
        router = new BridgeRouter();
        address routerImplAddress = address(router);
       
        routerProxy = new TransparentUpgradeableProxy(
            address(router),
            proxyAdminOwner,
            abi.encodeWithSignature("initialize(address)", bridgeOwner)
        );
        router = BridgeRouter(address(routerProxy));
        implementationSlot = vm.load(address(routerProxy), ERC1967Utils.IMPLEMENTATION_SLOT);
        adminSlot = vm.load(address(routerProxy), ERC1967Utils.ADMIN_SLOT);
        // dev: new proxy Admin contract that is deployed during TransparentUpgradeableProxy contract deployment
        proxyAdmin = ProxyAdmin(0xb1d655Ab5C2CDF913979a399836aAE18DD711Faa);
       
        assertEq(router.owner(), bridgeOwner,  "invalid router owner");
        assertEq(address(uint160(uint256(implementationSlot))), routerImplAddress, "invalid implementation");
        assertEq(proxyAdmin.owner(), proxyAdminOwner, "invalid proxy admin owner ");
        assertEq(address(uint160(uint256(adminSlot))),address(proxyAdmin), "invalid admin slot");
 
        peripheral = new XDaiBridgePeripheral(address(routerProxy));
        peripheralForDaiPreUsdsUpgrade = new XDaiBridgePeripheralForDaiPreUsdsUpgrade(address(routerProxy));
        peripheralForUsdsPreUsdsUpgrade = new XDaiBridgePeripheralForUsdsPreUsdsUpgrade(address(routerProxy));

        vm.startPrank(bridgeOwner);
        router.setRoute(address(DAI), address(peripheralForDaiPreUsdsUpgrade));
        router.setRoute(address(USDS), address(peripheralForUsdsPreUsdsUpgrade));
        vm.stopPrank();

    }


    function testRouterMetadata() public {
        // Pre USDS bridge upgrade
        assertEq(router.tokenRoutes(address(DAI)), address(peripheralForDaiPreUsdsUpgrade));
        assertEq(router.tokenRoutes(address(USDS)), address(peripheralForUsdsPreUsdsUpgrade));

        upgradeBrideAndSetupRoute();

        // Post USDS bridge upgrade 
        assertEq(router.tokenRoutes(address(DAI)), address(peripheral));
        assertEq(router.tokenRoutes(address(USDS)), FOREIGN_XDAIBRIDGE);

    }

    function testRouterUpgrade() public {
        upgradeBrideAndSetupRoute();
        BridgeRouter newRouterImpl = new BridgeRouter();
       
        vm.prank(bridgeOwner);
        vm.expectRevert();
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(routerProxy)), address(newRouterImpl), "");

        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(routerProxy)), address(newRouterImpl), "");

        implementationSlot = vm.load(address(routerProxy), ERC1967Utils.IMPLEMENTATION_SLOT);
        adminSlot = vm.load(address(routerProxy), ERC1967Utils.ADMIN_SLOT);

        assertEq(router.owner(), bridgeOwner,  "invalid router owner");
        assertEq(proxyAdmin.owner(), proxyAdminOwner, "invalid proxy admin owner ");
        assertEq(address(uint160(uint256(adminSlot))),address(proxyAdmin), "invalid admin slot");
        assertEq(address(uint160(uint256(implementationSlot))), address(newRouterImpl), "invalid implementation");
        
    }


    function testFuzzRelayDaiToken(uint256 amount) public {
        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx());
        vm.assume(bridge.withinLimit(amount));

        deal(address(DAI), alice, amount * 2);

        // Pre USDS Upgrade

        uint256 aliceInitialDaiBalancePre = DAI.balanceOf(alice);
        uint256 bridgeInitialDaiBalancePre = DAI.balanceOf(bridgeAddress);
        uint256 bridgeInitialUsdsBalancePre = USDS.balanceOf(bridgeAddress);

        vm.startPrank(alice);

        DAI.approve(address(router), amount);
        router.relayTokens(address(DAI), bob, amount);

        vm.stopPrank();

        assertEq(DAI.balanceOf(alice), aliceInitialDaiBalancePre - amount);
        assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalancePre + amount);
        assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalancePre);


        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBrideAndSetupRoute();
        // Post USDS Upgrade

        uint256 aliceInitialDaiBalancePost = DAI.balanceOf(alice);
        uint256 bridgeInitialDaiBalancePost = DAI.balanceOf(bridgeAddress);
        uint256 bridgeInitialUsdsBalancePost = USDS.balanceOf(bridgeAddress);

        vm.startPrank(alice);

        DAI.approve(address(router), amount);
        router.relayTokens(address(DAI), bob, amount);

        vm.stopPrank();

        assertEq(DAI.balanceOf(alice), aliceInitialDaiBalancePost - amount);
        assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalancePost);
        assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalancePost + amount);

    }

    function testFuzzRelayUSDSToken(uint256 amount) public {
        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx());
        vm.assume(bridge.withinLimit(amount));
        
        deal(address(USDS), alice, amount * 2);
        

        // Pre USDS upgrade
        // Route for USDS is not set yet, peripheral contract will swap USDS to DAI and send to xDAI Bridge
        uint256 aliceInitialUsdsBalancePre = USDS.balanceOf(alice);
        uint256 bridgeInitialUsdsBalancePre = USDS.balanceOf(bridgeAddress);
        uint256 bridgeInitialDaiBalancePre = DAI.balanceOf(bridgeAddress);
        uint256 routerInitialUsdsBalancePre = USDS.balanceOf(address(router));
        uint256 routerInitialDaiBalancePre = DAI.balanceOf(address(router));

        vm.startPrank(alice);

        USDS.approve(address(router), amount);
        router.relayTokens(address(USDS), bob, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), aliceInitialUsdsBalancePre - amount);
        assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalancePre);
        assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalancePre + amount);
        assertEq(USDS.balanceOf(address(router)), routerInitialUsdsBalancePre);
        assertEq(DAI.balanceOf(address(router)), routerInitialDaiBalancePre);
        


        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBrideAndSetupRoute();
       
        uint256 aliceInitialUsdsBalancePost = USDS.balanceOf(alice);
        uint256 bridgeInitialUsdsBalancePost = USDS.balanceOf(bridgeAddress);
        uint256 bridgeInitialDaiBalancePost = DAI.balanceOf(bridgeAddress);
        uint256 routerInitialUsdsBalancePost = USDS.balanceOf(address(router));
        uint256 routerInitialDaiBalancePost = DAI.balanceOf(address(router));

        vm.startPrank(alice);

        USDS.approve(address(router), amount);
        router.relayTokens(address(USDS), bob, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), aliceInitialUsdsBalancePost - amount);
        assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalancePost + amount);
        assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalancePost);
        assertEq(USDS.balanceOf(address(router)), routerInitialUsdsBalancePost);
        assertEq(DAI.balanceOf(address(router)), routerInitialDaiBalancePost);
        


    }

    function testFuzzRelayGNO(uint256 amount) public {

        amount = bound(amount, 1 ether, 1e30);
        vm.assume(IOmnibridge(FOREIGN_OMNIBRIDGE).withinLimit(address(GNO), amount));
        deal(address(GNO), alice, amount * 2);

        // Pre USDS upgrade
        uint256 aliceInitialGNOBalancePre = GNO.balanceOf(alice);
        uint256 omnibridgeInitialGNOBalancePre = GNO.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.startPrank(alice);

        GNO.approve(address(router), amount);
        router.relayTokens(address(GNO), bob, amount);

        vm.stopPrank();

        assertEq(GNO.balanceOf(alice), aliceInitialGNOBalancePre - amount);
        assertEq(GNO.balanceOf(FOREIGN_OMNIBRIDGE), omnibridgeInitialGNOBalancePre + amount);
       
        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBrideAndSetupRoute();
        
        // Post USDS upgrade
        uint256 aliceInitialGNOBalancePost = GNO.balanceOf(alice);
        uint256 omnibridgeInitialGNOBalancePost = GNO.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.startPrank(alice);

        GNO.approve(address(router), amount);
        router.relayTokens(address(GNO), bob, amount);

        vm.stopPrank();

        assertEq(GNO.balanceOf(alice), aliceInitialGNOBalancePost - amount);
        assertEq(GNO.balanceOf(FOREIGN_OMNIBRIDGE), omnibridgeInitialGNOBalancePost + amount);

    }

    function testFuzzRelayETH(uint256 amount) public payable {
        amount = bound(amount, 1, IOmnibridge(FOREIGN_OMNIBRIDGE).dailyLimit(address(WETH)));
        vm.assume(IOmnibridge(FOREIGN_OMNIBRIDGE).withinLimit(address(WETH), amount));

        deal(alice, amount * 2);
        IERC20 weth = IERC20(WETH);

        // Pre USDS Upgrade

        uint256 aliceInitialBalancePre = alice.balance;
        uint256 omnibridgeInitialBalancePre = weth.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.prank(alice);
        router.relayTokens{value: amount}(address(0), bob, amount);

        assertEq(alice.balance, aliceInitialBalancePre - amount);
        assertEq(weth.balanceOf(FOREIGN_OMNIBRIDGE),  omnibridgeInitialBalancePre + amount);

       
        teleport(block.timestamp + 1 days); // For cases where amount > current bridge limit and will raise Error ("Exceeds bridge daily limit")
        upgradeBrideAndSetupRoute();
        
        // Post USDS upgrade

        uint256 aliceInitialBalancePost = alice.balance;
        uint256 omnibridgeInitialBalancePost = weth.balanceOf(FOREIGN_OMNIBRIDGE);

        vm.prank(alice);
        router.relayTokens{value: amount}(address(0), bob, amount);

        assertEq(alice.balance, aliceInitialBalancePost - amount);
        assertEq(weth.balanceOf(FOREIGN_OMNIBRIDGE),  omnibridgeInitialBalancePost + amount);


    }

    function testFuzzExecuteSignaturePreUpgrade(uint256 amount) public {

        amount = bound(amount, 1 ether, sDAI.maxWithdraw(bridgeAddress) + DAI.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));
        uint256 claimAmount = amount;
        addMockValidator();

        // Pre USDS Upgrade


        uint256 aliceInitialUsdsBalancePre = USDS.balanceOf(alice);
        uint256 aliceInitialDaiBalancePre = DAI.balanceOf(alice);
        uint256 bridgeInitialUsdsBalancePre = USDS.balanceOf(bridgeAddress);
        uint256 bridgeInitialDaiBalancePre = DAI.balanceOf(bridgeAddress);

        (bytes memory messagePre, bytes memory signaturesPre) = getMessageAndSignatures(
            alice,
            claimAmount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            validatorPk
        );

        vm.prank(alice);
        router.executeSignatures(messagePre, signaturesPre);

        assertEq(DAI.balanceOf(alice), aliceInitialDaiBalancePre + claimAmount);
        assertEq(USDS.balanceOf(alice), aliceInitialUsdsBalancePre);
        assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalancePre);
        if(bridgeInitialDaiBalancePre > claimAmount){
             assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalancePre - claimAmount, "DAI balance of bridge should more than min threshold");
        }else{
             assertEq(DAI.balanceOf(bridgeAddress), bridge.minCashThreshold(address(DAI)), "DAI balance of bridge should equal to min threshold");
        }
     
    }

        // Should also get DAI after the upgrade when calling executeSignatures
       function testFuzzExecuteSignaturesPostUpgrade(uint256 amount) public {
        
        upgradeBrideAndSetupRoute();
        amount = bound(amount, 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));
        uint256 claimAmount = amount;
        addMockValidator();
    
        uint256 aliceInitialUsdsBalancePost = USDS.balanceOf(alice);
        uint256 aliceInitialDaiBalancePost = DAI.balanceOf(alice);
        uint256 bridgeInitialUsdsBalancePost = USDS.balanceOf(bridgeAddress);
        uint256 bridgeInitialDaiBalancePost = DAI.balanceOf(bridgeAddress);

        (bytes memory messagePost, bytes memory signaturesPost) = getMessageAndSignatures(
            alice,
            claimAmount,
            bytes32(uint256(20000001)), // nonce
            bridgeAddress,
            validatorPk
        );

        vm.prank(alice);
        router.executeSignatures(messagePost, signaturesPost);

        assertEq(USDS.balanceOf(alice), aliceInitialUsdsBalancePost);
        assertEq(DAI.balanceOf(alice), aliceInitialDaiBalancePost + claimAmount);
        assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalancePost);
        if(bridgeInitialUsdsBalancePost > claimAmount){
             assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalancePost - claimAmount, "USDS balance of bridge should more than min threshold");
        }else{
             assertEq(USDS.balanceOf(bridgeAddress), bridge.minCashThreshold(address(USDS)), "USDS balance of bridge should equal to min threshold");
        }

    }

   function testFuzzExecuteSignaturesUSDSPreUpgrade(uint256 amount) public {

        amount = bound(amount, 1 ether, sDAI.maxWithdraw(bridgeAddress) + DAI.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));
        uint256 claimAmount = amount;
        addMockValidator();

        // Pre USDS Upgrade
        (bytes memory messagePre, bytes memory signaturesPre) = getMessageAndSignatures(
            alice,
            claimAmount,
            bytes32(uint256(20000000)), // nonce
            bridgeAddress,
            validatorPk
        );

        vm.prank(alice);
        vm.expectRevert(ClaimUsdsNotSupported.selector);
        router.executeSignaturesUSDS(messagePre, signaturesPre);
    }


      function testFuzzExecuteSignaturesUSDSPostUpgrade(uint256 amount) public {
        
        upgradeBrideAndSetupRoute();
        amount = bound(amount, 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));
        uint256 claimAmount = amount;
        addMockValidator();
    
        uint256 aliceInitialUsdsBalancePost = USDS.balanceOf(alice);
        uint256 aliceInitialDaiBalancePost = DAI.balanceOf(alice);
        uint256 bridgeInitialUsdsBalancePost = USDS.balanceOf(bridgeAddress);
        uint256 bridgeInitialDaiBalancePost = DAI.balanceOf(bridgeAddress);

        (bytes memory messagePost, bytes memory signaturesPost) = getMessageAndSignatures(
            alice,
            claimAmount,
            bytes32(uint256(20000001)), // nonce
            bridgeAddress,
            validatorPk
        );

        vm.prank(alice);
        router.executeSignaturesUSDS(messagePost, signaturesPost);

        assertEq(DAI.balanceOf(alice), aliceInitialUsdsBalancePost);
        assertEq(USDS.balanceOf(alice), aliceInitialDaiBalancePost + claimAmount);
        assertEq(DAI.balanceOf(bridgeAddress), bridgeInitialDaiBalancePost);
        if(bridgeInitialUsdsBalancePost > claimAmount){
             assertEq(USDS.balanceOf(bridgeAddress), bridgeInitialUsdsBalancePost - claimAmount, "USDS balance of bridge should more than min threshold");
        }else{
             assertEq(USDS.balanceOf(bridgeAddress), bridge.minCashThreshold(address(USDS)), "USDS balance of bridge should equal to min threshold");
        }

    }
   
    function testRecoverLockedFund(uint256 amount) public{
        vm.assume(amount>0);
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


        upgradeBrideAndSetupRoute();
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

    function upgradeBrideAndSetupRoute() public {
  
        vm.startPrank(bridgeOwner);
        router.setRoute(address(DAI), address(peripheral));
        router.setRoute(address(USDS), FOREIGN_XDAIBRIDGE);
        vm.stopPrank();

        upgradeAndInitializeInterest();
    }
}
