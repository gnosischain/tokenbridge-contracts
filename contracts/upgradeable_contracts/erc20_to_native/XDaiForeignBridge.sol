pragma solidity 0.4.24;

import "./ForeignBridgeErcToNative.sol";
import "./SavingsDaiConnector.sol";
import "../GSNForeignERC20Bridge.sol";
import "../../interfaces/IDaiUsds.sol";

contract XDaiForeignBridge is ForeignBridgeErcToNative, SavingsDaiConnector, GSNForeignERC20Bridge {
    function initialize(
        address _validatorContract,
        address _erc20token,
        uint256 _requiredBlockConfirmations,
        uint256 _gasPrice,
        uint256[3] _dailyLimitMaxPerTxMinPerTxArray, // [ 0 = _dailyLimit, 1 = _maxPerTx, 2 = _minPerTx ]
        uint256[2] _homeDailyLimitHomeMaxPerTxArray, //[ 0 = _homeDailyLimit, 1 = _homeMaxPerTx ]
        address _owner,
        int256 _decimalShift,
        address _bridgeOnOtherSide
    ) external onlyRelevantSender returns (bool) {
        require(!isInitialized());
        require(AddressUtils.isContract(_validatorContract));
        require(_erc20token == address(daiToken()));
        require(_decimalShift == 0);

        addressStorage[VALIDATOR_CONTRACT] = _validatorContract;
        uintStorage[DEPLOYED_AT_BLOCK] = block.number;
        _setRequiredBlockConfirmations(_requiredBlockConfirmations);
        _setGasPrice(_gasPrice);
        _setLimits(_dailyLimitMaxPerTxMinPerTxArray);
        _setExecutionLimits(_homeDailyLimitHomeMaxPerTxArray);
        _setOwner(_owner);
        _setBridgeContractOnOtherSide(_bridgeOnOtherSide);
        setInitialize();

        return isInitialized();
    }

    /**
     * @dev return the address of USDS
     */
    function erc20token() public view returns (ERC20) {
        return daiToken();
    }

    /**
     * @dev one time function to be called during bridge upgrade
     */
    function swapSDAIToUSDS() public {
        bytes32 isUSDSBridgeUpgrade = keccak256("upgrade_DAI_to_USDS");
        require(!boolStorage[isUSDSBridgeUpgrade], "USDS bridge ugprade completed");

        address sDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address DaiUsds = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;

        // withdraw all sDAI into DAI
        uint256 maxWithdrawable = ISavingsDai(sDAI).maxWithdraw(address(this));
        ISavingsDai(sDAI).withdraw(maxWithdrawable, address(this), address(this));
        // disableInterest for DAI
        _setInvestedAmount(DAI, 0);
        _setInterestEnabled(DAI, false);

        // swap DAI -> USDS
        uint256 remainDAI = ERC20(DAI).balanceOf(address(this));
        ERC20(DAI).approve(DaiUsds, remainDAI);
        IDaiUsds(DaiUsds).daiToUsds(address(this), remainDAI);

        boolStorage[isUSDSBridgeUpgrade] = true;
    }

    /**
     * @dev Withdraws DAI from sDAI vault to the bridge up to min cash threshold
     */
    function refillBridge() external {
        uint256 currentBalance = daiToken().balanceOf(address(this));
        uint256 minThreshold = minCashThreshold(address(daiToken()));
        require(currentBalance < minThreshold, "Bridge is Filled");
        uint256 withdrawAmount = minThreshold - currentBalance;
        _withdraw(address(daiToken()), withdrawAmount);
    }

    /**
     * @dev Invests the DAI into the sDAI Vault.
     */
    function investDai() external {
        invest(address(daiToken()));
    }

    /**
     * @dev Withdraws the erc20 tokens or native coins from this contract.
     * @param _token address of the claimed token or address(0) for native coins.
     * @param _to address of the tokens/coins receiver.
     */
    function claimTokens(address _token, address _to) external onlyIfUpgradeabilityOwner {
        // Since bridged tokens are locked at this contract, it is not allowed to claim them with the use of claimTokens function
        address bridgedToken = address(daiToken());
        require(_token != address(bridgedToken), "Can't claim DAI");
        require(_token != address(sDaiToken()) || !isInterestEnabled(bridgedToken), "Can't claim sDAI");
        claimValues(_token, _to);
    }

    /**
     * @dev Withdraws the DAI tokens if they are mistakenly sent to this contract after the Hashi integration, as the Transfer event will no longer be supported.
     * @param _to address of the tokens/coins receiver.
     */
    function recoverLegacyTransfer(address _to) external onlyIfUpgradeabilityOwner {
        claimValues(address(daiToken()), _to);
    }

    function onExecuteMessage(
        address _recipient,
        uint256 _amount,
        bytes32 /*_nonce*/
    ) internal returns (bool) {
        addTotalExecutedPerDay(getCurrentDay(), _amount);

        ERC20 token = daiToken();
        ensureEnoughTokens(token, _amount);

        return token.transfer(_recipient, _amount);
    }

    function onExecuteMessageGSN(address recipient, uint256 amount, uint256 fee) internal returns (bool) {
        ensureEnoughTokens(daiToken(), amount);

        return super.onExecuteMessageGSN(recipient, amount, fee);
    }

    function ensureEnoughTokens(ERC20 token, uint256 amount) internal {
        uint256 currentBalance = token.balanceOf(address(this));

        if (currentBalance < amount) {
            uint256 withdrawAmount = (amount - currentBalance).add(minCashThreshold(address(token)));
            _withdraw(address(token), withdrawAmount);
        }
    }
}
