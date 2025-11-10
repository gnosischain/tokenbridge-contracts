pragma solidity ^0.8.0;

interface IHomeBridgeErcToNative {
    function relayTokens(address receiver) external payable;
    function maxAvailablePerTx() external returns (uint256);
    function maxPerTx() external returns (uint256);
    function minPerTx() external returns (uint256);
    function withinLimit(uint256 _amount) external returns (bool);
    function submitSignature(bytes memory signature, bytes memory message) external;
    function nonce() external view returns (uint256);
    function executeAffirmation(address recipient, uint256 value, bytes32 nonce) external;
    function withinExecutionLimit(uint256 _amount) external returns (bool);
    function fixAssetsAboveLimits(bytes32 messageId, bool unlockOnForeign, uint256 valueToUnlock, address tokenAddress)
        external;
    function outOfLimitAmount() external returns (uint256);
    function totalExecutedPerDay(uint256 _day) external returns (uint256);
    function getCurrentDay() external returns (uint256);
    function executionDailyLimit() external returns (uint256);
    function upgradeabilityOwner() external returns (address);
    receive() external payable;
}
