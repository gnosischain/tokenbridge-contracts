pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/AddressUtils.sol";
import "./BasicForeignBridge.sol";
import "../interfaces/hashi/IYaho.sol";
import "../interfaces/hashi/IAdapter.sol";
import "../interfaces/hashi/IReporter.sol";

contract ERC20Bridge is BasicForeignBridge {
    bytes32 internal constant ERC20_TOKEN = 0x15d63b18dbc21bf4438b7972d80076747e1d93c4f87552fe498c90cbde51665e; // keccak256(abi.encodePacked("erc20token"))
    bytes32 internal constant ERC20_BRIDGE_NONCE = 0xca9e19a1c0ca75f6ed36b5c6f7a47c46eac340c34dfb0fe4eab36b8dbd6a27b8; // keccak256(abi.encodePacked("erc20BridgeNonce"))

    function erc20token() public view returns (ERC20) {
        return ERC20(addressStorage[ERC20_TOKEN]);
    }

    function setErc20token(address _token) internal {
        require(AddressUtils.isContract(_token));
        addressStorage[ERC20_TOKEN] = _token;
    }

    function nonce() public view returns (uint256) {
        return uintStorage[ERC20_BRIDGE_NONCE];
    }

    function setNonce(uint256 nonce) internal {
        uintStorage[ERC20_BRIDGE_NONCE] = nonce;
    }

    function relayTokens(address _receiver, uint256 _amount) public {
        require(_receiver != address(0), "Receiver can't be Null");
        require(_receiver != address(this), "Receiver can't be the Bridge");
        require(_amount > 0, "Relayed zero tokens");
        require(withinLimit(_amount), "Relayed above limit");
        addTotalSpentPerDay(getCurrentDay(), _amount);
        erc20token().transferFrom(msg.sender, address(this), _amount);
        _emitUserRequestForAffirmationMaybeRelayDataWithHashiAndIncreaseNonce(_receiver, _amount);
    }

    function _relayInterest(address _receiver, uint256 _amount) internal {
        require(_receiver != address(0), "Receiver can't be Null");
        require(_receiver != address(this), "Receiver can't be the Bridge");
        require(_amount > 0, "Relayed zero tokens");
        require(withinLimit(_amount), "Relayed above limit");
        addTotalSpentPerDay(getCurrentDay(), _amount);
        _emitUserRequestForAffirmationMaybeRelayDataWithHashiAndIncreaseNonce(_receiver, _amount);
    }

    function _emitUserRequestForAffirmationMaybeRelayDataWithHashiAndIncreaseNonce(address _receiver, uint256 _amount)
        internal
    {
        uint256 currentNonce = nonce();
        // NOTE: bytes32 cast is used to avoid breaking changes as the nonce is used to replace the transactionHash
        emit UserRequestForAffirmation(_receiver, _amount, bytes32(currentNonce));
        _maybeRelayDataWithHashi(abi.encodePacked(_receiver, _amount, bytes32(currentNonce)));
        setNonce(currentNonce + 1);
    }
}
