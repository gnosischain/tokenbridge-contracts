pragma solidity 0.4.24;

interface IYaho {
    function dispatchMessage(
        uint256 targetChainId,
        uint256 threshold,
        address receiver,
        bytes data,
        address[] reporters,
        address[] adapters
    ) external returns (uint256);
}
