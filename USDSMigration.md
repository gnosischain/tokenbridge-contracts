# USDS migration

## Dev

### Setup

```
forge install
forge build
```

### Test

```
source .env
forge test --fork-url $RPC_MAINNET
```

or

```
./test/foundry/forkTest.sh
```

### Deploy

```
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY --broadcast
```

# Contracts

## New contracts

1. `BridgeRouter.sol`: An entry point for token transferring, abstracting relayTokens() for Omnibridge and xDAI bridge.
2. `XDaiBridgeperipheral.sol`: Peripheral contract to convert between DAI and USDS after bridge migration.

## Modified contracts

1. `SavingsDaiConnector.sol`: `daiToken()` address is changed to USDS address, `sDaiToken()` address is changed to sUSDS address.
2. `XDaiForeignBridge.sol`: new `swapSDAIToUSDS` function for bridge migration.
