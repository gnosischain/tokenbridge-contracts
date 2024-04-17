pragma solidity 0.4.24;

import "./IAdapter.sol";

interface IReporter {
    function dispatchBlocks(uint256 targetChainId, IAdapter adapter, uint256[] blockNumbers)
        external
        payable
        returns (bytes32);

    function dispatchMessages(uint256 targetChainId, IAdapter adapter, uint256[] messageIds, bytes32[] messageHashes)
        external
        payable
        returns (bytes32);
}
