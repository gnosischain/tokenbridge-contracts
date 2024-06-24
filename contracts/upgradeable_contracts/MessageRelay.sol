pragma solidity 0.4.24;

import "../upgradeability/EternalStorage.sol";

contract MessageRelay is EternalStorage {
    function relayedMessages(bytes32 _nonce) public view returns (bool) {
        return boolStorage[keccak256(abi.encodePacked("relayedMessages", _nonce))];
    }

    function setRelayedMessages(bytes32 _nonce, bool _status) internal {
        boolStorage[keccak256(abi.encodePacked("relayedMessages", _nonce))] = _status;
    }
}
