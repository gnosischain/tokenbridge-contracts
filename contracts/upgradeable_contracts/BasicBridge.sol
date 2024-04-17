pragma solidity 0.4.24;

import "./Upgradeable.sol";
import "./InitializableBridge.sol";
import "openzeppelin-solidity/contracts/AddressUtils.sol";
import "./Validatable.sol";
import "./Ownable.sol";
import "./Claimable.sol";
import "./VersionableBridge.sol";
import "./DecimalShiftBridge.sol";
import "../interfaces/hashi/IYaho.sol";
import "../interfaces/hashi/IAdapter.sol";
import "../interfaces/hashi/IReporter.sol";

contract BasicBridge is
    InitializableBridge,
    Validatable,
    Ownable,
    Upgradeable,
    Claimable,
    VersionableBridge,
    DecimalShiftBridge
{
    event GasPriceChanged(uint256 gasPrice);
    event RequiredBlockConfirmationChanged(uint256 requiredBlockConfirmations);

    bytes32 internal constant GAS_PRICE = 0x55b3774520b5993024893d303890baa4e84b1244a43c60034d1ced2d3cf2b04b; // keccak256(abi.encodePacked("gasPrice"))
    bytes32 internal constant REQUIRED_BLOCK_CONFIRMATIONS = 0x916daedf6915000ff68ced2f0b6773fe6f2582237f92c3c95bb4d79407230071; // keccak256(abi.encodePacked("requiredBlockConfirmations"))
    bytes32 internal constant N_HASHI_ADAPTERS = 0xb84ed7af6cad1ac3db521f9b730295b9af9131ed3612f8f83e37ae030d440cdc; // keccak256(abi.encodePacked("nHashiAdapters"))
    bytes32 internal constant N_HASHI_REPORTERS = 0x90bd2a3289afeef413446382a0b9b2a4718473419286a503c22b5b61e9a5610b; // keccak256(abi.encodePacked("nHashiReporters"))
    bytes32 internal constant YAHO = 0xb947d41ce6141eb4dc972fcad3b49fe0eb8d5f59730728c86b8f6e1427912f0e; // keccak256(abi.encodePacked("yaho"))
    bytes32 internal constant YARU = 0x524607f5322f856f1415d60956f8220a13a3abe3281979fdb843027035724c76; // keccak256(abi.encodePacked("yaru"))
    bytes32 internal constant TARGET_AMB = 0x951fac2f6ac1586d0b31ff29b0f80314d0e14f9d116d97db8786bdb86e548285; // keccak256(abi.encodePacked("targetAmb"))
    bytes32 internal constant HASHI_TARGET_CHAIN_ID = 0xa6c3b41d4586b3220aecef5a5303a259a4af00db10885d9da4747b9352277114; // keccak256(abi.encodePacked("hashiTargetChainId"))
    bytes32 internal constant HASHI_THRESHOLD = 0xcee9971420de3ced933f6dc33d3cde97aa59ee5a4b2ac467f10f498085c856df; // keccak256(abi.encodePacked("hashiThreshold"))
    bool public constant HASHI_IS_ENABLED = true;

    /**
    * @dev Public setter for fallback gas price value. Only bridge owner can call this method.
    * @param _gasPrice new value for the gas price.
    */
    function setGasPrice(uint256 _gasPrice) external onlyOwner {
        _setGasPrice(_gasPrice);
    }

    function gasPrice() external view returns (uint256) {
        return uintStorage[GAS_PRICE];
    }

    function setRequiredBlockConfirmations(uint256 _blockConfirmations) external onlyOwner {
        _setRequiredBlockConfirmations(_blockConfirmations);
    }

    function _setRequiredBlockConfirmations(uint256 _blockConfirmations) internal {
        require(_blockConfirmations > 0);
        uintStorage[REQUIRED_BLOCK_CONFIRMATIONS] = _blockConfirmations;
        emit RequiredBlockConfirmationChanged(_blockConfirmations);
    }

    function requiredBlockConfirmations() external view returns (uint256) {
        return uintStorage[REQUIRED_BLOCK_CONFIRMATIONS];
    }

    function hashiAdapters() public view returns (address[]) {
        uint256 nAdapters = uintStorage[N_HASHI_ADAPTERS];
        address[] memory adapters = new address[](nAdapters);
        for (uint256 i = 0; i < nAdapters; i++)
            adapters[i] = addressStorage[keccak256(abi.encodePacked("hashiAdapters", i))];
        return adapters;
    }

    function setHashiAdapters(address[] adapters) external onlyOwner {
        uint256 nCurrentHashiAdapters = uintStorage[N_HASHI_ADAPTERS];
        for (uint256 i = 0; i < nCurrentHashiAdapters; i++)
            delete addressStorage[keccak256(abi.encodePacked("hashiAdapters", i))];
        uintStorage[N_HASHI_ADAPTERS] = adapters.length;
        for (uint256 j = 0; j < adapters.length; j++)
            addressStorage[keccak256(abi.encodePacked("hashiAdapters", j))] = adapters[j];
    }

    function hashiReporters() public view returns (address[]) {
        uint256 nReporters = uintStorage[N_HASHI_REPORTERS];
        address[] memory reporters = new address[](nReporters);
        for (uint256 i = 0; i < nReporters; i++)
            reporters[i] = addressStorage[keccak256(abi.encodePacked("hashiReporters", i))];
        return reporters;
    }

    function setHashiReporters(address[] reporters) external onlyOwner {
        uint256 nCurrentHashiAdapters = uintStorage[N_HASHI_REPORTERS];
        for (uint256 i = 0; i < nCurrentHashiAdapters; i++)
            delete addressStorage[keccak256(abi.encodePacked("hashiReporters", i))];
        uintStorage[N_HASHI_REPORTERS] = reporters.length;
        for (uint256 j = 0; j < reporters.length; j++)
            addressStorage[keccak256(abi.encodePacked("hashiReporters", j))] = reporters[j];
    }

    function yaho() public view returns (address) {
        return addressStorage[YAHO];
    }

    function setYaho(address yaho_) external onlyOwner {
        addressStorage[YAHO] = yaho_;
    }

    function yaru() public view returns (address) {
        return addressStorage[YARU];
    }

    function setYaru(address yaru_) external onlyOwner {
        addressStorage[YARU] = yaru_;
    }

    function targetAmb() public view returns (address) {
        return addressStorage[TARGET_AMB];
    }

    function setTargetAmb(address targetAmb_) external onlyOwner {
        addressStorage[TARGET_AMB] = targetAmb_;
    }

    function hashiTargetChainId() public view returns (uint256) {
        return uintStorage[HASHI_TARGET_CHAIN_ID];
    }

    function setHashiTargetChainId(uint256 targetChainId_) external onlyOwner {
        uintStorage[HASHI_TARGET_CHAIN_ID] = targetChainId_;
    }

    function hashiThreshold() public view returns (uint256) {
        return uintStorage[HASHI_THRESHOLD];
    }

    function setHashiThreshold(uint256 threshold) external onlyOwner {
        uintStorage[HASHI_THRESHOLD] = threshold;
    }

    /**
    * @dev Internal function for updating fallback gas price value.
    * @param _gasPrice new value for the gas price, zero gas price is allowed.
    */
    function _setGasPrice(uint256 _gasPrice) internal {
        uintStorage[GAS_PRICE] = _gasPrice;
        emit GasPriceChanged(_gasPrice);
    }

    function _maybeRelayDataWithHashi(bytes data) internal {
        if (HASHI_IS_ENABLED) {
            address[] memory hReporters = hashiReporters();
            IReporter[] memory reporters = new IReporter[](hReporters.length);
            for (uint256 i = 0; i < hReporters.length; i++) reporters[i] = IReporter(hReporters[i]);

            address[] memory hAdapters = hashiAdapters();
            IAdapter[] memory adapters = new IAdapter[](hAdapters.length);
            for (uint256 j = 0; j < hAdapters.length; j++) adapters[j] = IAdapter(hAdapters[j]);

            IYaho(yaho()).dispatchMessage(
                hashiTargetChainId(),
                hashiThreshold(),
                targetAmb(),
                data,
                reporters,
                adapters
            );
        }
    }
}
