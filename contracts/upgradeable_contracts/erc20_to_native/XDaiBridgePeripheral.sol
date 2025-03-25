pragma solidity ^0.8.0;

import { IForeignBridge } from "../../interfaces/IForeignBridge.sol";
import { IERC20 } from "../../interfaces/IERC20.sol";

interface IDaiUsds {
    function daiToUsds(address usr, uint256 wad) external;
    function usdsToDai(address usr, uint256 wad) external;
}

/// @title XdaiBridgePeripheral
/// @author Gnosis Chain's bridge team
/// @notice A peripheral contract to allow user to deposit DAI, convert it into USDS and call XDai Bridge relayTokens
/// @dev This contract is non upgradeable and only callable by BridgeRouter contract
contract XDaiBridgePeripheral {
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

    /// @notice Convert Dai to Usds and relayTokens on behalf of user
    /// @dev only callable by BridgeRouter
    /// @param receiver receiver of the xDAI token on Gnosis Chain
    /// @param amount amount of xDAI token received
    function relayTokens(address receiver, uint256 amount) external onlyRouter {
        // swap Dai to Usds
        IERC20(DAI).approve(DAIUSDS, amount);
        IDaiUsds(DAIUSDS).daiToUsds(address(this), amount);

        // call XDaibridge relayTokens
        IERC20(USDS).approve(FOREIGN_XDAIBRIDGE, amount);
        IForeignBridge(FOREIGN_XDAIBRIDGE).relayTokens(receiver, amount);
    }
}
