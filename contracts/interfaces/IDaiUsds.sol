// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.4.24;

interface IDaiUsds {
    event DaiToUsds(address indexed caller, address indexed usr, uint256 wad);
    event UsdsToDai(address indexed caller, address indexed usr, uint256 wad);

    function daiToUsds(address usr, uint256 wad) external;

    function usdsToDai(address usr, uint256 wad) external;

    function dai() external view returns (address);
    function usds() external view returns (address);
}
