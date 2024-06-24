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

            bytes32 hashMsg = keccak256(abi.encodePacked(recipient, amount, nonce));
            if (HASHI_IS_ENABLED && HASHI_IS_MANDATORY) require(isApprovedByHashi(hashMsg));

            require(onExecuteMessage(recipient, amount, nonce));
            emit RelayedMessage(recipient, amount, nonce);
        } else {
            onFailedMessage(recipient, amount, nonce);
        }
    }

    function onMessage(
        uint256, /*messageId*/
        uint256 chainId,
        address sender,
        uint256 threshold,
        address[] adapters,
        bytes data
    ) external returns (bytes) {
        _validateHashiMessage(chainId, threshold, sender, adapters);
        bytes32 hashMsg = keccak256(data);
        require(!isApprovedByHashi(hashMsg));
        _setHashiApprovalForMessage(hashMsg, true);
    }

    function _emitUserRequestForAffirmationIncreaseNonceAndMaybeSendDataWithHashi(address _receiver, uint256 _amount)
        internal
    {
        uint256 currentNonce = nonce();
        setNonce(currentNonce + 1);
        emit UserRequestForAffirmation(_receiver, _amount, bytes32(currentNonce));
        _maybeSendDataWithHashi(abi.encodePacked(_receiver, _amount, bytes32(currentNonce)));
    }

    /**
    * @dev Internal function for updating fallback gas price value.
    * @param _gasPrice new value for the gas price, zero gas price is not allowed.
    */
    function _setGasPrice(uint256 _gasPrice) internal {
        require(_gasPrice > 0);
        super._setGasPrice(_gasPrice);
    }

    /* solcov ignore next */
    function onExecuteMessage(address, uint256, bytes32) internal returns (bool);

    /* solcov ignore next */
    function onFailedMessage(address, uint256, bytes32) internal;
}
