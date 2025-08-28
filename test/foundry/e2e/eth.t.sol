// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {SetupTest} from "../Setup.t.sol";
import {BridgeRouter} from "../../../contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol";
import {XDaiBridgePeripheral} from "../../../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol";

///@dev Don't run this this individually, please run ./test/foundry/e2e/e2e-test.sh
contract ETHForkTest is SetupTest {
    event RelayedMessage(address recipient, uint256 value, bytes32 transactionHash);

    struct MessageFromGC {
        uint256 amount;
        bytes message;
        bytes32 nonce;
        bytes32 r;
        address recipient;
        bytes32 s;
        address token;
        uint8 v;
    }

    BridgeRouter bridgeRouter = BridgeRouter(0x9a873656c19Efecbfb4f9FAb5B7acdeAb466a0B0);
    address FOREIGN_XDAIBRIDGE = 0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016;

    function setUp() public payable override {
        super.setUp();
        upgradeAndInitializeInterest();
        vm.startPrank(validatorContractOwner);
        validatorContract.addValidator(makeAddr("mockValidator"));
        validatorContract.setRequiredSignatures(1);
        vm.stopPrank();
    }

    function testRelayDAIToRouter() public {
        setupBridgeRouter();

        uint256 amount = bridge.minPerTx() + 1;
        vm.assume(bridge.withinLimit(amount) == true);
        deal(address(DAI), alice, amount);

        uint256 initialAliceDAIBalance = DAI.balanceOf(alice);
        bytes32 nonce = bytes32(bridge.nonce());
        vm.startPrank(alice);

        DAI.approve(address(bridgeRouter), amount);
        bridgeRouter.relayTokens(address(DAI), bob, amount);

        vm.stopPrank();

        assertEq(DAI.balanceOf(alice), initialAliceDAIBalance - amount);
        writeToFile(bob, nonce, amount);
    }

    function testRelayUSDSToRouter() public {
        setupBridgeRouter();

        uint256 amount = bridge.minPerTx() + 1;
        vm.assume(bridge.withinLimit(amount) == true);
        deal(address(USDS), alice, amount);

        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        bytes32 nonce = bytes32(bridge.nonce());
        vm.startPrank(alice);

        USDS.approve(address(bridgeRouter), amount);
        bridgeRouter.relayTokens(address(USDS), bob, amount);

        vm.stopPrank();

        assertEq(DAI.balanceOf(alice), initialAliceUSDSBalance - amount);
        writeToFile(bob, nonce, amount);
    }

    function testRelayUSDSToBridge() public {
        uint256 amount = bridge.minPerTx() + 1;
        vm.assume(bridge.withinLimit(amount) == true);
        deal(address(USDS), alice, amount);

        uint256 initialAliceUSDSBalance = USDS.balanceOf(alice);
        bytes32 nonce = bytes32(bridge.nonce());
        vm.startPrank(alice);

        USDS.approve(address(bridge), amount);
        bridge.relayTokens(bob, amount);

        vm.stopPrank();

        assertEq(USDS.balanceOf(alice), initialAliceUSDSBalance - amount);
        writeToFile(bob, nonce, amount);
    }

    function testExecuteSignaturesAndClaimUSDS() public {
        bytes memory data = readFromFile();
        MessageFromGC memory message = abi.decode(data, (MessageFromGC));
        bytes memory signatures = abi.encodePacked(uint8(1), message.v, message.r, message.s);

        uint256 initialBalance = USDS.balanceOf(message.recipient);
        vm.prank(alice);
        vm.expectEmit(bridgeAddress);
        emit RelayedMessage(message.recipient, message.amount, message.nonce);
        bridge.executeSignatures(message.message, signatures);
        assertEq(USDS.balanceOf(message.recipient), initialBalance + message.amount);
    }

    function testExecuteSignaturesAndClaimDai() public {
        bytes memory data = readFromFile();
        MessageFromGC memory message = abi.decode(data, (MessageFromGC));
        bytes memory signatures = abi.encodePacked(uint8(1), message.v, message.r, message.s);

        require(message.token == address(DAI), "Token mismatch");
        uint256 initialBalance = DAI.balanceOf(message.recipient);
        vm.prank(alice);
        vm.expectEmit(bridgeAddress);
        emit RelayedMessage(message.recipient, message.amount, message.nonce);
        bridge.executeSignatures(message.message, signatures);
        assertEq(DAI.balanceOf(message.recipient), initialBalance + message.amount);
    }

    function testExecuteSignaturesAndClaimDaiWithOldMsg() public {
        bytes memory data = readFromFile();
        MessageFromGC memory message = abi.decode(data, (MessageFromGC));
        bytes memory signatures = abi.encodePacked(uint8(1), message.v, message.r, message.s);

        uint256 initialBalance = DAI.balanceOf(message.recipient);
        vm.prank(alice);
        vm.expectEmit(bridgeAddress);
        emit RelayedMessage(message.recipient, message.amount, message.nonce);
        bridge.executeSignatures(message.message, signatures);
        assertEq(DAI.balanceOf(message.recipient), initialBalance + message.amount);
    }

    function writeToFile(address _recipient, bytes32 _nonce, uint256 _amount) public {
        string memory test1 = "transactionDetails";
        vm.serializeAddress(test1, "recipeint", _recipient);
        vm.serializeUint(test1, "amount", _amount);
        string memory finalJson = vm.serializeBytes32(test1, "nonce", _nonce);
        vm.writeJson(finalJson, "./test/foundry/e2e/validator.json");
    }

    function readFromFile() public view returns (bytes memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/foundry/e2e/validator.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        return data;
    }

    function setupBridgeRouter() public {
        XDaiBridgePeripheral peripheral = new XDaiBridgePeripheral(address(bridgeRouter));
        vm.startPrank(bridgeOwner);
        bridgeRouter.setRoute(address(DAI), address(peripheral));
        bridgeRouter.setRoute(address(USDS), FOREIGN_XDAIBRIDGE);
        vm.stopPrank();
    }
}
