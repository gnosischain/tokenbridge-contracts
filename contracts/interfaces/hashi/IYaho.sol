pragma solidity 0.4.24;

import "./IAdapter.sol";
import "./IReporter.sol";

interface IYaho {
    function dispatchMessage(
        uint256 targetChainId,
        uint256 threshold,
        address receiver,
        bytes data,
        IReporter[] reporters,
        IAdapter[] adapters
    ) external returns (uint256);
}
