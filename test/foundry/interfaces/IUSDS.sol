pragma solidity ^0.8.10;

import "forge-std/interfaces/IERC20.sol";

interface IUSDS is IERC20 {
    function nonces(address owner) external returns (uint256);
    function PERMIT_TYPEHASH() external returns (bytes32);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
