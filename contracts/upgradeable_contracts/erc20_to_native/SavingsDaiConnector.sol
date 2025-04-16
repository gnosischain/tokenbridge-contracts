pragma solidity 0.4.24;

import "./InterestConnector.sol";
import "../../interfaces/ISavingsDai.sol";

/**
 * @title SavingsDaiConnector
 * @dev After the usds upgrade, this contract deposit locked USDS into Sky's SSR.
 * @dev The contract and functions name in this contract remains unchanged but the value of daiToken() and sDaiToken() are changed to Usds and sUsds address respectively.
 * @dev https://forum.gnosis.io/t/gip-118-should-sdai-be-replaced-by-susds-in-the-bridge/9354
 * @dev This must never be deployed standalone and only as an interface to interact with the sUSDS from the InterestConnector
 */
contract SavingsDaiConnector is InterestConnector {
    /**
     * @dev After the usds upgrade, this function returns the address of the USDS token in the Ethereum Mainnet instead of DAI token address.
     * @dev To minimize the changes on the bridge contract itself, the same function name is used but the address is changed. One should be aware when interacting with the contract.
     */
    function daiToken() public pure returns (ERC20) {
        return ERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    }

    /**
     * @dev After the usds upgrade, this function returns the address of the sUSDS token in the Ethereum Mainnet instead of sDAI token address.
     * @dev To minimize the changes on the bridge contract itself, the same function name is used but the address is changed. One should be aware when interacting with the contract.
     */
    function sDaiToken() public pure returns (ISavingsDai) {
        return ISavingsDai(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
    }

    /**
     * @dev Tells the current earned interest amount.
     * @param _token address of the underlying token contract.
     * @return total amount of interest that can be withdrawn now.
     */
    function interestAmount(address _token) public view returns (uint256) {
        require(_token == 0xdC035D45d973E3EC169d2276DDab16f1e407384F, "Not USDS");
        uint256 underlyingBalance = ISavingsDai(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD).maxWithdraw(address(this));
        // 1 DAI is reserved for possible truncation/round errors
        uint256 invested = investedAmount(_token) + 1 ether;
        return underlyingBalance > invested ? underlyingBalance - invested : 0;
    }

    /**
     * @dev Tells if interest earning is supported for the specific token contract.
     * @param _token address of the token contract.
     * @return true, if interest earning is supported.
     */
    function _isInterestSupported(address _token) internal pure returns (bool) {
        return _token == 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    }

    /**
     * @dev Invests the given amount of DAI to the sDAI Vault.
     * Deposits _amount of _token into the sDAI vault.
     * @param _token address of the token contract.
     * @param _amount amount of tokens to invest.
     */
    function _invest(address _token, uint256 _amount) internal {
        require(_token == 0xdC035D45d973E3EC169d2276DDab16f1e407384F, "not USDS");
        ERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F).approve(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, _amount);
        require(
            ISavingsDai(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD).deposit(_amount, address(this)) > 0,
            "Failed to deposit"
        );
    }

    /**
     * @dev Withdraws at least the given amount of USDS from the sUSDS vault contract.
     * Withdraws the _amount of _token from the sUSDS vault.
     * @param _token address of the token contract.
     * @param _amount minimal amount of tokens to withdraw.
     */
    function _withdrawTokens(address _token, uint256 _amount) internal {
        require(_token == 0xdC035D45d973E3EC169d2276DDab16f1e407384F, "not USDS");
        require(
            ISavingsDai(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD).withdraw(_amount, address(this), address(this)) > 0,
            "Failed to withdraw"
        );
    }

    /**
     * @dev Previews a withdraw of the given amount of DAI from the sDAI vault contract.
     * Previews withdrawing the _amount of _token from the sDAI vault.
     * @param _token address of the token contract.
     * @param _amount minimal amount of tokens to withdraw.
     */
    function previewWithdraw(address _token, uint256 _amount) public view returns (uint256) {
        require(_token == 0xdC035D45d973E3EC169d2276DDab16f1e407384F, "not USDS");
        return ISavingsDai(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD).previewWithdraw(_amount);
    }
}
