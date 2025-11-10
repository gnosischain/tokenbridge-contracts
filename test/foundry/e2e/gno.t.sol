// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IHomeBridgeErcToNative} from "../interfaces/IHomeBridgeErcToNative.sol";
import {IEternalStorageProxy} from "../interfaces/IEternalStorageProxy.sol";
import {IBridgeValidators} from "../interfaces/IBridgeValidators.sol";
import {USDSDepositContract} from "../../../contracts/USDSDepositContract.sol";

///@dev Don't run this this individually, please run ./test/foundry/e2e/e2e-test.sh
contract GNOForkTest is Test {
    event UserRequestForSignature(address recipient, uint256 value, bytes32 nonce, address token);
    event CollectedSignatures(
        address authorityResponsibleForRelay, bytes32 messageHash, uint256 NumberOfCollectedSignatures
    );
    event AffirmationCompleted(address recipient, uint256 value, bytes32 nonce);

    struct MessageFromETH {
        uint256 amount;
        bytes32 nonce;
        address recipient;
    }

    IHomeBridgeErcToNative newImpl;
    IEternalStorageProxy public bridgeProxy;
    IBridgeValidators validatorContract = IBridgeValidators(0xB289f0e6fBDFf8EEE340498a56e1787B303F1B6D);
    USDSDepositContract depositContract;
    address payable HOME_XDAI_BRIDGE_PROXY = payable(0x7301CFA0e1756B71869E93d4e4Dca5c7d0eb0AA6);
    address FOREIGN_XDAI_BRIDGE_PROXY = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    address public PROXY_OWNER = 0x7a48Dac683DA91e4faa5aB13D91AB5fd170875bd;
    address public VALIDATOR_CONTRACT_OWNER = 0x7a48Dac683DA91e4faa5aB13D91AB5fd170875bd;
    address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address payable newImplAddress = payable(makeAddr("newImplAddress"));
    address validator;
    uint256 pKey;

    function setUp() public {
        (validator, pKey) = makeAddrAndKey("mockValidator");

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

        vm.prank(PROXY_OWNER);
        IEternalStorageProxy(HOME_XDAI_BRIDGE_PROXY).upgradeToAndCall(initialVersion + 1, address(newImpl), data);

        vm.startPrank(VALIDATOR_CONTRACT_OWNER);
        validatorContract.addValidator(validator);
        validatorContract.setRequiredSignatures(1);
        vm.stopPrank();
    }

    function testTransferToDepositContract() public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        uint256 _amount = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).minPerTx() + 2;

        bytes32 nonce = bytes32(uint256(IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).nonce()));
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(alice, _amount, nonce, USDS);
        address(depositContract).call{value: _amount}("");

        // mock validator get message and signatures
        (bytes memory message, bytes memory signatures, uint8 v, bytes32 r, bytes32 s) =
            getMessageAndSignatures(alice, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, USDS, pKey, false);
        require(message.length != 0, "message is 0");
        require(signatures.length != 0, "sigantures is 0");
        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);

        // Record the UserRequestForSignature
        writeToFile(alice, _amount, nonce, USDS, message, v, r, s);
    }

    function testRelayTokensToDepositContract() public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        uint256 _amount = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).minPerTx() + 2;

        bytes32 nonce = bytes32(uint256(IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).nonce()));
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(bob, _amount, nonce, USDS);
        depositContract.relayTokens{value: _amount}(bob);

        // mock validator get message and signatures
        (bytes memory message, bytes memory signatures, uint8 v, bytes32 r, bytes32 s) =
            getMessageAndSignatures(bob, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, USDS, pKey, false);
        require(message.length != 0, "message is 0");
        require(signatures.length != 0, "sigantures is 0");
        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);

        // Record the UserRequestForSignature
        writeToFile(bob, _amount, nonce, USDS, message, v, r, s);
    }

    function testTransferToBridge() public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        uint256 _amount = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).minPerTx() + 2;

        bytes32 nonce = bytes32(uint256(IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).nonce()));
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(alice, _amount, nonce, DAI);
        HOME_XDAI_BRIDGE_PROXY.call{value: _amount}("");

        // mock validator get message and signatures
        (bytes memory message, bytes memory signatures, uint8 v, bytes32 r, bytes32 s) =
            getMessageAndSignatures(alice, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, DAI, pKey, false);
        require(message.length != 0, "message is 0");
        require(signatures.length != 0, "sigantures is 0");
        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);

        // Record the UserRequestForSignature
        writeToFile(alice, _amount, nonce, DAI, message, v, r, s);
    }

    function testRelayTokensToBridge() public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        uint256 _amount = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).minPerTx() + 2;

        bytes32 nonce = bytes32(uint256(IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).nonce()));
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(bob, _amount, nonce, DAI);
        IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).relayTokens{value: _amount}(bob);

        // mock validator get message and signatures
        (bytes memory message, bytes memory signatures, uint8 v, bytes32 r, bytes32 s) =
            getMessageAndSignatures(bob, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, DAI, pKey, false);
        require(message.length != 0, "message is 0");
        require(signatures.length != 0, "sigantures is 0");
        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);

        // Record the UserRequestForSignature
        writeToFile(bob, _amount, nonce, DAI, message, v, r, s);
    }

    function testTransferToBridgeWithOldXDaiMsg() public {
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        uint256 _amount = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).minPerTx() + 2;

        bytes32 nonce = bytes32(uint256(IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).nonce()));
        vm.deal(alice, _amount);
        vm.prank(alice);
        vm.expectEmit();
        emit UserRequestForSignature(bob, _amount, nonce, DAI);
        IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY).relayTokens{value: _amount}(bob);

        // mock validator get message and signatures
        (bytes memory message, bytes memory signatures, uint8 v, bytes32 r, bytes32 s) =
            getMessageAndSignatures(bob, _amount, nonce, FOREIGN_XDAI_BRIDGE_PROXY, address(0), pKey, false);
        require(message.length != 0, "message is 0");
        require(signatures.length != 0, "sigantures is 0");
        vm.prank(validator);
        vm.expectEmit();
        emit CollectedSignatures(validator, keccak256(abi.encodePacked(message)), 1);
        bridge.submitSignature(signatures, message);

        // Record the UserRequestForSignature
        writeToFile(bob, _amount, nonce, DAI, message, v, r, s);
    }

    function testExecuteAffirmation() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/foundry/e2e/validator.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        MessageFromETH memory message = abi.decode(data, (MessageFromETH));
        IHomeBridgeErcToNative bridge = IHomeBridgeErcToNative(HOME_XDAI_BRIDGE_PROXY);
        vm.prank(validator);
        vm.expectEmit(address(bridge));
        emit AffirmationCompleted(message.recipient, message.amount, message.nonce);
        bridge.executeAffirmation(message.recipient, message.amount, message.nonce);
    }

    function getMessageAndSignatures(
        address _recipient,
        uint256 _amount,
        bytes32 _nonce,
        address _contractAddress,
        address _tokenAddress,
        uint256 signerPk,
        bool isForeign
    ) public returns (bytes memory message, bytes memory signatures, uint8 v, bytes32 r, bytes32 s) {
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

        (v, r, s) = vm.sign(signerPk, hashedMessage);

        assertEq(ecrecover(hashedMessage, v, r, s), validator);
        if (isForeign) {
            signatures = abi.encodePacked(uint8(1), v, r, s);
        } else {
            signatures = abi.encodePacked(r, s, v);
        }
    }

    function writeToFile(
        address _recipient,
        uint256 _amount,
        bytes32 _nonce,
        address _token,
        bytes memory _message,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        string memory test1 = "transactionDetails";
        vm.serializeAddress(test1, "recipeint", _recipient);
        vm.serializeUint(test1, "amount", _amount);
        vm.serializeBytes32(test1, "nonce", _nonce);
        vm.serializeAddress(test1, "token", _token);
        vm.serializeBytes(test1, "message", _message);
        vm.serializeUint(test1, "v", _v);
        vm.serializeBytes32(test1, "r", _r);
        string memory finalJson = vm.serializeBytes32(test1, "s", _s);
        vm.writeJson(finalJson, "./test/foundry/e2e/validator.json");
    }
}
