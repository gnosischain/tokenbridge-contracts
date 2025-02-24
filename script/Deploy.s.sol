// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

import {XDaiBridgePeripheral} from "../contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol";
import {BridgeRouter} from "../contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployScript is Script{

       function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Disclaimer: In production, bridgeOwner should not be an EOA,
        // as it exposes a front-run vulnerability.
        address bridgeOwner = vm.envAddress("BRIDGE_OWNER");
        address proxyAdminOwner = vm.envAddress("PROXY_ADMIN_OWNER");
        vm.startBroadcast(deployerPrivateKey);

        // Deployment for xDAIForeignBridge can only use forge create because of the incompatible Solidity version (0.4.24 for xDAIForeignBridge)
        // refer to deploy.sh

        BridgeRouter router = new BridgeRouter();
        TransparentUpgradeableProxy bridgeRouterProxy = new TransparentUpgradeableProxy(address(router), proxyAdminOwner,  abi.encodeWithSignature("initialize(address)",bridgeOwner));
        XDaiBridgePeripheral peripheral = new XDaiBridgePeripheral(address(bridgeRouterProxy));

        
        vm.stopBroadcast();
    }
}