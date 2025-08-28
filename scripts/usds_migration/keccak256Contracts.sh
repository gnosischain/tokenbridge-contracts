#!/usr/bin/env bash

# This script generate the keccak256 of the contracts into a json file
# XDaiForeignBridge 
# Bridge Router
# XDaiBridgePeripheral
# XDaiBridgePeripheralForDaiPreUsdsUpgrade
# XDaiBridgePeripheralForUsdsPreUsdsUpgrade
# HomeBridgeErcToNative



# Exit on error
set -e

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"


nvm use
npm cache clean --force
rm -rf node_modules
npm install

forge build


# Paths to keccak256 files
XDaiForeignBridge_json="out/XDaiForeignBridge.sol/XDaiForeignBridge.json"
BridgeRouter_json="out/BridgeRouter.sol/BridgeRouter.json"
XDaiBridgePeripheral_json="out/XDaiBridgePeripheral.sol/XDaiBridgePeripheral.json"
XDaiBridgePeripheralForDaiPreUsdsUpgrade_json="out/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol/XDaiBridgePeripheralForDaiPreUsdsUpgrade.json"
XDaiBridgePeripheralForUsdsPreUsdsUpgrade_json="out/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.json"
TransparentUpgradeableProxy_json="out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json"
HomeBridgeErcToNative_json="out/HomeBridgeErcToNative.sol/HomeBridgeErcToNative.json"

# Extract  keccak256
XDaiBridge_keccak256=$(jq -r '.metadata.sources["contracts/upgradeable_contracts/erc20_to_native/XDaiForeignBridge.sol"].keccak256' "$XDaiForeignBridge_json")
BridgeRouter_keccak256=$(jq -r '.metadata.sources["contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol"].keccak256' "$BridgeRouter_json")
XDaiBridgePeripheral_keccak256=$(jq -r '.metadata.sources["contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol"].keccak256' "$XDaiBridgePeripheral_json")
XDaiBridgePeripheralForDaiPreUsdsUpgrade_keccak256=$(jq -r '.metadata.sources["contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol"].keccak256' "$XDaiBridgePeripheralForDaiPreUsdsUpgrade_json")
XDaiBridgePeripheralForUsdsPreUsdsUpgrade_keccak256=$(jq -r '.metadata.sources["contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol"].keccak256' "$XDaiBridgePeripheralForUsdsPreUsdsUpgrade_json")
TransparentUpgradeableProxy_keccak256=$(jq -r '.metadata.sources["lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol"].keccak256' "$TransparentUpgradeableProxy_json")
HomeBridgeErcToNative_keccak256=$(jq -r '.metadata.sources["contracts/upgradeable_contracts/erc20_to_native/HomeErcToNative.sol"].keccak256' "$HomeBridgeErcToNative_json")

cat <<EOF > scripts/usds_migration/keccak256hash.json
{
  "xDaiForeignBridge keccak256": "$XDaiBridge_keccak256",
  "BridgeRouter keccak256": "$BridgeRouter_keccak256",
  "XDaiBridgePeripheral keccak256": "$XDaiBridgePeripheral_keccak256",
  "XDaiBridgePeripheralForDaiPreUsdsUpgrade keccak256": "$XDaiBridgePeripheralForDaiPreUsdsUpgrade_keccak256",
  "XDaiBridgePeripheralForUsdsPreUsdsUpgrade keccak256": "$XDaiBridgePeripheralForUsdsPreUsdsUpgrade_keccak256",
  "TransparentUpgradeableProxy keccak256": "$TransparentUpgradeableProxy_keccak256",
  "HomeBridgeErcToNative keccak256": "$HomeBridgeErcToNative_keccak256"
}
EOF

echo "Output written to  scripts/usds_migration/deploykeccak256_usds_migration.json"

