pragma solidity 0.4.24;

/**
 * @title Bytes
 * @dev Helper methods to transform bytes to other solidity types.
 */
library Bytes {
    /**
    * @dev Converts bytes array to bytes32.
    * Truncates bytes array if its size is more than 32 bytes.
    * NOTE: This function does not perform any checks on the received parameter.
    * Make sure that the _bytes argument has a correct length, not less than 32 bytes.
    * A case when _bytes has length less than 32 will lead to the undefined behaviour,
    * since assembly will read data from memory that is not related to the _bytes argument.
    * @param _bytes to be converted to bytes32 type
    * @return bytes32 type of the firsts 32 bytes array in parameter.
    */
    function bytesToBytes32(bytes _bytes) internal pure returns (bytes32 result) {
        assembly {
            result := mload(add(_bytes, 32))
        }
    }

    /**
    * @dev Truncate bytes array if its size is more than 20 bytes.
    * NOTE: Similar to the bytesToBytes32 function, make sure that _bytes is not shorter than 20 bytes.
    * @param _bytes to be converted to address type
    * @return address included in the firsts 20 bytes of the bytes array in parameter.
    */
    function bytesToAddress(bytes _bytes) internal pure returns (address addr) {
        assembly {
            addr := mload(add(_bytes, 20))
        }
    }

    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        require(data.length >= start + length);

        bytes memory tempData;
        assembly {
            switch iszero(length)
                case 0 {
                    tempData := mload(0x40)
                    let lengthmod := and(length, 31)
                    let mc := add(add(tempData, lengthmod), mul(0x20, iszero(lengthmod)))
                    let end := add(mc, length)

                    for {
                        let cc := add(add(add(data, lengthmod), mul(0x20, iszero(lengthmod))), start)
                    } lt(mc, end) {
                        mc := add(mc, 0x20)
                        cc := add(cc, 0x20)
                    } {
                        mstore(mc, mload(cc))
                    }
                    mstore(tempData, length)
                    mstore(0x40, and(add(mc, 31), not(31)))
                }
                default {
                    tempData := mload(0x40)
                    mstore(tempData, 0)
                    mstore(0x40, add(tempData, 0x20))
                }
        }

        return tempData;
    }
}
