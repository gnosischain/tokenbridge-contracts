// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import { IUSDS } from "./interfaces/IUSDS.sol";
import { ISavingsDai } from "./interfaces/ISavingsDai.sol";
import { IEternalStorageProxy } from "./interfaces/IEternalStorageProxy.sol";
import { IXDaiForeignBridge } from "./interfaces/IXDaiForeignBridge.sol";
import { IBridgeValidators } from "./interfaces/IBridgeValidators.sol";

contract SetupTest is Test {
    address public initializer = 0x1B572dBCBBDA53e2A900D00d39c67292288E97c8;

    address public alice;
    uint256 alicePk;
    address public bob = makeAddr("bob");
    address validator;
    uint256 validatorPk;

    IBridgeValidators validatorContract = IBridgeValidators(0xe1579dEbdD2DF16Ebdb9db8694391fa74EeA201E);
    address public proxyOwner = 0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6;
    address public bridgeOwner = 0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6;
    address public validatorContractOwner = 0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6;
    address public gnosisInterestReceiver = address(27);

    ISavingsDai public sUSDS = ISavingsDai(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
    IUSDS public USDS = IUSDS(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    ISavingsDai sDAI = ISavingsDai(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 GNO = IERC20(0x6810e776880C02933D47DB1b9fc05908e5386b96);
    address public bridgeAddress = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    IEternalStorageProxy public bridgeProxy;
    IXDaiForeignBridge public bridge;
    IXDaiForeignBridge public newImpl;
    IXDaiForeignBridge public initialImpl;
    uint256 public globalTime;

    function setUp() public payable virtual {
        (validator, validatorPk) = makeAddrAndKey("newValidator");
        (alice, alicePk) = makeAddrAndKey("alice");

        console.log("chainId %s", block.chainid);
        console.log("block %s", block.number);

        bridgeProxy = IEternalStorageProxy(bridgeAddress);
        bridge = IXDaiForeignBridge(bridgeAddress);
        initialImpl = IXDaiForeignBridge(bridgeProxy.implementation());

        // deploy new Implementation
        // new XDaiForeignBridge() method is not used, because of the incompatible Solidity version with the test contract
        bytes memory newImplCode = vm.getDeployedCode("XDaiForeignBridge.sol:0.4.24");

        // set the impl code to an arbitrary address
        address overrideAddress = makeAddr("newXDaibridgeImpl");
        vm.etch(overrideAddress, newImplCode);
        assertEq(overrideAddress.code, newImplCode);
        newImpl = IXDaiForeignBridge(makeAddr("newXDaibridgeImpl"));

        uint256 size;
        address _a = address(newImpl);
        assembly {
            size := extcodesize(_a)
        }
        assertGt(size, 0);
        globalTime = block.timestamp;

        vm.deal(initializer, 100 ether);
        vm.deal(bridgeOwner, 100 ether);
        vm.deal(proxyOwner, 100 ether);
        vm.deal(alice, 10000 ether);
        vm.deal(bob, 100000 ether);

    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function testInitialize() public {
        bool implInitialized = initialImpl.isInitialized();
        assertFalse(implInitialized);
        implInitialized = newImpl.isInitialized();
        assertFalse(implInitialized);
        implInitialized = bridge.isInitialized();
        assertTrue(implInitialized);
    }

    function upgradeAndInitializeInterest() public {
        uint256 initialVersion = bridgeProxy.version();

        vm.startPrank(proxyOwner);

        bridgeProxy.upgradeTo(initialVersion + 1, address(newImpl));
        assertEq(initialVersion + 1, bridgeProxy.version());
        assertEq(address(newImpl), bridgeProxy.implementation());
        console.log("upgraded bridge to version %s", initialVersion + 1);

        // disable interested for DAIA and swap sUSDS -> sUSDS
        bridge.swapSDAIToUSDS();
        bridge.initializeInterest(
            address(USDS),
            bridge.minCashThreshold(address(DAI)),
            bridge.minInterestPaid(address(DAI)),
            gnosisInterestReceiver
        );
        bridge.invest(address(USDS));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        UTILS
    //////////////////////////////////////////////////////////////*/

    function teleport(uint256 _timestamp) public {
        globalTime = _timestamp;
        vm.warp(globalTime);
    }

    function skipTime(uint256 secs) public {
        globalTime += secs;
        vm.warp(globalTime);
    }

    function addMockValidator() public {
        vm.startPrank(validatorContractOwner);
        validatorContract.addValidator(address(validator));
        validatorContract.setRequiredSignatures(1);
        vm.stopPrank();
    }

    // encode message for xDAI bridge
    function encodeXdaiBridgeMessage(address recipient, uint256 amount, bytes32 nonce, address contractAddress)
        public
        pure
        returns (bytes memory)
    {
        bytes memory message = new bytes(104);

        assembly {
            mstore(add(message, 20), recipient) // Store recipient at offset 20
            mstore(add(message, 52), amount) // Store amount at offset 52
            mstore(add(message, 84), nonce) // Store nonce at offset 84
            mstore(add(message, 104), contractAddress) // Store contractAddress at offset 104
        }

        return message;
    }

    function hashMessage(bytes memory message, bool isAMBMessage) public pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        if (isAMBMessage) {
            return keccak256(abi.encodePacked(prefix, uintToString(message.length), message));
        } else {
            string memory msgLength = "104";
            return keccak256(abi.encodePacked(prefix, msgLength, message));
        }
    }

    function uintToString(uint256 i) public pure returns (string memory) {
        if (i == 0) return "0";
        uint256 j = i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length - 1;
        while (i != 0) {
            bstr[k--] = bytes1(uint8(48 + (i % 10)));
            i /= 10;
        }
        return string(bstr);
    }

    function getMessageAndSignatures(
        address receiver,
        uint256 amount,
        bytes32 nonce,
        address contractAddress,
        uint256 signerPk
    ) public pure returns (bytes memory message, bytes memory signatures) {
        message = abi.encodePacked(receiver, amount, nonce, contractAddress);
        // hashMessage(message, isAMBMessage)
        bytes32 hashedMessage = hashMessage(message, false);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, hashedMessage);
        signatures = abi.encodePacked(uint8(1), v, r, s);
    }

}
