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
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY --verify --etherscan-api-key --broadcast
```

### Get deployed bytecode

`npm run get-deployed-bytecode`

The result will be written into `scripts/usds_migration/deployBytecode_usds_migration.json`.

Here are the list of keccak256 hashes of the bytecode of each contracts:

• xDaiForeignBridge: `0xb8b0173057aeedf9412bbe27dbd8983a403c3153e49a37d61cdf0ad6d63952d7`
• BridgeRouter: `0x96dcffff68bef488694f12c7aca620b60771c46c8ef460338f3486dde664ab01`
• XDaiBridgePeripheral: `0x26ef751bddddbd7addbd9dbe9365b8a23f0648fce0ef5b9c5f364a0799b5735f`
• XDaiBridgePeripheralForDaiPreUsdsUpgrade: `0x7bb382eb2b03e84e8d905c2e0eac7fac6985722d3a88793bb7ee083789dbf7f6`
• XDaiBridgePeripheralForUsdsPreUsdsUpgrade: `0x55cb479b9e81039f32231ce704cce153b0068036ea69df5115156086e8e4b32d`
• TransparentUpgradeableProxy: `0xb7ac622259b04bc6eb1bd4aed1cae089ba8927600bddc2c248f610c20df75624`

### Contract versions

**v0.8.25+commit.b61c2a91**
optimizer-runs = 100

- BridgeRouter.sol
- XDaiBridgePeripheral.sol
- XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol
- XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol

**v0.4.24+commit.e67f0147**
optimizer-runs = 100

- XDaiForeignBridge.sol

# Contracts

## New contracts

1. `BridgeRouter.sol`: An entry point for token transferring, abstracting relayTokens() for Omnibridge and xDAI bridge. Upgradeable with `TransparentUpgradeableProxy`.
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
2. Calling XDaiForeignBridge's `executeSignatures` and BridgeRouter's `executeSignatures` will **always receive DAI**.
3. Calling XDaiForeignBridge's `executeSignaturesUSDS` and BridgeRouter's `executeSignaturesUSDS` will **receive USDS** post upgrade, while BridgeRouter's executeSignaturesUSDS will **revert** pre upgrade.

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

# Function calls during the proxy upgrade

## Before the upgrade

Caller: BridgeRouterOwner `0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6` (same as the bridge owner)

```
router.setRoute(DAI,address(XDaiBridgePeripheralForDaiPreUsdsUpgrade));
router.setRoute(USDS,address(XDaiBridgePeripheralForUsdsPreUsdsUpgrade));
```

**Relay DAI**

1. DAI.approve(BridgeRouter, amount)
   -> [BridgeRouter.relayTokens(DAI, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L44)
   -> [XDaiBridgePeripheralForDaiPreUsdsUpgrade.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol#L36)
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim DAI**

1. [BridgeRouter.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L81)
   -> [xDAIForeignBridge.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/BasicForeignBridge.sol#L22)
   -> (internal) [onExecuteMessage](./contracts/upgradeable_contracts/erc20_to_native/XDaiForeignBridge.sol#L80-L91) |Here is where the DAI is transferred

**Relay USDS**

1. USDS.approve(BridgeRouter, amount)
   -> [BridgeRouter.relayTokens(USDS, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L47)
   -> [XDaiBridgePeripheralForUsdsPreUsdsUpgrade.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol#L36) |Here is where USDS is swap to DAI
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim USDS**

1. [BridgeRouter.executeSignaturesUSDS(message,signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L105-L109)
   -> revert `ClaimUsdsNotSupported()` `0x662554fc43b5d87090a5f9e8b365ca35213d23ae7082671886b760dc510ee8da`

XDaiForeignBridge's current implementation: https://etherscan.io/address/0x166124b75c798cedf1b43655e9b5284ebd5203db
Code: https://github.com/gnosischain/tokenbridge-contracts/tree/xdaibridge/contracts/upgradeable_contracts/erc20_to_native

## Upgrade

Test for the upgrade calls is written in [BridgeRouter.t.sol#upgradeBridgeAndSetupRoute](./test/foundry/BridgeRouter.t.sol#L533)

### Function calls during the proxy upgrade

> > The function calls during the upgrade on BridgeProxy and Router is a bundled Safe transaction, that will be signed and executed by [bridge governors](https://docs.gnosischain.com/bridges/management/#bridge-governance).

**Call on xDAI Foreign Bridge contract**

XDaiForeignBridgeProxy=`0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016`

Caller: Bridge Owner `0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6`

```solidity
   uint256 initialVersion = 8
   address newImpl = # TODO: deploy
   bridgeProxy.upgradeTo(initialVersion + 1, address(newImpl));

   // disable interested for DAI and swap sDAI -> sUSDS
   bridgeProxy.swapSDAIToUSDS();
   bridgeProxy.initializeInterest(
      address(USDS): 0xdC035D45d973E3EC169d2276DDab16f1e407384F,
      minCashThreshold: 1000000000000000000000000,
      minInterestPaid: 1000000000000000000000,
      gnosisInterestReceiver: 0x670daeaF0F1a5e336090504C68179670B5059088
   );
   bridgeProxy.invest(address(USDS));
```

**sUpdate routes on BridgeRouter**

Caller: BridgeRouterOwner `0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6` (same as the bridge owner)

ROUTER_ADDRESS= # TODO deploy
XDAI_BRIDGE_PERIPHERAL= # TODO deploy
XDAI_FOREIGNBRIDGE_PROXY=`0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016`

```solidity
router.setRoute(address(DAI), address(xDAIBridgeperipheral));
router.setRoute(address(USDS), xDAIForeignBridgeProxy);
```

## After the upgrade

**Relay DAI**

1. DAI.approve(BridgeRouter, amount)
   -> [BridgeRouter.relayTokens(DAI, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L44)
   -> [XDaiBridgePeripheral.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol#L35)
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim DAI**

1. [BridgeRouter.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L85)
   -> [xDAIForeignBridge.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/BasicForeignBridge.sol#L22)
   -> (internal)[onExecuteMessage](./contracts/upgradeable_contracts/erc20_to_native/XDaiForeignBridge.sol#L146-L156) |Here is where USDS is swap to DAI

**Relay USDS**

1. USDS.approve(bridgeRouter, amount)
   -> [BridgeRouter.relayTokens(USDS, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L47)
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim USDS**

1. [BridgeRouter.executeSignaturesUSDS(message, signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L111)
   -> [xDAIForeigbBridge.executeSignaturesUSDS(message,signatures)](./contracts/upgradeable_contracts/erc20_to_native/XDaiForeignBridge.sol#L113)
