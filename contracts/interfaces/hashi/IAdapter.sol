pragma solidity 0.4.24;

interface IAdapter {
    function getHash(uint256 domain, uint256 id) external view returns (bytes32 hash);
}
