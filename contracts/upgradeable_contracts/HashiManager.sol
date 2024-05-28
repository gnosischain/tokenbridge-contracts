pragma solidity 0.4.24;

import "./Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./InitializableBridge.sol";

contract HashiManager is InitializableBridge, Ownable {
    bytes32 internal constant N_ADAPTERS = 0xdcf7815b28c450099ee39fe328212215e261dd8ce26acdea76caf742d778991e; // keccak256(abi.encodePacked("nAdapters"))
    bytes32 internal constant N_REPORTERS = 0x7759f17e5239c7f5c713a5c2ca4f103cbe6896de01dabfb0d08276642d579e33; // keccak256(abi.encodePacked("nReporters"))
    bytes32 internal constant YAHO = 0xb947d41ce6141eb4dc972fcad3b49fe0eb8d5f59730728c86b8f6e1427912f0e; // keccak256(abi.encodePacked("yaho"))
    bytes32 internal constant YARU = 0x524607f5322f856f1415d60956f8220a13a3abe3281979fdb843027035724c76; // keccak256(abi.encodePacked("yaru"))
    bytes32 internal constant TARGET_ADDRESS = 0x2f1696ba9bd43014bc580768c9270c32ad765cbf97d2a2ba5e81ab9f1ee90561; // keccak256(abi.encodePacked("targetAddress"))
    bytes32 internal constant TARGET_CHAIN_ID = 0xbd2b577e24554caf96874c1f333079c108fe5afbd441f36a76920df41d10820c; // keccak256(abi.encodePacked("targetChainId"))
    bytes32 internal constant THRESHOLD = 0xd46c2b20c7303c2e50535d224276492e8a1eda2a3d7398e0bea254640c1154e7; // keccak256(abi.encodePacked("threshold"))

    function initialize(address _owner) external onlyRelevantSender returns (bool) {
        require(!isInitialized());
        _setOwner(_owner);
        setInitialize();
        return isInitialized();
    }

    function setReportersAdaptersAndThreshold(address[] reporters, address[] adapters, uint256 threshold)
        external
        onlyOwner
    {
        _setArray(N_REPORTERS, "reporters", reporters);
        _setArray(N_ADAPTERS, "adapters", adapters);
        uintStorage[THRESHOLD] = threshold;
    }

    function adapters() external view returns (address[]) {
        return _getArray(N_ADAPTERS, "adapters");
    }

    function reporters() external view returns (address[]) {
        return _getArray(N_REPORTERS, "reporters");
    }

    function yaho() external view returns (address) {
        return addressStorage[YAHO];
    }

    function setYaho(address yaho_) external onlyOwner {
        addressStorage[YAHO] = yaho_;
    }

    function yaru() external view returns (address) {
        return addressStorage[YARU];
    }

    function setYaru(address yaru_) external onlyOwner {
        addressStorage[YARU] = yaru_;
    }

    function targetAddress() external view returns (address) {
        return addressStorage[TARGET_ADDRESS];
    }

    function setTargetAddress(address targetAddress_) external onlyOwner {
        addressStorage[TARGET_ADDRESS] = targetAddress_;
    }

    function targetChainId() external view returns (uint256) {
        return uintStorage[TARGET_CHAIN_ID];
    }

    function setTargetChainId(uint256 targetChainId_) external onlyOwner {
        uintStorage[TARGET_CHAIN_ID] = targetChainId_;
    }

    function threshold() external view returns (uint256) {
        return uintStorage[THRESHOLD];
    }

    function _getArray(bytes32 keyLength, bytes32 key) internal view returns (address[]) {
        uint256 n = uintStorage[keyLength];
        address[] memory values = new address[](n);
        for (uint256 i = 0; i < n; i++) values[i] = addressStorage[keccak256(abi.encodePacked(key, i))];
        return values;
    }

    function _setArray(bytes32 keyLength, bytes32 key, address[] values) internal {
        uint256 n = uintStorage[keyLength];
        for (uint256 i = 0; i < n; i++) delete addressStorage[keccak256(abi.encodePacked(key, i))];
        uintStorage[keyLength] = values.length;
        for (uint256 j = 0; j < values.length; j++) addressStorage[keccak256(abi.encodePacked(key, j))] = values[j];
    }
}
