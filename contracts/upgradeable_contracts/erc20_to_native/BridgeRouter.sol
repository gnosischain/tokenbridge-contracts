pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IForeignBridge } from "../../interfaces/IForeignBridge.sol";
import { IXDaiForeignBridge } from "../../interfaces/IXDaiForeignBridge.sol";
import { IXDaiBridgePeripheral } from "../../interfaces/IXDaiBridgePeripheral.sol";
import { IERC20 } from "../../interfaces/IERC20.sol";
import { IWETHOmnibridgeRouter } from "../../interfaces/IWETHOmnibridgeRouter.sol";

/// @title BridgeRouter
/// @author Gnosis Chain Bridge team
/// @notice A router contract that facilitates the correct routing for specific token that bridges to Gnosis Chain
/// @dev this intended to be an upgradeable contract
contract BridgeRouter is OwnableUpgradeable {

    address public constant FOREIGN_OMNIBRIDGE = 0x88ad09518695c6c3712AC10a214bE5109a655671;
    address public constant FOREIGN_AMB = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
    address public constant FOREIGN_XDAIBRIDGE = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant WETH_OMNIBRIDGE_ROUTER = 0xa6439Ca0FCbA1d0F80df0bE6A17220feD9c9038a;

    mapping(address => address) public tokenRoutes;

    constructor(){
        _disableInitializers();
    }

    function initialize(address owner) public initializer {
        __Ownable_init(owner);
    }


    /// @notice An entry point contract for user to bridge any token from source chain
    /// @dev Directs route to relevant contract to perform token relaying
    /// @param _token token to bridge
    /// @param _receiver receiver of token on Gnosis Chain
    /// @param _amount amount to receive on Gnosis Chain
    function relayTokens(address _token, address _receiver, uint256 _amount) external payable {
        address route = tokenRoutes[_token];

        if (_token == DAI) {
            IERC20(_token).transferFrom(msg.sender, route, _amount);
            IXDaiBridgePeripheral(route).relayTokens(_receiver, _amount);
        } else if (_token == USDS) {
            // token need to be transferred to router contract first, because the bridge will call transferFrom(msg.sender, bridge, amount);
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            IERC20(_token).approve(route, _amount);
            IXDaiForeignBridge(route).relayTokens(_receiver, _amount);
        } else if(_token == address(0)){
            // call wrapAndRelayTokens
            require(msg.value == _amount, "msg.value mismatch");
            IWETHOmnibridgeRouter(WETH_OMNIBRIDGE_ROUTER).wrapAndRelayTokens{value: msg.value}(_receiver);
        }   
        else {
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            IERC20(_token).approve(FOREIGN_OMNIBRIDGE, _amount);
            IForeignBridge(FOREIGN_OMNIBRIDGE).relayTokens(_token, _receiver, _amount);
        }
    }

    /// @notice Set route for specific token. Be aware of pending cross chain transactions before updating the route.
    /// @param _token token address
    /// @param _route router contract address
    function setRoute(address _token, address _route) public onlyOwner {
        require(_route != address(0) && _route != address(this), "invalid route address");
        uint256 size;
        assembly {
            size := extcodesize(_route)
        }
        require(size > 0, "route should be a contract");
        tokenRoutes[_token] = _route;
    }

    /// @notice Claim token function
    /// @dev This function check if the data belongs of xDAI bridge or AMB/Omnibridge
    /// @param message for claiming tx
    /// @param signatures signatures from bridge validators
    function executeSignatures(bytes memory message, bytes memory signatures) external {
        if (message.length == 104) {
            // xdai bridge
            IForeignBridge(FOREIGN_XDAIBRIDGE).executeSignatures(message, signatures);
        } else {
            // amb & omnibridge
            IForeignBridge(FOREIGN_AMB).safeExecuteSignaturesWithAutoGasLimit(message, signatures);
        }
    }

    /// @notice Claim function and receive DAI
    /// @dev Receiver of the token should sign and submit signature to allow peripheral contract swapping Usds to Dai
    /// @param message data for claiming tx
    /// @param signatures signatures from bridge validators
    /// @param permitSignatures permit signature by token receiver
    function executeSignaturesAndSwapToDai(bytes memory message, bytes memory signatures, bytes memory permitSignatures, uint256 permitDeadline)
        external
    {
        require(message.length == 104, "invalid message length");
        address xdaiBridgePeripheral = tokenRoutes[DAI];
        IXDaiBridgePeripheral(xdaiBridgePeripheral).executeSignaturesAndSwapToDai(
            message,
            signatures,
            permitSignatures,
            permitDeadline
        );
    }

    /// @notice Allows to transfer any locked token from this contract.
    /// @param token token to recover
    /// @param recipient recipient of token
    /// @param amount token amount
    function recoverLockedFund(address token, address recipient, uint256 amount) external onlyOwner {
        if(token == address(0)){
            uint256 balance = address(this).balance;
            require(amount <= balance, "no enough ETH to withdraw");
            require(payable(recipient).send(amount), "unsuccesssful sent");
        }else{
            require(amount <= IERC20(token).balanceOf(address(this)), "no enough balance to withdraw");
            IERC20(token).transfer(recipient, amount);
        }
       
    }
}
