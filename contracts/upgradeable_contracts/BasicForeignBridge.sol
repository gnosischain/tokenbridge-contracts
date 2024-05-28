pragma solidity 0.4.24;

import "../upgradeability/EternalStorage.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./Validatable.sol";
import "../libraries/Message.sol";
import "./MessageRelay.sol";
import "./BasicBridge.sol";
import "./BasicTokenBridge.sol";
import "./MessageRelay.sol";

contract BasicForeignBridge is EternalStorage, Validatable, BasicBridge, BasicTokenBridge, MessageRelay {
    /// triggered when relay of deposit from HomeBridge is complete
    event RelayedMessage(address recipient, uint256 value, bytes32 transactionHash);
    event UserRequestForAffirmation(address recipient, uint256 value, bytes32 nonce);

    /**
    * @dev Validates provided signatures and relays a given message
    * @param message bytes to be relayed
    * @param signatures bytes blob with signatures to be validated
    */
    function executeSignatures(bytes message, bytes signatures) external {
        Message.hasEnoughValidSignatures(message, signatures, validatorContract(), false);

        address recipient;
        uint256 amount;
        bytes32 nonce;
        address contractAddress;
        (recipient, amount, nonce, contractAddress) = Message.parseMessage(message);
        if (withinExecutionLimit(amount)) {
            require(contractAddress == address(this));
            require(!relayedMessages(nonce));
            setRelayedMessages(nonce, true);

            bytes32 msgId = keccak256(abi.encodePacked(recipient, amount, nonce));
            if (HASHI_IS_ENABLED && HASHI_IS_MANDATORY) require(isApprovedByHashi(msgId));

            require(onExecuteMessage(recipient, amount, nonce));
            emit RelayedMessage(recipient, amount, nonce);
        } else {
            onFailedMessage(recipient, amount, nonce);
        }
    }

    function onMessage(uint256 chainId, uint256, address sender, bytes message) external returns (bytes) {
        require(
            HASHI_IS_ENABLED &&
                msg.sender == hashiManager().yaru() &&
                chainId == hashiManager().hashiTargetChainId() &&
                sender == hashiManager().hashiTargetAddress()
        );
        // NOTE: message contains recipient, amount, nonce
        bytes32 msgId = keccak256(message);
        _setHashiApprovalForMessage(msgId, true);
    }

    function _emitUserRequestForAffirmationMaybeRelayDataWithHashiAndIncreaseNonce(address _receiver, uint256 _amount)
        internal
    {
        uint256 currentNonce = nonce();
        emit UserRequestForAffirmation(_receiver, _amount, bytes32(currentNonce));
        _maybeRelayDataWithHashi(abi.encodePacked(_receiver, _amount, bytes32(currentNonce)));
        setNonce(currentNonce + 1);
    }

    /**
    * @dev Internal function for updating fallback gas price value.
    * @param _gasPrice new value for the gas price, zero gas price is not allowed.
    */
    function _setGasPrice(uint256 _gasPrice) internal {
        require(_gasPrice > 0);
        super._setGasPrice(_gasPrice);
    }

    function canBeExecuted(bytes32 msgId) public view returns (bool) {
        return boolStorage[keccak256(abi.encodePacked("messageToExecute", msgId))];
    }

    function _setMessageToExecute(bytes32 msgId, bool status) internal {
        boolStorage[keccak256(abi.encodePacked("messageToExecute", msgId))] = status;
    }

    /* solcov ignore next */
    function onExecuteMessage(address, uint256, bytes32) internal returns (bool);

    /* solcov ignore next */
    function onFailedMessage(address, uint256, bytes32) internal;
}
