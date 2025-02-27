pragma solidity ^0.8.0;

import { IXDaiForeignBridge } from "../../interfaces/IXDaiForeignBridge.sol";
import { IERC20 } from "../../interfaces/IERC20.sol";

interface IDaiUsds {
    function daiToUsds(address usr, uint256 wad) external;
    function usdsToDai(address usr, uint256 wad) external;
}

/// @title XDaiBridgePeripheralForUsdsPreUsdsUpgrade
/// @author Gnosis Chain's bridge team
/// @notice This contract acts as a transitional contract between BridgeRouter and xDAIForeignBridge contract before xDAIForeignBridge is upgraded to USDS as default
///          The functions in this contract are compatible with the XDaiBridgePeripheral contract that is used after xDAIForeignBridge USDS upgrade
/// @dev This contract is non upgradeable and only callable by BridgeRouter contract
contract XDaiBridgePeripheralForUsdsPreUsdsUpgrade {
    address public router;
    address public constant DAIUSDS = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;
    address public constant FOREIGN_XDAIBRIDGE = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    modifier onlyRouter() {
        require(msg.sender == router, "only Router");
        _;
    }

    constructor(address _router) {
        router = _router;
    }

    /// @notice call approve & relayTokens after swapping USDS to DAI
    /// @dev only callable by BridgeRouter
    /// @param receiver receiver of the xDAI token on Gnosis Chain
    /// @param amount amount of xDAI token received
    function relayTokens(address receiver, uint256 amount) external onlyRouter {
        // user bridge USDS
        IERC20(USDS).transferFrom(msg.sender, address(this), amount);

        // swap Usds to Dai
        IERC20(USDS).approve(DAIUSDS, amount);
        IDaiUsds(DAIUSDS).usdsToDai(address(this), amount);
        require(IERC20(DAI).balanceOf(address(this)) == amount, "swap unsuccessfull");

        // call XDaibridge relayTokens
        IERC20(DAI).approve(FOREIGN_XDAIBRIDGE, amount);
        IXDaiForeignBridge(FOREIGN_XDAIBRIDGE).relayTokens(receiver, amount);

    }
}
