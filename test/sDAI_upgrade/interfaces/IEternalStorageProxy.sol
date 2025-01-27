pragma solidity ^0.8.10;

interface IEternalStorageProxy {
    event ProxyOwnershipTransferred(address previousOwner, address newOwner);
    event Upgraded(uint256 version, address indexed implementation);

    function implementation() external view returns (address);
    function proxyOwner() external view returns (address);
    function transferProxyOwnership(address newOwner) external;
    function upgradeTo(uint256 version, address implementation) external;
    function upgradeToAndCall(uint256 version, address implementation, bytes memory data) external payable;
    function upgradeabilityOwner() external view returns (address);
    function version() external view returns (uint256);
}
