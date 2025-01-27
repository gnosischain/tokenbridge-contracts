// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/interfaces/IERC20.sol";
import "./interfaces/ISavingsDai.sol";
import "./interfaces/IEternalStorageProxy.sol";
import "./interfaces/IXDaiForeignBridge.sol";

contract SetupTest is Test {
    address public initializer = 0x1B572dBCBBDA53e2A900D00d39c67292288E97c8;
    address public alice = address(12);
    address public bob = address(13);
    address public proxyOwner = 0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6;
    address public bridgeOwner = 0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6;
    address public gnosisInterestReceiver = address(27);

    ISavingsDai public sDAI;
    IERC20 public dai;
    address public bridgeAddress = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;
    IEternalStorageProxy public bridgeProxy;
    IXDaiForeignBridge public bridge;
    IXDaiForeignBridge public newImpl;
    IXDaiForeignBridge public initialImpl;
    uint256 public globalTime;

    function setUp() public payable {
        console.log("chainId %s", block.chainid);
        console.log("block %s", block.number);

        sDAI = ISavingsDai(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        bridgeProxy = IEternalStorageProxy(bridgeAddress);
        bridge = IXDaiForeignBridge(bridgeAddress);
        initialImpl = IXDaiForeignBridge(bridgeProxy.implementation());
        newImpl = IXDaiForeignBridge(vm.envAddress("NEW_IMPLEMENTATION"));

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

        deal(address(dai), alice, 100e18);
        assertEq(dai.balanceOf(alice), 100e18);

        deal(address(dai), bob, 10000e18);
        assertEq(dai.balanceOf(bob), 10000e18);

        /*//////////////////////////////////////////////////////////////
                                DEPLOYMENTS
        //////////////////////////////////////////////////////////////*/
        uint256 initialInvested = bridge.investedAmount(address(dai));
        console.log("initially invested amount: %e, %s", initialInvested, block.timestamp);
        upgrade();
        uint256 afterInvested = bridge.investedAmount(address(dai));
        console.log("after invested amount: %e, %s", afterInvested, block.timestamp);

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

    /*//////////////////////////////////////////////////////////////
                        UPGRADING PROXIES
    //////////////////////////////////////////////////////////////*/

    function upgrade() public {
        if (address(newImpl) != bridgeProxy.implementation()) {
            vm.startPrank(proxyOwner);

            uint256 initialVersion = bridgeProxy.version();

            bridgeProxy.upgradeTo(initialVersion + 1, address(newImpl));

            assertEq(initialVersion + 1, bridgeProxy.version());
            assertEq(address(newImpl), bridgeProxy.implementation());
            console.log("upgraded bridge to version %s", initialVersion + 1);
            vm.stopPrank();
            vm.startPrank(bridgeOwner);
            bridge.initializeInterest(address(dai), 1000000 ether, 1000 ether, gnosisInterestReceiver);
            bridge.investDai();
            skipTime(1 days);
            vm.stopPrank();
        }
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
}
