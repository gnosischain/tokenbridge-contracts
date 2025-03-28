// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import "./interfaces/ISavingsDai.sol";
import "./interfaces/IEternalStorageProxy.sol";
import "./interfaces/IXDaiForeignBridge.sol";
import "./Setup.t.sol";

contract USDSXDaiForeignBridgeTest is SetupTest {
    event DailyLimitChanged(uint256 newLimit);
    event ExecutionDailyLimitChanged(uint256 newLimit);
    event GasPriceChanged(uint256 gasPrice);
    event OwnershipTransferred(address previousOwner, address newOwner);
    event PaidInterest(address indexed token, address to, uint256 value);
    event RelayedMessage(address recipient, uint256 value, bytes32 transactionHash);
    event RequiredBlockConfirmationChanged(uint256 requiredBlockConfirmations);
    event UserRequestForAffirmation(address recipient, uint256 value);

    // test XDaibridge upgradeAndInitializeInterest

    /*//////////////////////////////////////////////////////////////
                        UPGRADING PROXIES
    //////////////////////////////////////////////////////////////*/

    function testUpgradeAndInitializeInterest() public {
        uint256 bridgeSDAIMaxWithdraw = sDAI.maxWithdraw(bridgeAddress);
        uint256 bridgeSDAIBalance = sDAI.balanceOf(bridgeAddress);
        uint256 bridgeDAIBalance = DAI.balanceOf(bridgeAddress);
        uint256 daiInvestedAmount = bridge.investedAmount(address(DAI));
        uint256 minCashThreshold = bridge.minCashThreshold(address(DAI));

        upgradeAndInitializeInterest();

        assertGt(sUSDS.balanceOf(bridgeAddress), bridgeSDAIBalance); // chi_sUSDS < chi_sDAI
        assertEq(USDS.balanceOf(bridgeAddress), minCashThreshold);
        assertEq(sDAI.maxWithdraw(bridgeAddress), 0); //disabled interested
        assertEq(DAI.balanceOf(bridgeAddress), 0); //disabled interested

        // Check if USDS initialize
        assertFalse(bridge.isInterestEnabled(address(DAI)));
        assertTrue(bridge.isInterestEnabled(address(USDS)));

        vm.stopPrank();
    }

    function testMetadata() public {
        assertEq(bridge.daiToken(), address(DAI));
        assertEq(bridge.sDaiToken(), address(sDAI));
        assertEq(bridge.erc20token(), address(DAI));

        upgradeAndInitializeInterest();

        assertEq(bridge.daiToken(), address(USDS));
        assertEq(bridge.sDaiToken(), address(sUSDS));
        assertEq(bridge.erc20token(), address(USDS));
    }

    function testFuzzRelayTokensWithUsds(uint256 amount) public {
        upgradeAndInitializeInterest();

        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx() - 1);
        vm.assume(bridge.withinLimit(amount) == true);
        deal(address(USDS), alice, amount);

        uint256 aliceBalanceBefore = USDS.balanceOf(alice);

        vm.startPrank(alice);

        USDS.approve(address(bridge), amount);
        bridge.relayTokens(bob, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), aliceBalanceBefore - amount);
    }

    function testFuzzRelayTokensWithDai(uint256 amount) public {
        upgradeAndInitializeInterest();

        amount = bound(amount, bridge.minPerTx(), bridge.maxPerTx() - 1);
        vm.assume(bridge.withinLimit(amount) == true);
        deal(address(DAI), alice, amount);

        vm.startPrank(alice);
        DAI.approve(address(bridge), amount);

        // USDS is the default accepted token on bridge when calling `relayTokens`
        vm.expectRevert("Usds/insufficient-balance");
        bridge.relayTokens(alice, amount);

        vm.stopPrank();
    }

    // Dev: we keep the same function name investDai() but USDS is invested as underlying asset
    function testFuzzInvestUSDS(uint256 amount) public {
        upgradeAndInitializeInterest();

        vm.assume(amount < USDS.totalSupply() + DAI.totalSupply());
        vm.assume(amount > 1 ether);

        vm.startPrank(bridgeOwner);

        uint256 initialBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialInvested = bridge.investedAmount(address(USDS));
        uint256 initialCollectable = bridge.interestAmount(address(USDS));
        assertLt(sUSDS.balanceOf(bridgeAddress), initialInvested);

        deal(address(USDS), address(bridge), amount + initialBalance);

        bridge.investDai();

        skipTime(1 days);
        uint256 afterBalance = USDS.balanceOf(bridgeAddress);
        uint256 afterInvested = bridge.investedAmount(address(USDS));
        uint256 afterCollectable = bridge.interestAmount(address(USDS));

        assertEq(afterBalance, initialBalance);
        assertGt(afterInvested, initialInvested);
        assertEq(afterInvested, initialInvested + amount);
        assertGt(afterCollectable, initialCollectable);
    }

    function testFuzzPayInterest(uint256 minCashThreshold, uint256 minInterestPaid, uint256 amount) public {
        address token = address(USDS);

        vm.assume(minCashThreshold > 100 ether);
        vm.assume(minInterestPaid > 100 ether);
        vm.assume(amount > 0);

        upgradeAndInitializeInterest();

        vm.startPrank(bridgeOwner);
        bridge.setMinCashThreshold(token, minCashThreshold);
        bridge.setMinInterestPaid(token, minInterestPaid);
        vm.stopPrank();

        uint256 initialBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialInvested = bridge.investedAmount(token);
        uint256 initialCollectable = bridge.interestAmount(token);
        uint256 claimed = (initialCollectable > amount) ? amount : initialCollectable;
        uint256 initialWithdrawable = bridge.previewWithdraw(token, claimed);
        console.log("Bal:%e Inv:%e Col:%e", initialBalance, initialInvested, initialCollectable);
        if (claimed >= minInterestPaid) {
            vm.startPrank(bridgeOwner);
            vm.expectEmit();
            emit UserRequestForAffirmation(gnosisInterestReceiver, claimed);
            bridge.payInterest(token, claimed);

            vm.stopPrank();
            uint256 afterBalance = USDS.balanceOf(bridgeAddress);
            uint256 afterInvested = bridge.investedAmount(token);
            uint256 afterCollectable = bridge.interestAmount(token);
            uint256 afterWithdrawable = bridge.previewWithdraw(token, afterCollectable);
            assertGe(initialCollectable, initialWithdrawable);
            assertLt(afterCollectable, initialCollectable);
            assertLe(afterWithdrawable, bridge.previewWithdraw(token, initialCollectable));
            assertEq(afterBalance, initialBalance);
            assertGt(afterInvested, initialInvested);
            assertEq(afterInvested, initialInvested + claimed);
            console.log("Bal:%e Inv:%e Col:%e", afterBalance, afterInvested, afterCollectable);
            console.log("initWith:%e afterWith:%e", initialWithdrawable, afterWithdrawable);
        } else {
            vm.expectRevert(bytes("Collectable interest too low"));
            bridge.payInterest(token, claimed);
        }
    }

    function testPayInterestToWrongToken() public {
        address comp = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
        vm.startPrank(bridgeOwner);
        vm.expectRevert("Token not supported");
        bridge.initializeInterest(comp, 100 ether, 1 ether, address(1));
        vm.expectRevert("Interest not Enabled");
        bridge.payInterest(comp, 1000);
    }

    function testDisableInterest() public {
        address token = address(USDS);
        upgradeAndInitializeInterest();
        skipTime(6 hours);
        uint256 initialBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialInvested = bridge.investedAmount(token);
        uint256 initialCollectable = bridge.interestAmount(token);
        uint256 initialWithdrawable = bridge.previewWithdraw(token, initialInvested);

        vm.startPrank(bridgeOwner);
        bridge.disableInterest(address(USDS));
        vm.stopPrank();

        uint256 afterBalance = USDS.balanceOf(bridgeAddress);
        uint256 afterInvested = bridge.investedAmount(token);
        uint256 afterCollectable = bridge.interestAmount(token); // what is the difference?
        uint256 afterWithdrawable = bridge.previewWithdraw(token, afterInvested); // what is the difference?
        if (initialInvested > 0) {
            assertGt(afterBalance, initialBalance);
            assertEq(afterBalance, initialBalance + initialInvested);
            assertLt(afterInvested, initialInvested);
            if (afterWithdrawable > 0) {
                assertLt(afterCollectable, afterWithdrawable);
            }
        } else {
            assertEq(afterBalance, initialBalance);
        }
        assertEq(afterInvested, 0);
        assertEq(afterWithdrawable, 0);
        assertGe(afterCollectable, afterWithdrawable);
        assertGe(initialInvested, initialWithdrawable);
    }

    /*//////////////////////////////////////////////////////////////
                        CONFIG PARAMETERS
    //////////////////////////////////////////////////////////////*/

    function testInitializeInterest(uint256 _minCashThreshold, uint256 _minInterestPaid) public {
        upgradeAndInitializeInterest();
        vm.startPrank(bridgeOwner);

        vm.expectRevert(bytes("Token not supported"));
        bridge.initializeInterest(address(sUSDS), _minCashThreshold, _minInterestPaid, gnosisInterestReceiver);

        if (bridge.isInterestEnabled(address(USDS)) == false) {
            bridge.initializeInterest(address(USDS), _minCashThreshold, _minInterestPaid, gnosisInterestReceiver);
        } else {
            vm.expectRevert(bytes("Interest already enabled"));
            bridge.initializeInterest(address(USDS), _minCashThreshold, _minInterestPaid, gnosisInterestReceiver);
        }

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        SPECIAL STATES
    //////////////////////////////////////////////////////////////*/

    function testFuzzRefillBridge(uint256 amount) public {
        upgradeAndInitializeInterest();
        uint256 maxWithdrawable = sUSDS.maxWithdraw(bridgeAddress);
        amount = bound(amount, 1 ether, maxWithdrawable);

        uint256 initialBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialInvested = bridge.investedAmount(address(USDS));
        uint256 initialCollectable = bridge.interestAmount(address(USDS));

        // config change to force valid refill state
        vm.prank(bridgeOwner);
        bridge.setMinCashThreshold(address(USDS), initialBalance + amount);
        //refill
        bridge.refillBridge();

        uint256 afterBalance = USDS.balanceOf(bridgeAddress);
        uint256 afterInvested = bridge.investedAmount(address(USDS));
        uint256 afterCollectable = bridge.interestAmount(address(USDS));

        assertEq(afterBalance, initialBalance + amount);
    }

    function testFuzzExecuteSignatures(uint256 amount) public {
        upgradeAndInitializeInterest();
        addMockValidator();

        bytes32 nonce = bytes32(uint256(20000000));

        uint256 initialAliceBalance = USDS.balanceOf(alice);
        uint256 initialBridgeBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);
        uint256 minCasThreshold = bridge.minCashThreshold(address(USDS));

        amount = bound(amount, 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));

        // Case 1: amount < minCashThreshold
        if (amount <= minCasThreshold) {
            // should not call refill bridge

            (bytes memory message, bytes memory signatures) =
                getMessageAndSignatures(alice, amount, nonce, bridgeAddress, validatorPk);

            vm.prank(alice);
            vm.expectEmit(bridgeAddress);
            emit RelayedMessage(alice, amount, nonce);
            bridge.executeSignatures(message, signatures);
            assertEq(USDS.balanceOf(bridgeAddress), initialBridgeBalance - amount);
        } else {
            // Case 2: amount > minCashThreshold
            // expect not enough balance
            // need to call refillBridge

            (bytes memory message, bytes memory signatures) =
                getMessageAndSignatures(alice, amount, nonce, bridgeAddress, validatorPk);

            vm.prank(alice);
            vm.expectEmit(bridgeAddress);
            emit RelayedMessage(alice, amount, nonce);
            bridge.executeSignatures(message, signatures);
            assertEq(USDS.balanceOf(bridgeAddress), bridge.minCashThreshold(address(USDS)));
        }
        // after upgrade
        // should also receive DAI when calling executeSignatures
        assertEq(DAI.balanceOf(alice), initialAliceBalance + amount, "Alice should receive DAI");
        assertEq(USDS.balanceOf(alice), initialAliceDAIBalance, "Alice should not receive USDS");
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance, "Bridge should have the same DAI balance");
    }

    function testFuzzExecuteSignaturesUSDS(uint256 amount) public {
        // after upgrade, should receive USDS
        upgradeAndInitializeInterest();
        addMockValidator();

        bytes32 nonce = bytes32(uint256(20000000));

        uint256 initialAliceBalance = USDS.balanceOf(alice);
        uint256 initialBridgeBalance = USDS.balanceOf(bridgeAddress);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);
        uint256 minCasThreshold = bridge.minCashThreshold(address(USDS));

        amount = bound(amount, 1 ether, sUSDS.maxWithdraw(bridgeAddress) + USDS.balanceOf(bridgeAddress) - 10 ether);
        vm.assume(bridge.withinExecutionLimit(amount));

        // Case 1: amount < minCashThreshold
        if (amount <= minCasThreshold) {
            // should not call refill bridge

            (bytes memory message, bytes memory signatures) =
                getMessageAndSignatures(alice, amount, nonce, bridgeAddress, validatorPk);

            vm.prank(alice);
            vm.expectEmit(bridgeAddress);
            emit RelayedMessage(alice, amount, nonce);
            bridge.executeSignaturesUSDS(message, signatures);
            assertEq(USDS.balanceOf(bridgeAddress), initialBridgeBalance - amount);
        } else {
            // Case 2: amount > minCashThreshold
            // expect not enough balance
            // need to call refillBridge

            (bytes memory message, bytes memory signatures) =
                getMessageAndSignatures(alice, amount, nonce, bridgeAddress, validatorPk);

            vm.prank(alice);
            vm.expectEmit(bridgeAddress);
            emit RelayedMessage(alice, amount, nonce);
            bridge.executeSignaturesUSDS(message, signatures);
            assertEq(USDS.balanceOf(bridgeAddress), bridge.minCashThreshold(address(USDS)));
        }

        assertEq(USDS.balanceOf(alice), initialAliceBalance + amount, "Alice should receive USDS");
        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance, "Alice should not receive DAI");
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance, "Bridge should have the same DAI balance");
    }

    function testFuzzRelayDAIAndClaimBack(uint256 amount) public {
        upgradeAndInitializeInterest();
        // transfer DAI
        amount = bound(amount, bridge.minPerTx(), bridge.minPerTx());
        vm.assume(bridge.withinLimit(amount));
        deal(address(DAI), alice, amount);

        uint256 currentDay = bridge.getCurrentDay();
        uint256 initialBridgeTotalSpentPerDay = bridge.totalSpentPerDay(currentDay);
        uint256 initialBridgeDAIBalance = DAI.balanceOf(bridgeAddress);
        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);

        vm.startPrank(alice);
        DAI.approve(bridgeAddress, amount);
        DAI.transfer(bridgeAddress, amount);
        vm.stopPrank();

        assertEq(bridge.totalSpentPerDay(currentDay), initialBridgeTotalSpentPerDay);
        assertEq(DAI.balanceOf(bridgeAddress), initialBridgeDAIBalance + amount);
        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance - amount);

        vm.prank(bridgeOwner);
        bridge.claimTokens(address(DAI), alice);

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance);
    }

    function testInvalidInterestReceiver() public {
        upgradeAndInitializeInterest();

        vm.prank(bridgeOwner);
        vm.expectRevert("Receiver can't be the Bridge"); // this error is obsolete because _relayInterest is used, instead of _transferInterest
        bridge.setInterestReceiver(address(USDS), bridgeAddress);
    }
}
