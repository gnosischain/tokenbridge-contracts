pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {SetupTest} from "./Setup.t.sol";
import {XDaiBridgePeripheral} from "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol";
import {XDaiBridgePeripheralForDaiPreUsdsUpgrade} from
    "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol";
import {XDaiBridgePeripheralForUsdsPreUsdsUpgrade} from
    "../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol";

contract PeripheralTest is SetupTest {
    XDaiBridgePeripheral peripheral;
    XDaiBridgePeripheralForDaiPreUsdsUpgrade peripheralForDaiPreUsdsUpgrade;
    XDaiBridgePeripheralForUsdsPreUsdsUpgrade peripheralForUsdsPreUsdsUpgrade;
    address router = makeAddr("router");

    function setUp() public payable override {
        super.setUp();
        peripheral = new XDaiBridgePeripheral(address(router));
        peripheralForDaiPreUsdsUpgrade = new XDaiBridgePeripheralForDaiPreUsdsUpgrade(address(router));
        peripheralForUsdsPreUsdsUpgrade = new XDaiBridgePeripheralForUsdsPreUsdsUpgrade(address(router));
    }

    function testFailIfNotFromRouter() public {
        uint256 amount = 10e25;
        vm.startPrank(alice);
        vm.expectRevert("revert: only Router");
        peripheral.relayTokens(makeAddr("token"), amount);

        vm.expectRevert("revert: only Router");
        peripheralForDaiPreUsdsUpgrade.relayTokens(makeAddr("token"), amount);

        vm.expectRevert("revert: only Router");
        peripheralForUsdsPreUsdsUpgrade.relayTokens(makeAddr("token"), amount);

        vm.stopPrank();
    }
}
