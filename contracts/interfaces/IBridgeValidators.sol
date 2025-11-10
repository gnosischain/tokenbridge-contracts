pragma solidity 0.4.24;

interface IBridgeValidators {
    function isValidator(address _validator) external view returns (bool);
    function requiredSignatures() external view returns (uint256);
    function owner() external view returns (address);
    function addValidator(address _validator) external;
    function removeValidator(address _validator) external;
    function setRequiredSignatures(uint256 _requiredSignatures) external;
}
