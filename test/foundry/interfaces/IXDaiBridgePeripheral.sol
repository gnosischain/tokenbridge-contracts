pragma solidity ^0.8.0;

interface IXdaiBridgePeripheral {
    function relayTokens(address receiver, uint256 amount) external;
    function executeSignaturesAndSwapToDai(bytes memory message, bytes memory signatures, bytes memory permitSignatures)
        external;

}
