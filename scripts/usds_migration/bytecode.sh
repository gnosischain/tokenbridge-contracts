#!/usr/bin/env bash

# This script generate the bytecode of the contracts into a json file
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
# npm cache clean --force
rm -rf node_modules
npm install

forge install
forge build


# Paths to bytecode files
XDaiForeignBridge_json="out/XDaiForeignBridge.sol/XDaiForeignBridge.json"
BridgeRouter_json="out/BridgeRouter.sol/BridgeRouter.json"
XDaiBridgePeripheral_json="out/XDaiBridgePeripheral.sol/XDaiBridgePeripheral.json"
XDaiBridgePeripheralForDaiPreUsdsUpgrade_json="out/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol/XDaiBridgePeripheralForDaiPreUsdsUpgrade.json"
XDaiBridgePeripheralForUsdsPreUsdsUpgrade_json="out/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.json"
TransparentUpgradeableProxy_json="out/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json"
HomeBridgeErcToNative_json="out/HomeBridgeErcToNative.sol/HomeBridgeErcToNative.json"

# Extract deployed bytecode
XDaiBridge_bytecode=$(jq -r '.deployedBytecode.object' "$XDaiForeignBridge_json")
BridgeRouter_bytecode=$(jq -r '.deployedBytecode.object' "$BridgeRouter_json")
XDaiBridgePeripheral_bytecode=$(jq -r '.deployedBytecode.object' "$XDaiBridgePeripheral_json")
XDaiBridgePeripheralForDaiPreUsdsUpgrade_bytecode=$(jq -r '.deployedBytecode.object' "$XDaiBridgePeripheralForDaiPreUsdsUpgrade_json")
XDaiBridgePeripheralForUsdsPreUsdsUpgrade_bytecode=$(jq -r '.deployedBytecode.object' "$XDaiBridgePeripheralForUsdsPreUsdsUpgrade_json")
TransparentUpgradeableProxy_bytecode=$(jq -r '.deployedBytecode.object' "$TransparentUpgradeableProxy_json")
HomeBridgeErcToNative_bytecode=$(jq -r '.deployedBytecode.object' "$HomeBridgeErcToNative_json")

cat <<EOF > scripts/usds_migration/deployBytecode_usds_migration.json
{
  "xDaiForeignBridge deployedBytecode": "$XDaiBridge_bytecode",
  "BridgeRouter deployedBytecode": "$BridgeRouter_bytecode",
  "XDaiBridgePeripheral deployedBytecode": "$XDaiBridgePeripheral_bytecode",
  "XDaiBridgePeripheralForDaiPreUsdsUpgrade deployedBytecode": "$XDaiBridgePeripheralForDaiPreUsdsUpgrade_bytecode",
  "XDaiBridgePeripheralForUsdsPreUsdsUpgrade deployedBytecode": "$XDaiBridgePeripheralForUsdsPreUsdsUpgrade_bytecode"
  "TransparentUpgradeableProxy deployedBytecode": "$TransparentUpgradeableProxy_bytecode",
  "HomeErcToNative deployedBytecode": "$HomeBridgeErcToNative_bytecode"
}
EOF

echo "Output written to  scripts/usds_migration/deployBytecode_usds_migration.json"

