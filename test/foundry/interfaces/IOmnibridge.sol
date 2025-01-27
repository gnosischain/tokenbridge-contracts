pragma solidity ^0.8.0;

interface IOmnibridge {
    function relayTokens(address token, address receiver, uint256 amount) external;
    function withinLimit(address token, uint256 amount) external returns (bool);
    function dailyLimit(address token) external returns(uint256);
}