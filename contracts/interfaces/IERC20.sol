pragma solidity ^0.8.0;

interface IERC20 {
    function approve(address usr, uint256 wad) external;
    function allowance(address owner, address spender, uint256 amount) external returns (uint256);
    function permit(address owner, address spender, uint256 amount, uint256 deadline, bytes memory signatures) external;
    function transferFrom(address owner, address spender, uint256 amount) external;
    function transfer(address usr, uint256 wad) external;
    function balanceOf(address usr) external returns (uint256);
}
