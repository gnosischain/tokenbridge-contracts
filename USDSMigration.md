# USDS migration

## Dev

### Setup

```
nvm use
npm i
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
2. `XDaiBridgePeripheral.sol`: Peripheral contract to convert between DAI and USDS after bridge migration.

Transitional contracts during migration

1. `XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol`: Allow `relayTokens` with DAI.

2. `XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol`: Allow `relayTokens` with USDS.

## Modified contracts

1. `SavingsDaiConnector.sol`: `daiToken()` address is changed to USDS address, `sDaiToken()` address is changed to sUSDS address.
2. `XDaiForeignBridge.sol`: new function introduced
   1. `swapSDAIToUSDS`: one time function for bridge migration
   2. `executeSignaturesUSDS`: receive USDS instead of DAI

## Changes

1. After the migration, xDAI Foreign Bridge take USDS as collateral instead of DAI.
2. CCalling XDaiForeignBridge's executeSignatures and BridgeRouter's executeSignatures will always receive DAI
3. Calling XDaiForeignBridge's executeSignaturesUSDS and BridgeRouter's executeSignaturesUSDS will receive USDS post upgrade, while BridgeRouter's executeSignaturesUSDS will revert pre upgrade. XDaiForeignBridge's executeSignaturesUSDS

> User/Third party application should interact with BridgeRouter contract instead of xDAI bridge contract

# Interact with the contracts

Before migration (current):

1. `BridgeRouter.relayTokens(address token, address recipient, uint256 amount)`
   -> When token is DAI / USDS from Ethereum, receive xDAI on GC.  
   -> When token is other tokens from Ethereum, receive the bridged version token on GC.
2. `BridgeRouter.executeSignatures(bytes memory message, bytes memory signatures)`
   -> claim DAI on Ethereum
3. `BridgeRouter.executeSignaturesUSDS(bytes memory message, bytes memory signatures)`  
   -> revert `ClaimUsdsNotSupported()`
4. `BridgeRouter.safeExecuteSignaturesWithAutoGasLimit(bytes memory message, bytes memory signatures)`  
   -> claim token from Omnibridge
5. `xDAIForeignBridge.relayTokens(address recipient, uint256 amount)`  
   -> relay DAI from Ethereum, receive xDAI on GC
6. `xDAIForeignBridge.executeSignatures(bytes memory message, bytes memory signatures)`  
   -> claim DAI on Ethereum

After migration (current):

1. `BridgeRouter.relayTokens(address token, address recipient, uint256 amount)`
   -> When token is DAI / USDS from Ethereum, receive xDAI on GC.  
   -> When token is other tokens from Ethereum, receive the bridged version token on GC.
2. `BridgeRouter.executeSignatures(bytes memory message, bytes memory signatures)`
   -> claim DAI on Ethereum
3. `BridgeRouter.executeSignaturesUSDS(bytes memory message, bytes memory signatures)`  
   -> claim USDS on Ethereum
4. `BridgeRouter.safeExecuteSignaturesWithAutoGasLimit(bytes memory message, bytes memory signatures)`  
   -> claim token from Omnibridge
5. `xDAIForeignBridge.relayTokens(address recipient, uint256 amount)`  
   -> relay USDS from Ethereum, receive xDAI on GC
6. `xDAIForeignBridge.executeSignatures(bytes memory message, bytes memory signatures)`  
   -> claim DAI on Ethereum
7. `xDAIForeignBridge.executeSignaturesUSDS(bytes memory message, bytes memory signatures)`  
   -> claim USDS on Ethereum
