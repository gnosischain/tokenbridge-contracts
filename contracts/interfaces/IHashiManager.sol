pragma solidity 0.4.24;

interface IHashiManager {
    function adapters() external view returns (address[]);

    function reporters() external view returns (address[]);

    function yaho() external view returns (address);

    function yaru() external view returns (address);

    function targetAddress() external view returns (address);

    function targetChainId() external view returns (uint256);

    function threshold() external view returns (uint256);
}
