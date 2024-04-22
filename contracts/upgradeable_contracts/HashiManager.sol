pragma solidity 0.4.24;

import "./Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./InitializableBridge.sol";

contract HashiManager is InitializableBridge, Ownable {
    bytes32 internal constant N_HASHI_ADAPTERS = 0xb84ed7af6cad1ac3db521f9b730295b9af9131ed3612f8f83e37ae030d440cdc; // keccak256(abi.encodePacked("nHashiAdapters"))
    bytes32 internal constant N_HASHI_REPORTERS = 0x90bd2a3289afeef413446382a0b9b2a4718473419286a503c22b5b61e9a5610b; // keccak256(abi.encodePacked("nHashiReporters"))
    bytes32 internal constant YAHO = 0xb947d41ce6141eb4dc972fcad3b49fe0eb8d5f59730728c86b8f6e1427912f0e; // keccak256(abi.encodePacked("yaho"))
    bytes32 internal constant YARU = 0x524607f5322f856f1415d60956f8220a13a3abe3281979fdb843027035724c76; // keccak256(abi.encodePacked("yaru"))
    bytes32 internal constant HASHI_TARGET_ADDRESS = 0x70bc570ef0635df82f171427ad68afc63c0c8b7ec49d4ca0acc4591acb9f2111; // keccak256(abi.encodePacked("hashiTargetAddress"))
    bytes32 internal constant HASHI_TARGET_CHAIN_ID = 0xa6c3b41d4586b3220aecef5a5303a259a4af00db10885d9da4747b9352277114; // keccak256(abi.encodePacked("hashiTargetChainId"))
    bytes32 internal constant HASHI_THRESHOLD = 0xcee9971420de3ced933f6dc33d3cde97aa59ee5a4b2ac467f10f498085c856df; // keccak256(abi.encodePacked("hashiThreshold"))

    function hashiAdapters() external view returns (address[]) {
        uint256 nAdapters = uintStorage[N_HASHI_ADAPTERS];
        address[] memory adapters = new address[](nAdapters);
        for (uint256 i = 0; i < nAdapters; i++)
            adapters[i] = addressStorage[keccak256(abi.encodePacked("hashiAdapters", i))];
        return adapters;
    }

    function setHashiAdapters(address[] _adapters) external onlyOwner {
        _resetAdaptersOrReporters(N_HASHI_ADAPTERS, "hashiAdapters", _adapters);
    }

    function hashiReporters() external view returns (address[]) {
        uint256 nReporters = uintStorage[N_HASHI_REPORTERS];
        address[] memory reporters = new address[](nReporters);
        for (uint256 i = 0; i < nReporters; i++)
            reporters[i] = addressStorage[keccak256(abi.encodePacked("hashiReporters", i))];
        return reporters;
    }

    function setHashiReporters(address[] _reporters) external onlyOwner {
        _resetAdaptersOrReporters(N_HASHI_REPORTERS, "hashiReporters", _reporters);
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

    function hashiTargetAddress() external view returns (address) {
        return addressStorage[HASHI_TARGET_ADDRESS];
    }

    function setHashiTargetAddress(address hashiTargetAddress_) external onlyOwner {
        addressStorage[HASHI_TARGET_ADDRESS] = hashiTargetAddress_;
    }

    function hashiTargetChainId() external view returns (uint256) {
        return uintStorage[HASHI_TARGET_CHAIN_ID];
    }

    function setHashiTargetChainId(uint256 targetChainId_) external onlyOwner {
        uintStorage[HASHI_TARGET_CHAIN_ID] = targetChainId_;
    }

    function hashiThreshold() external view returns (uint256) {
        return uintStorage[HASHI_THRESHOLD];
    }

    function setHashiThreshold(uint256 threshold) external onlyOwner {
        uintStorage[HASHI_THRESHOLD] = threshold;
    }

    function _resetAdaptersOrReporters(bytes32 keyLength, bytes32 key, address[] values) internal {
        uint256 n = uintStorage[keyLength];
        for (uint256 i = 0; i < n; i++) delete addressStorage[keccak256(abi.encodePacked(key, i))];
        uintStorage[keyLength] = values.length;
        for (uint256 j = 0; j < values.length; j++) addressStorage[keccak256(abi.encodePacked(key, j))] = values[j];
    }
}
