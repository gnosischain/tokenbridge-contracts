#!/usr/bin/env bash
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/-nS9M81JxS_vHfz1wlWLIuSo0O6W_HMC
RPC_GNOSIS=https://ancient-virulent-crater.xdai.quiknode.pro/31c54ce2d49aba7562061ea5dae0479ae512b677/

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