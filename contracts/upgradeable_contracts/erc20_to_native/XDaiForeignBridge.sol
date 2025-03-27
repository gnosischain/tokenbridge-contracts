pragma solidity 0.4.24;

import "./ForeignBridgeErcToNative.sol";
import "./SavingsDaiConnector.sol";
import "../GSNForeignERC20Bridge.sol";
import "../../interfaces/IDaiUsds.sol";

contract XDaiForeignBridge is ForeignBridgeErcToNative, SavingsDaiConnector, GSNForeignERC20Bridge {
    bool public constant IS_USDS_COLLATERALIZED = true;
    address public constant DAI_USDS = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

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

        // withdraw all sDAI into DAI
        uint256 maxWithdrawable = ISavingsDai(sDAI).maxWithdraw(address(this));
        ISavingsDai(sDAI).withdraw(maxWithdrawable, address(this), address(this));
        // disableInterest for DAI
        _setInvestedAmount(DAI, 0);
        _setInterestEnabled(DAI, false);
        _setMinCashThreshold(DAI, 0);
        _setMinInterestPaid(DAI, 0);

        // swap DAI -> USDS
        uint256 remainDAI = ERC20(DAI).balanceOf(address(this));
        ERC20(DAI).approve(DAI_USDS, remainDAI);
        IDaiUsds(DAI_USDS).daiToUsds(address(this), remainDAI);
        boolStorage[isUSDSBridgeUpgrade] = true;
    }

    /**
     * @dev Withdraws USDS from sUSDS vault to the bridge up to min cash threshold
     */
    function refillBridge() external {
        uint256 currentBalance = daiToken().balanceOf(address(this));
        uint256 minThreshold = minCashThreshold(address(daiToken()));
        require(currentBalance < minThreshold, "Bridge is Filled");
        uint256 withdrawAmount = minThreshold - currentBalance;
        _withdraw(address(daiToken()), withdrawAmount);
    }

    /**
     * @dev Invests the USDS into the sUSDS Vault.
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
     * @dev Validates provided signatures and relays a given message, recipient should receive USDS
     * @param message bytes to be relayed
     * @param signatures bytes blob with signatures to be validated
     */
    function executeSignaturesUSDS(bytes message, bytes signatures) external {
        Message.hasEnoughValidSignatures(message, signatures, validatorContract(), false);

        address recipient;
        uint256 amount;
        bytes32 nonce;
        address contractAddress;
        (recipient, amount, nonce, contractAddress) = Message.parseMessage(message);
        if (withinExecutionLimit(amount)) {
            require(contractAddress == address(this));
            require(!relayedMessages(nonce));
            setRelayedMessages(nonce, true);

            bytes32 hashMsg = keccak256(abi.encodePacked(recipient, amount, nonce));
            if (HASHI_IS_ENABLED && HASHI_IS_MANDATORY) require(isApprovedByHashi(hashMsg));

            require(onExecuteMessageUSDS(recipient, amount, nonce));
            emit RelayedMessage(recipient, amount, nonce);
        } else {
            onFailedMessage(recipient, amount, nonce);
        }
    }
    /**
     * @dev Withdraws the DAI tokens if they are mistakenly sent to this contract after the Hashi integration, as the Transfer event will no longer be supported.
     * @param _to address of the tokens/coins receiver.
     */

    function recoverLegacyTransfer(address _to) external onlyIfUpgradeabilityOwner {
        claimValues(DAI, _to);
    }

    function onExecuteMessage(address _recipient, uint256 _amount, bytes32 /*_nonce*/ ) internal returns (bool) {
        addTotalExecutedPerDay(getCurrentDay(), _amount);

        ERC20 token = daiToken();
        ensureEnoughTokens(token, _amount);

        if (IS_USDS_COLLATERALIZED) {
            // if bridge is upgraded to USDS, swap to DAI and send to recipient
            token.transfer(address(this), _amount);
            ERC20(USDS).approve(DAI_USDS, _amount);
            IDaiUsds(DAI_USDS).usdsToDai(address(this), _amount);
            return ERC20(DAI).transfer(_recipient, _amount);
        } else {
            ERC20(DAI).transfer(_recipient, _amount);
        }
    }

    function onExecuteMessageUSDS(address _recipient, uint256 _amount, bytes32 /*_nonce*/ ) internal returns (bool) {
        addTotalExecutedPerDay(getCurrentDay(), _amount);

        ERC20 token = daiToken();
        ensureEnoughTokens(token, _amount);

        if (IS_USDS_COLLATERALIZED) {
            // if bridge is upgraded to USDS, send Usds to recipient
            return token.transfer(_recipient, _amount);
        } else {
            revert();
        }
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
