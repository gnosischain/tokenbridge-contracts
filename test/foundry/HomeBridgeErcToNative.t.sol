// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IHomeBridgeErcToNative} from "./interfaces/IHomeBridgeErcToNative.sol";
import {IEternalStorageProxy} from "./interfaces/IEternalStorageProxy.sol";
import {IBridgeValidators} from "./interfaces/IBridgeValidators.sol";
import {USDSDepositContract} from "../../contracts/USDSDepositContract.sol";

// Required fork-url to run the test on Gnosis Chain
// Include test for DepositContract
// Run forge test --match-contract HomeBridgeErcToNativeTest --fork-url https://rpc.gnosischain.com
contract HomeBridgeErcToNativeTest is Test {

    event UserRequestForSignature(address recipient, uint256 value, bytes32 nonce, address token);
    event CollectedSignatures(
        address authorityResponsibleForRelay, bytes32 messageHash, uint256 NumberOfCollectedSignatures
    );
    event AmountLimitExceeded(address recipient, uint256 value, bytes32 indexed transactionHash, bytes32 messageId);
    event AssetAboveLimitsFixed(bytes32 indexed messageId, uint256 value, uint256 remaining);

    IHomeBridgeErcToNative newImpl;
    IEternalStorageProxy public bridgeProxy;
    IBridgeValidators validatorContract = IBridgeValidators(0xB289f0e6fBDFf8EEE340498a56e1787B303F1B6D);
    USDSDepositContract depositContract;

    address payable HOME_XDAI_BRIDGE_PROXY = payable(0x7301CFA0e1756B71869E93d4e4Dca5c7d0eb0AA6);
    address FOREIGN_XDAI_BRIDGE_PROXY = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    address public XDAI_BRIDGE_PROXY_OWNER = 0x7a48Dac683DA91e4faa5aB13D91AB5fd170875bd;
    address public VALIDATOR_CONTRACT_OWNER = 0x7a48Dac683DA91e4faa5aB13D91AB5fd170875bd;
    address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address payable newImplAddress = payable(makeAddr("newImplAddress"));

    address validator;
    uint256 validatorPk;

    function setUp() public payable virtual {
        (validator, validatorPk) = makeAddrAndKey("mockValidator");

        // deploy new Implementation
        // new HomeBridgeErcToNative() method is not used, because of the incompatible Solidity version with the test contract
        bytes memory newImplCode = vm.getDeployedCode("HomeBridgeErcToNative.sol:0.4.24");

        vm.etch(newImplAddress, newImplCode);
        assertEq(newImplAddress.code, newImplCode);
        newImpl = IHomeBridgeErcToNative(newImplAddress);

        uint256 size;
        address _a = address(newImpl);
        assembly {
            size := extcodesize(_a)
        }
        assertGt(size, 0);
        upgradeHomexDAIBridge();
    }

    function upgradeHomexDAIBridge() public {
        depositContract = new USDSDepositContract();
        uint256 initialVersion = IEternalStorageProxy(HOME_XDAI_BRIDGE_PROXY).version();
        bytes memory data = abi.encodeWithSignature("setUSDSDepositContract(address)", address(depositContract));

        vm.prank(XDAI_BRIDGE_PROXY_OWNER);
        IEternalStorageProxy(HOME_XDAI_BRIDGE_PROXY).upgradeToAndCall(initialVersion + 1, address(newImpl), data);

        vm.startPrank(VALIDATOR_CONTRACT_OWNER);
        validatorContract.addValidator(validator);
        validatorContract.setRequiredSignatures(1);
        vm.stopPrank();
    }

    ///@dev Test calling `relayTokens(address recipient)` to USDS Deposit Contract. Should expect USDS emitted as token parameter
    function testRelayTokenToDepositContract(uint256 _amount, address _recipient) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        require(_recipient != address(0) && _recipient != HOME_XDAI_BRIDGE_PROXY);
        bytes32 nonce = bytes32(bridge.nonce());
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(_recipient, _amount, nonce, USDS);
        depositContract.relayTokens{value: _amount}(_recipient);
    }

    ///@dev Test direct transferring xDAI to USDS Deposit Contract. Should expect USDS emitted as token parameter
    function testTransferxDAIToDepositContract(uint256 _amount) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        bytes32 nonce = bytes32(bridge.nonce());
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(alice, _amount, nonce, USDS);
        address(depositContract).call{value: _amount}("");
    }

   ///@dev Test calling `relayTokens(address recipient)` to HomeBridgeErcToNative. Should expect DAI emitted as token parameter
    function testRelayTokenToBridge(uint256 _amount, address _recipient) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        require(_recipient != address(0) && _recipient != HOME_XDAI_BRIDGE_PROXY);
        bytes32 nonce = bytes32(bridge.nonce());
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(_recipient, _amount, nonce, DAI);

        IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).relayTokens{value: _amount}(_recipient);
    }

    ///@dev Test direct transferring xDAI to HomeBridgeErcToNative. Should expect DAI emitted as token parameter
    function testTransferxDAIToBridge(uint256 _amount) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        bytes32 nonce = bytes32(bridge.nonce());
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(alice, _amount, nonce, DAI);
        HOME_XDAI_BRIDGE_PROXY.call{value: _amount}("");
    }

 
    ///@dev Test validator calling `submitSignatures` with new message type. Should expect DAI emmited as token parameter
    function testValidatorSignatureDAIRelayToken(uint256 _amount) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        bytes32 nonce = bytes32(bridge.nonce());
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(bob, _amount, nonce, DAI);
        IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).relayTokens{value: _amount}(bob);

        (bytes memory message, bytes memory signatures) =
            getMessageAndSignatures(bob, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, DAI, validatorPk, false);

        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);
    }

    ///@dev Test validator calling `submitSignatures` with new message type. Should expect DAI emmited as token parameter
    function testValidatorSignatureDAIDirectTransfer(uint256 _amount) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        bytes32 nonce = bytes32(bridge.nonce());

        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(alice, _amount, nonce, DAI);
        HOME_XDAI_BRIDGE_PROXY.call{value: _amount}("");

        (bytes memory message, bytes memory signatures) =
            getMessageAndSignatures(alice, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, DAI, validatorPk, false);

        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);
    }

    ///@dev Test validator calling `submitSignatures` with new message type. Should expect USDS emmited as token parameter
    function testValidatorSignatureUSDSRelayToken(uint256 _amount) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        bytes32 nonce = bytes32(bridge.nonce());

        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(bob, _amount, nonce, USDS);
        depositContract.relayTokens{value: _amount}(bob);

        (bytes memory message, bytes memory signatures) =
            getMessageAndSignatures(bob, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, USDS, validatorPk, false);

        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);
    }
    
    ///@dev Test validator calling `submitSignatures` with new message type. Should expect USDS emmited as token parameter
    function testValidatorSignatureUSDSDirectTransfer(uint256 _amount) public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.assume(_amount >= bridge.minPerTx() && _amount <= bridge.maxPerTx() && bridge.withinLimit(_amount));
        bytes32 nonce = bytes32(bridge.nonce());
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(alice, _amount, nonce, USDS);

        // transfer directly
        address(depositContract).call{value: _amount}("");
        (bytes memory message, bytes memory signatures) =
            getMessageAndSignatures(alice, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, USDS, validatorPk, false);

        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);
    }
    
    ///@dev Test calling fixAssetsAboveLimit and emit the specified token in the event.
    function testFixAssetsAboveLimit() public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);

        // create executeAffirmation that exceed the limitation
        uint256 amount = bridge.executionDailyLimit() - bridge.totalExecutedPerDay(bridge.getCurrentDay()) + 1;
        bytes32 randomNonceFromSrcChain = keccak256("0x1234"); // The tx is bridging from ETH
        bytes32 messageId = keccak256(abi.encodePacked(alice, amount, randomNonceFromSrcChain));
        vm.prank(validator);
        vm.expectEmit();
        emit AmountLimitExceeded(alice, amount, randomNonceFromSrcChain, messageId);
        bridge.executeAffirmation(alice, amount, randomNonceFromSrcChain);

        // call fixAssetsAboveLimit
        vm.deal(XDAI_BRIDGE_PROXY_OWNER, 1 ether);
        bytes32 nonce = bytes32(uint256(bridge.nonce()));
        require(bridge.upgradeabilityOwner() == XDAI_BRIDGE_PROXY_OWNER);
        vm.startPrank(XDAI_BRIDGE_PROXY_OWNER);

        // Should emit these 2 events in the traces
        // vm.expectEmit(address(bridge));
        // emit AssetAboveLimitsFixed(messageId,  bridge.maxPerTx() - 1, amount - bridge.maxPerTx() + 1);
        // emit UserRequestForSignature(alice, bridge.maxPerTx() - 1, nonce , USDS);

        // The amount to unlock <= maxPerTx
        // the messageId's value >= amount to unlock , <= maxPerTx
        bridge.fixAssetsAboveLimits(messageId, true, bridge.maxPerTx() - 1, USDS);
        vm.stopPrank();

        // Should not call executeAffirmation again if it is fixed
        vm.prank(validator);
        vm.expectRevert();
        bridge.executeAffirmation(alice, amount, randomNonceFromSrcChain);
    }

    function getMessageAndSignatures(
        address _recipient,
        uint256 _amount,
        bytes32 _nonce,
        address _contractAddress,
        address _tokenAddress,
        uint256 signerPk,
        bool isForeign
    ) public returns (bytes memory message, bytes memory signatures) {
        if (_tokenAddress == address(0)) {
            message = abi.encodePacked(_recipient, _amount, _nonce, _contractAddress);
        } else {
            message = abi.encodePacked(_recipient, _amount, _nonce, _contractAddress, _tokenAddress);
        }

        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        string memory msgLength;
        if (message.length == 104) {
            msgLength = "104";
        } else if (message.length == 124) {
            msgLength = "124";
        }

        bytes32 hashedMessage = keccak256(abi.encodePacked(prefix, msgLength, message));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, hashedMessage);

        assertEq(ecrecover(hashedMessage, v, r, s), validator);
        if (isForeign) {
            signatures = abi.encodePacked(uint8(1), v, r, s);
        } else {
            signatures = abi.encodePacked(r, s, v);
        }
    }
}
