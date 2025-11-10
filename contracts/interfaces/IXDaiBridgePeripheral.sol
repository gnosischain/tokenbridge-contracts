// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IXDaiBridgePeripheral {
    function DAI() external view returns (address);
    function DAIUSDS() external view returns (address);
    function FOREIGN_XDAIBRIDGE() external view returns (address);
    function USDS() external view returns (address);
    function relayTokens(address receiver, uint256 amount) external;
    function router() external view returns (address);
}
