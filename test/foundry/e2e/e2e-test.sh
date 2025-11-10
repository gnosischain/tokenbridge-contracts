#!/usr/bin/env bash

# ========================= ETH -> GC ===========================
echo "🚀 ETH bridge relayTokens -> GC bridge executeAffirmation"
forge test  --match-test testRelayUSDSToBridge --fork-url $RPC_MAINNET 
forge test  --match-test testExecuteAffirmation --fork-url $RPC_GNOSIS 
echo "Complete ✅"

echo "🚀 ETH router relayTokens(DAI) -> GC bridge executeAffirmation"
forge test  --match-test testRelayDAIToRouter --fork-url $RPC_MAINNET 
forge test  --match-test testExecuteAffirmation --fork-url $RPC_GNOSIS
echo "Complete ✅"

echo "🚀 ETH router relayTokens(USDS) -> GC bridge executeAffirmation"
forge test  --match-test testRelayUSDSToRouter --fork-url $RPC_MAINNET 
forge test  --match-test testExecuteAffirmation --fork-url $RPC_GNOSIS
echo "Complete ✅"



# ========================= GC -> ETH ===========================
echo "🚀 GC Transfer xDAI to bridge -> ETH claim DAI"
forge test  --match-test testTransferToBridge --no-match-test testTransferToBridgeWithOldXDaiMsg --fork-url $RPC_GNOSIS
forge test  --match-test testExecuteSignaturesAndClaimDai --no-match-test testExecuteSignaturesAndClaimDaiWithOldMsg --fork-url $RPC_MAINNET
echo "Complete ✅"

echo "🚀 GC relayTokens with xDAI to bridge -> ETH claim DAI"
forge test  --match-test testRelayTokensToBridge --no-match-test testRelayTokensToBridgeWithOldXDaiMsg --fork-url $RPC_GNOSIS 
forge test  --match-test testExecuteSignaturesAndClaimDai --no-match-test testExecuteSignaturesAndClaimDaiWithOldMsg --fork-url $RPC_MAINNET
echo "Complete ✅"

echo "🚀 GC relayTokens with xDAI old msg to bridge -> ETH claim DAI"
forge test  --match-test testTransferToBridgeWithOldXDaiMsg --fork-url $RPC_GNOSIS 
forge test  --match-test testExecuteSignaturesAndClaimDaiWithOldMsg --fork-url $RPC_MAINNET
echo "Complete ✅"


echo "🚀 GC transfer xDAI to Deposit contract -> ETH claim USDS"
forge test  --match-test testTransferToDepositContract --fork-url $RPC_GNOSIS
forge test  --match-test testExecuteSignaturesAndClaimUSDS --fork-url $RPC_MAINNET
echo "Complete ✅"
# Deposit.relayTokens -> Bridge.submitSignatures -> ForeignBridge.executeSignatures

echo "🚀 GC relayTokens with xDAI to Deposit contract -> ETH claim USDS"
forge test  --match-test testRelayTokensToDepositContract --fork-url $RPC_GNOSIS
forge test  --match-test testExecuteSignaturesAndClaimUSDS --fork-url $RPC_MAINNET
echo "Complete ✅"



