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
2. `XDaiForeignBridge.sol`: new function introduced
   1. `swapSDAIToUSDS`: one time function for bridge migration
   2. `executeSignaturesUSDS`: receive USDS instead of DAI
   3. `daiUsds`: view function to read the daiUsds contract address
   4. `setDaiUsds`: set new daiUsds contract address, only callable by owner

# Changes

1. After the migration, xDAI Foreign Bridge take USDS as collateral instead of DAI.
2. Calling XDaiForeignBridge's executeSignatures and BridgeRouter's executeSignatures will always receive DAI
3. alling XDaiForeignBridge's executeSignaturesUSDS and BridgeRouter's executeSignaturesUSDS will receive USDS post upgrade, while BridgeRouter's executeSignaturesUSDS will revert pre upgrade.

> User/Third party application should interact with BridgeRouter contract instead of xDAI bridge contract
