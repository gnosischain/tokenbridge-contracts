pragma solidity 0.4.24;

import "../interfaces/IBridgeValidators.sol";
import "../upgradeability/EternalStorage.sol";
import "./ValidatorStorage.sol";

contract Validatable is EternalStorage, ValidatorStorage {
    function validatorContract() public view returns (IBridgeValidators) {
        return IBridgeValidators(addressStorage[VALIDATOR_CONTRACT]);
    }

    function requiredSignatures() public view returns (uint256) {
        return validatorContract().requiredSignatures();
    }

    function _onlyValidator() internal {
        require(validatorContract().isValidator(msg.sender));
    }

}
