pragma solidity ^0.8.0;

interface IForeignBridge {
    function relayTokens(address receiver, uint256 amount) external;
    function relayTokens(address token, address receiver, uint256 amount) external;
    function withinLimit(address token, uint256 amount) external returns (bool);
    function executeSignatures(bytes memory data, bytes memory signatures) external;
    function safeExecuteSignaturesWithAutoGasLimit(bytes memory data, bytes memory signatures) external;
}
