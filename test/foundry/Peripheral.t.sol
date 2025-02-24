pragma solidity ^0.8.0;

import { XDaiBridgePeripheral } from "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol";
import { SetupTest } from "./Setup.t.sol";
import "forge-std/console.sol";

contract PeripheralTest is SetupTest {
    XDaiBridgePeripheral peripheral;
    address router = makeAddr("router");

    function setUp() public payable override {
        super.setUp();
        peripheral = new XDaiBridgePeripheral(router);

    }

    function testFailIfNotFromRouter() public {
        uint256 amount = 10e25;
        vm.startPrank(alice);
        vm.expectRevert("revert: only Router");
        peripheral.relayTokens(makeAddr("token"), amount);

        vm.expectRevert("revert: only Router");
        peripheral.executeSignaturesAndSwapToDai("0x", "0x", "0x", block.timestamp);

        vm.stopPrank();
    }
}
