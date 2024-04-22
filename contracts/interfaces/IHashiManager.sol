pragma solidity 0.4.24;

interface IHashiManager {
    function hashiAdapters() external view returns (address[]);

    function hashiReporters() external view returns (address[]);

    function yaho() external view returns (address);

    function yaru() external view returns (address);

    function hashiTargetAddress() external view returns (address);

    function hashiTargetChainId() external view returns (uint256);

    function hashiThreshold() external view returns (uint256);
}
