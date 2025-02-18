pragma solidity ^0.8.10;

interface IXDaiForeignBridge {
    event DailyLimitChanged(uint256 newLimit);
    event ExecutionDailyLimitChanged(uint256 newLimit);
    event GasPriceChanged(uint256 gasPrice);
    event OwnershipTransferred(address previousOwner, address newOwner);
    event PaidInterest(address indexed token, address to, uint256 value);
    event RelayedMessage(address recipient, uint256 value, bytes32 transactionHash);
    event RequiredBlockConfirmationChanged(uint256 requiredBlockConfirmations);
    event UserRequestForAffirmation(address recipient, uint256 value);

    function claimTokens(address _token, address _to) external;
    function daiToken() external pure returns (address);
    function dailyLimit() external view returns (uint256);
    function decimalShift() external view returns (int256);
    function deployedAtBlock() external view returns (uint256);
    function disableInterest(address _token) external;
    function erc20token() external view returns (address);
    function executeSignatures(bytes memory message, bytes memory signatures) external;
    function executeSignaturesGSN(bytes memory message, bytes memory signatures, uint256 maxTokensFee) external;
    function executionDailyLimit() external view returns (uint256);
    function executionMaxPerTx() external view returns (uint256);
    function gasPrice() external view returns (uint256);
    function getBridgeInterfacesVersion() external pure returns (uint64 major, uint64 minor, uint64 patch);
    function getBridgeMode() external pure returns (bytes4 _data);
    function getCurrentDay() external view returns (uint256);
    function getTrustedForwarder() external view returns (address);
    function initialize(
        address _validatorContract,
        address _erc20token,
        uint256 _requiredBlockConfirmations,
        uint256 _gasPrice,
        uint256[3] memory _dailyLimitMaxPerTxMinPerTxArray,
        uint256[2] memory _homeDailyLimitHomeMaxPerTxArray,
        address _owner,
        int256 _decimalShift,
        address _bridgeOnOtherSide
    ) external returns (bool);
    function initializeInterest(
        address _token,
        uint256 _minCashThreshold,
        uint256 _minInterestPaid,
        address _interestReceiver
    ) external;
    function swapSDAIToUSDS() external;
    function interestAmount(address _token) external view returns (uint256);
    function interestReceiver(address _token) external view returns (address);
    function invest(address _token) external;
    function investDai() external;
    function investedAmount(address _token) external view returns (uint256);
    function isInitialized() external view returns (bool);
    function isInterestEnabled(address _token) external view returns (bool);
    function isTrustedForwarder(address forwarder) external view returns (bool);
    function maxAvailablePerTx() external view returns (uint256);
    function maxPerTx() external view returns (uint256);
    function minCashThreshold(address _token) external view returns (uint256);
    function minInterestPaid(address _token) external view returns (uint256);
    function minPerTx() external view returns (uint256);
    function owner() external view returns (address);
    function payInterest(address _token, uint256 _amount) external;
    function previewWithdraw(address _token, uint256 _amount) external view returns (uint256);
    function refillBridge() external;
    function relayTokens(address _receiver, uint256 _amount) external;
    function relayedMessages(bytes32 _nonce) external view returns (bool);
    function requiredBlockConfirmations() external view returns (uint256);
    function requiredSignatures() external view returns (uint256);
    function sDaiToken() external pure returns (address);
    function setDailyLimit(uint256 _dailyLimit) external;
    function setExecutionDailyLimit(uint256 _dailyLimit) external;
    function setExecutionMaxPerTx(uint256 _maxPerTx) external;
    function setGasPrice(uint256 _gasPrice) external;
    function setInterestReceiver(address _token, address _receiver) external;
    function setMaxPerTx(uint256 _maxPerTx) external;
    function setMinCashThreshold(address _token, uint256 _minCashThreshold) external;
    function setMinInterestPaid(address _token, uint256 _minInterestPaid) external;
    function setMinPerTx(uint256 _minPerTx) external;
    function setPayMaster(address _paymaster) external;
    function setRequiredBlockConfirmations(uint256 _blockConfirmations) external;
    function setTrustedForwarder(address _trustedForwarder) external;
    function totalExecutedPerDay(uint256 _day) external view returns (uint256);
    function totalSpentPerDay(uint256 _day) external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function validatorContract() external view returns (address);
    function versionRecipient() external view returns (string memory);
    function withinExecutionLimit(uint256 _amount) external view returns (bool);
    function withinLimit(uint256 _amount) external view returns (bool);
    function setNewErc20Token(address newDAI) external;
}
