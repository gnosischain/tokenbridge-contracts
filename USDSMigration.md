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

In fork test, tx will revert because Hashi migration on xDAI bridge is not yet implemented on Ethereum. Please comment out `_emitUserRequestForAffirmationIncreaseNonceAndMaybeSendDataWithHashi(_receiver, _amount);` in `contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol`
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

1. `BridgeRouter.sol`: An entry point for token transferring, abstracting relayTokens() for Omnibridge and xDAI bridge. Upgradeable with TransparentUpgradeableProxy.
2. `XDaiBridgeperipheral.sol`: Peripheral contract to convert between DAI and USDS after bridge migration.

Transitional contracts during migration

1. `XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol`: Allow `relayTokens` with DAI.

2. `XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol`: Allow `relayTokens` with USDS.

## Modified contracts

1. `SavingsDaiConnector.sol`: `daiToken()` address is changed to USDS address, `sDaiToken()` address is changed to sUSDS address.
2. `XDaiForeignBridge.sol`: new `swapSDAIToUSDS` function for bridge migration.
