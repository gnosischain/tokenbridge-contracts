// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISUSDS {
    // Constructor
    function initialize(address usdsJoin_, address vow_) external;

    // Errors
    error AddressEmptyCode(address target);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error InvalidInitialization();
    error NotInitializing();
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    // Events
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deny(address indexed usr);
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Drip(uint256 chi, uint256 diff);
    event File(bytes32 indexed what, uint256 data);
    event Initialized(uint64 version);
    event Referral(uint16 indexed referral, address indexed owner, uint256 assets, uint256 shares);
    event Rely(address indexed usr);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Upgraded(address indexed implementation);
    event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    // Read-only functions
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external view returns (bytes32);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function allowance(address owner, address spender) external view returns (uint256);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function chi() external view returns (uint192);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function decimals() external view returns (uint8);
    function getImplementation() external view returns (address);
    function maxRedeem(address owner) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function proxiableUUID() external view returns (bytes32);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);

    // State-changing functions
    function approve(address spender, uint256 value) external returns (bool);
    function deny(address usr) external;
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function deposit(uint256 assets, address receiver, uint16 referral) external returns (uint256 shares);
    function drip() external returns (uint256 nChi);
    function file(bytes32 what, uint256 data) external;
    function initialize() external;
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function mint(uint256 shares, address receiver, uint16 referral) external returns (uint256 assets);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes calldata signature
    ) external;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
}
