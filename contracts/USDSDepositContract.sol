pragma solidity 0.8.25;

interface IHomeBridgeErcToNative {
    function relayTokens(address recipient) external payable;
}

contract USDSDepositContract {
    address public constant xDAIBridge = 0x7301CFA0e1756B71869E93d4e4Dca5c7d0eb0AA6;

    receive() external payable {
        IHomeBridgeErcToNative(xDAIBridge).relayTokens{value: msg.value}(msg.sender);
    }

    function relayTokens(address recipient) external payable {
        IHomeBridgeErcToNative(xDAIBridge).relayTokens{value: msg.value}(recipient);
    }
}
