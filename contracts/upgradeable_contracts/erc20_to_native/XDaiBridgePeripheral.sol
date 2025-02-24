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

    /// @notice claim the USDS token and convert to Dai for user
    /// @dev receiver should permit this contract to convert Usds to Dai by submitting permitSignature
    /// @param message data about the claiming tx for `executeSignatures`
    /// @param signatures signatures from bridge valdiators
    /// @param permitSignatures signature signed by the receiver of the tx to permit this contract doing the swap action)
    function executeSignaturesAndSwapToDai(bytes memory message, bytes memory signatures, bytes memory permitSignatures, uint256 permitDeadline)
        external
        onlyRouter
    {
        require(message.length == 104, "Invalid data length");
        IForeignBridge(FOREIGN_XDAIBRIDGE).executeSignatures(message, signatures);
        address recipient;
        uint256 amount;
        bytes32 nonce;
        address contractAddress;
        assembly {
            recipient := mload(add(message, 20))
            amount := mload(add(message, 52))
            nonce := mload(add(message, 84))
            contractAddress := mload(add(message, 104))
        }
        IERC20(USDS).permit(recipient, address(this), amount, permitDeadline, permitSignatures);
        IERC20(USDS).transferFrom(recipient, address(this), amount);
        IERC20(USDS).approve(DAIUSDS, amount);
        IDaiUsds(DAIUSDS).usdsToDai(recipient, amount);
    }

}
