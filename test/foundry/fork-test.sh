#!/usr/bin/env bash

echo "Running fork test on Ethereum"
forge test --match-contract BridgeRouterTest --fork-url $RPC_MAINNET
echo "✅ BridgeRouterTest completed"
forge test --match-contract USDSXDaiForeignBridgeTest  --fork-url $RPC_MAINNET
echo "✅ USDSXDaiForeignBridgeTest completed"
forge test --match-contract PeripheralTest --fork-url $RPC_MAINNET
echo "✅ PeripheralTest completed"

echo "Running fork test on Gnosis Chain"
forge test --match-contract HomeBridgeErcToNativeTest --fork-url $RPC_GNOSIS
echo "✅ HomeBridgeErcToNativeTest completed"