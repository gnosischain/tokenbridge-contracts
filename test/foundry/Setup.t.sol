// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import {IUSDS} from "./interfaces/IUSDS.sol";
import {ISavingsDai} from "./interfaces/ISavingsDai.sol";
import {IEternalStorageProxy} from "./interfaces/IEternalStorageProxy.sol";
import {IXDaiForeignBridge} from "./interfaces/IXDaiForeignBridge.sol";
import {IBridgeValidators} from "./interfaces/IBridgeValidators.sol";

contract SetupTest is Test {
    address public alice = makeAddr("alice");
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
        (validator, validatorPk) = makeAddrAndKey("mockValidator");
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
        newImpl = IXDaiForeignBridge(overrideAddress);

        uint256 size;
        address _a = address(newImpl);
        assembly {
            size := extcodesize(_a)
        }
        assertGt(size, 0);
        globalTime = block.timestamp;

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

    /// The following function calls during the upgrade on BridgeProxy need to be bundled with another two Router.setRoute calls in a bundled Safe transaction,
    /// that will be signed and executed by [bridge governors](https://docs.gnosischain.com/bridges/management/#bridge-governance)
    /// Check BridgeRouter.t.sol#upgradeBridgeAndSetupRoute() for the complete calls during the upgrade
    function upgradeAndInitializeInterest() public {
        uint256 initialVersion = bridgeProxy.version();
        uint256 minCashThresholdForUsds = bridge.minCashThreshold(address(DAI));
        uint256 minInterestPaidForUsds = bridge.minInterestPaid(address(DAI));

        vm.startPrank(proxyOwner);

        bridgeProxy.upgradeTo(initialVersion + 1, address(newImpl));
        assertEq(initialVersion + 1, bridgeProxy.version());
        assertEq(address(newImpl), bridgeProxy.implementation());
        console.log("upgraded bridge to version %s", initialVersion + 1);

        // disable interested for DAI and swap sDAI -> sUSDS
        bridge.swapSDAIToUSDS();
        bridge.initializeInterest(
            address(USDS), minCashThresholdForUsds, minInterestPaidForUsds, gnosisInterestReceiver
        );
        bridge.invest(address(USDS));
        assertEq(bridge.minCashThreshold(address(DAI)), 0, "minCashThreshodl fro DAI mismatch");
        assertEq(bridge.minInterestPaid(address(DAI)), 0, "minInterestPaid fro DAI mismatch");

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

    function hashMessage(bytes memory message, bool isAMBMessage) public pure returns (bytes32) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        if (isAMBMessage) {
            return keccak256(abi.encodePacked(prefix, uintToString(message.length), message));
        } else {
            string memory msgLength;
            if (message.length == 104) {
                msgLength = "104";
            } else if (message.length == 124) {
                msgLength = "124";
            }
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
        address _recipient,
        uint256 _amount,
        bytes32 _nonce,
        address _contractAddress,
        address _tokenAddress,
        uint256 signerPk,
        bool isForeign
    ) public returns (bytes memory message, bytes memory signatures) {
        if (_tokenAddress == address(0)) {
            message = abi.encodePacked(_recipient, _amount, _nonce, _contractAddress);
        } else {
            message = abi.encodePacked(_recipient, _amount, _nonce, _contractAddress, _tokenAddress);
        }

        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        string memory msgLength;
        if (message.length == 104) {
            msgLength = "104";
        } else if (message.length == 124) {
            msgLength = "124";
        }

        bytes32 hashedMessage = keccak256(abi.encodePacked(prefix, msgLength, message));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, hashedMessage);

        assertEq(ecrecover(hashedMessage, v, r, s), validator);
        if (isForeign) {
            signatures = abi.encodePacked(uint8(1), v, r, s);
        } else {
            signatures = abi.encodePacked(r, s, v);
        }
    }
}
