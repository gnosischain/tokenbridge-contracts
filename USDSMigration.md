# USDS migration

> > After the migration, xDAI Foreign Bridge take USDS as collateral instead of DAI.  
> > Background: https://forum.gnosis.io/t/gip-118-should-sdai-be-replaced-by-susds-in-the-bridge/9354

## Table of Contents

- [General Overview](#general-overview)
- [Dev](#dev)
- [Contracts overview](#contracts)
- [Interact with contracts](#interact-with-the-contracts)
- [Call to Action: Update your code](#call-to-action-update-your-code)

## General overview

1.  The **xDAI bridge contract** is undergoing a critical upgrade: **DAI will be replaced with USDS as the default accepted token on Ethereum, while xDAI will continue to be minted on Gnosis Chain**.

### Key Changes for Third-Party Applications:

- Third-party applications **must integrate** with the new **Bridge Router contract** after it has been deployed on Ethereum, with timeline for **1 month**.
- The **Bridge Router** serves as the entry point for token relay transactions, routing them to the appropriate bridge contract on Gnosis Chain (**xDAI Bridge** or **Omnibridge**).
- **DAI & USDS transactions must go through the Bridge Router.** Transactions sent directly to the xDAI Bridge on Ethereum will **fail** if they attempt to relay DAI after the upgrade.
- **For tokens other than DAI & USDS**, using the Bridge Router is **optional**—third-party applications can continue interacting with Omnibridge directly.

### Transition Period:

- Before the USDS upgrade on the xDAI Bridge, third-party applications have time to **adapt to the Bridge Router interface**.
- By **specifying the token address** when relaying tokens through the Bridge Router, the system will **swap them accordingly** to the currently accepted token on the xDAI Bridge.

More info on the GIP: https://forum.gnosis.io/t/gip-118-should-sdai-be-replaced-by-susds-in-the-bridge/9354

## Dev

### Prerequisite

- [Node v10.18](https://nodejs.org/en/blog/release/v10.18.0) (as specified in .[nvm](https://github.com/nvm-sh/nvm)rc)
- [Foundry v0.2.0 or later](https://book.getfoundry.sh/getting-started/installation)
- Ethereum, Gnosis Chain RPC endpoint (for testing and deployment)

### Framework

[Foundry](https://book.getfoundry.sh/)

> > This repository was initially developed using [Truffle](https://archive.trufflesuite.com/docs/truffle/). However, due to the [sunsetting of Truffle](https://consensys.io/blog/consensys-announces-the-sunset-of-truffle-and-ganache-and-new-hardhat?utm_source=chatgpt.com), we transition our development workflow to Foundry.

### Setup

```sh
nvm use
npm i
forge install
forge build
```

### Test

```sh
source .env
forge test --fork-url $RPC_MAINNET
```

```sh
./test/foundry/forkTest.sh
```

### Deploy

```sh
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY --verify --etherscan-api-key --broadcast
```

### Get deployed bytecode of the contract

```sh
npm run get-deployed-bytecode
```

The result will be written into `scripts/usds_migration/deployBytecode_usds_migration.json`.

### Get keccak256 hash of the contract

```sh
npm run get-contract-keccak256
```

The result will be written into `scripts/usds_migration/keccak256hash.json`.

| Contract                                  | Contract Hash (keccak256)                                            |
| ----------------------------------------- | -------------------------------------------------------------------- |
| xDaiForeignBridge                         | `0x6e7ca817c9686c0ee3dbcd99e9d498d704fd3aae47c1fab98a6f81adaabff95b` |
| BridgeRouter                              | `0xc4f7cdc0ec90c22bca996d328c7dc11e20ef11f017eedb8df3d9b6e035f560b4` |
| XDaiBridgePeripheral                      | `0x3d5e7ff9da196691d2dc57c93036c7414b68d63921dce530c5747017ea39afb5` |
| XDaiBridgePeripheralForDaiPreUsdsUpgrade  | `0x721cfb942f77f4b04de65a4dbb7b1686e2c363689c83de3bee58da3ab9ae0bb3` |
| XDaiBridgePeripheralForUsdsPreUsdsUpgrade | `0x74284da7c9b250a0348d431981364bf4e82987ca93524f2c392ea2455fd1e8a9` |

For details about the keccak256 of the contract, please check [Sourcify's doc](https://docs.sourcify.dev/docs/full-vs-partial-match/#full-perfect-matches) and [Solidity's doc](https://docs.soliditylang.org/en/latest/metadata.html)

### Contract versions

| Contract                                      | Version                 | Optimizer Runs |
| --------------------------------------------- | ----------------------- | -------------- |
| BridgeRouter.sol                              | v0.8.25+commit.b61c2a91 | 10             |
| XDaiBridgePeripheral.sol                      | v0.8.25+commit.b61c2a91 | 10             |
| XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol  | v0.8.25+commit.b61c2a91 | 10             |
| XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol | v0.8.25+commit.b61c2a91 | 10             |
| XDaiForeignBridge.sol                         | v0.4.24+commit.e67f0147 | 10             |

# Contracts Overview

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

1. After the migration, xDAI Foreign Bridge takes USDS as collateral instead of DAI.
2. Calling XDaiForeignBridge's `executeSignatures` and BridgeRouter's `executeSignatures` will **always receive DAI**.
3. Calling XDaiForeignBridge's `executeSignaturesUSDS` and BridgeRouter's `executeSignaturesUSDS` will **receive USDS** post upgrade, while BridgeRouter's executeSignaturesUSDS will **revert** pre upgrade.

> User/Third party application **SHOULD** interact with BridgeRouter contract instead of xDAI bridge contract

### Contract addresses

| Contract                                   | Chain    | Address                                      |
| ------------------------------------------ | -------- | -------------------------------------------- |
| BridgeRouter Proxy                         | Ethereum | `0x9a873656c19Efecbfb4f9FAb5B7acdeAb466a0B0` |
| BridgeRouter Implementation                | Ethereum | `0x691c025Efa7ea1c87DF256F2Da9208E5345D40b1` |
| XDaiBridgePeripheral                       | Ethereum | `0x3b6669727927b934753B018EB421a84Ed4eb0a43` |
| XDaiBridgePeripheralForDaiPreUsdsUpgrade   | Ethereum | `0xF676cc15Eb6d15b794aeC65bC20052aFB53D9052` |
| XDaiBridgePeripheralForUsdsPreUsdsUpgrade  | Ethereum | `0x7df0e6a8BA609A6cC3Ab2fA33D953a3B5584f10C` |
| XDaiForeignBridge(Implementation Contract) | Ethereum | `0x3AbD91b5564BaF7966DcA7a30Bd50EAcc9aBeD77` |

# Interacting with the contracts

## Before the xDAI Bridge migration

**Bridge Router setup**  
Caller: BridgeRouterOwner `0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6` (same as the bridge owner)

```
router.setRoute(DAI,address(XDaiBridgePeripheralForDaiPreUsdsUpgrade));
router.setRoute(USDS,address(XDaiBridgePeripheralForUsdsPreUsdsUpgrade));
```

### Relay tokens

```mermaid
graph TD
    User([User]) -->|"relayTokens: DAI"| BridgeRouter
    User -->|"relayTokens: USDS"| BridgeRouter
    User -->|"relayTokens: Other ERC20"| BridgeRouter
    User -->|"relayTokens: ETH"| BridgeRouter

    subgraph "BridgeRouter Contract"
        BridgeRouter[BridgeRouter]
    end

    subgraph "Pre-Upgrade Peripherals"
        DaiPeripheral[XDaiBridgePeripheralForDaiPreUsdsUpgrade]
        UsdsPeripheral[XDaiBridgePeripheralForUsdsPreUsdsUpgrade]
    end

    BridgeRouter -->|DAI| DaiPeripheral
    BridgeRouter -->|USDS| UsdsPeripheral
    BridgeRouter -->|Other ERC20| OmniBridge[Foreign OmniBridge]
    BridgeRouter -->|ETH| WETHRouter[WETH OmniBridge Router]

    DaiPeripheral --> XDaiForeignBridge
    UsdsPeripheral -->|"Convert USDS to DAI"| XDaiForeignBridge

    subgraph "Omnibridge contract"
        OmniBridge --> OmniBridgeHome[Mint bridged token on Gnosis Chain]
        WETHRouter --> OmniBridgeHome
    end
    subgraph "XDaiForeignBridge Contract (Pre-Upgrade)"
        XDaiForeignBridge[XDaiForeignBridge] -->|"DAI as collateral"| GnosisChain[Mint xDAI on Gnosis Chain]
    end
```

### To claim token

```mermaid
graph TD


    subgraph "BridgeRouter Contract"
        BridgeRouter[BridgeRouter]
    end


    subgraph "XDaiForeignBridge Contact"
        XDaiForeignBridge[XDaiForeignBridge] -->|DAI as collateral| GnosisChain[unlock DAI to recipient]
    end

    subgraph "ForeignAMB Contract"
        ForeignAMB[ForeignAMB] --> Action[Unlock token to recipient]
    end

    %% For claim operations (pre-upgrade)
    User -->|executeSignatures| BridgeRouter
    User -.->|revert executeSignaturesUSDS| BridgeRouter
    User -->|safeExecuteSignaturesWithAutoGasLimit| BridgeRouter
    BridgeRouter -->|executeSignatures| XDaiForeignBridge
    BridgeRouter -->|safeExecuteSignaturesWithAutoGasLimit| ForeignAMB[Foreign AMB]

```

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

### Function Callflow

```mermaid
sequenceDiagram
    participant User
    participant BridgeRouter
    participant DaiPeripheral as XDaiBridgePeripheralForDaiPreUsdsUpgrade
    participant UsdsPeripheral as XDaiBridgePeripheralForUsdsPreUsdsUpgrade
    participant DaiUsds as DaiUsds
    participant XDaiForeignBridge as XDaiForeignBridge on Ethereum
    participant GnosisChain as XDaiHomeBridge on Gnosis Chain
    participant Receiver

    box Ethereum
        participant User
        participant BridgeRouter
        participant DaiPeripheral
        participant UsdsPeripheral
        participant DaiUsds
        participant XDaiForeignBridge
    end

    box Gnosis Chain
        participant GnosisChain
        participant Receiver
    end

    %% Relay DAI Flow
    par
    Note over User,Receiver: Relay DAI
    User->>BridgeRouter: DAI.approve(BridgeRouter, amount)
    User->>BridgeRouter: relayTokens(DAI, receiver, amount)
    BridgeRouter->>DaiPeripheral: Transfer DAI
    DaiPeripheral->>XDaiForeignBridge: relayTokens(receiver, amount)
    XDaiForeignBridge->>XDaiForeignBridge: Lock DAI as collateral
    XDaiForeignBridge-->>GnosisChain: Bridging process
    GnosisChain->>Receiver: Receive xDAI
    end

    %% Claim DAI Flow
    par
    Note over User,Receiver: Claim DAI
    User->>BridgeRouter: executeSignatures(message, signatures)
    BridgeRouter->>XDaiForeignBridge: executeSignatures(message, signatures)
    XDaiForeignBridge->>User: Transfer DAI to Receiver
    end

    %% Relay USDS Flow
    par
    Note over User,Receiver: Relay USDS
    User->>BridgeRouter: USDS.approve(BridgeRouter, amount)
    User->>BridgeRouter: relayTokens(USDS, receiver, amount)
    BridgeRouter->>UsdsPeripheral: Transfer USDS
    UsdsPeripheral->>DaiUsds: swapUsdsToDai()
    DaiUsds->>XDaiForeignBridge: Approve DAI
    XDaiForeignBridge->>XDaiForeignBridge: Lock DAI as collateral
    XDaiForeignBridge-->>GnosisChain: Bridging process
    GnosisChain->>Receiver: Receive xDAI
    end

    %% Claim USDS Flow (Fails)
    par
    Note over User,Receiver: Claim USDS
    User->>BridgeRouter: executeSignaturesUSDS(message, signatures)
    BridgeRouter->>BridgeRouter: Revert ClaimUsdsNotSupported()
    end
```

**Relay DAI**

1. DAI.approve(BridgeRouter, amount)  
   -> [BridgeRouter.relayTokens(DAI, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L44)  
   -> [XDaiBridgePeripheralForDaiPreUsdsUpgrade.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForDaiPreUsdsUpgrade.sol#L37)  
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim DAI**

1. [BridgeRouter.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L79)  
   -> [xDAIForeignBridge.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/BasicForeignBridge.sol#L22)  
   -> (internal) [onExecuteMessage](./contracts/upgradeable_contracts/erc20_to_native/XDaiForeignBridge.sol#L151) |Here is where the DAI is transferred

**Relay USDS**

1. USDS.approve(BridgeRouter, amount)  
   -> [BridgeRouter.relayTokens(USDS, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L47)  
   -> [XDaiBridgePeripheralForUsdsPreUsdsUpgrade.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheralForUsdsPreUsdsUpgrade.sol#L36) |Here is where USDS is swap to DAI  
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim USDS**

1. [BridgeRouter.executeSignaturesUSDS(message,signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L102)  
   -> revert `ClaimUsdsNotSupported()` `0x662554fc43b5d87090a5f9e8b365ca35213d23ae7082671886b760dc510ee8da`

XDaiForeignBridge's current implementation: https://etherscan.io/address/0x166124b75c798cedf1b43655e9b5284ebd5203db  
Code: https://github.com/gnosischain/tokenbridge-contracts/tree/xdaibridge/contracts/upgradeable_contracts/erc20_to_native

## Upgrade procedure

```mermaid
graph TD

    subgraph "Upgrade txs"
        UpgradeBundledTx[Execute BundledSafeTx by bridge governors]
        UpgradeBundledTx -->|Disable interest for DAI, Enable interest for USDS| XDaiForeignBridge
        UpgradeBundledTx -->|Set USDS as collateral token| XDaiForeignBridge
        UpgradeBundledTx -->|Set DAI route| BridgeRouter --> |DAI| XDaiBridgePeripheral
        UpgradeBundledTx -->|Set USDS route| BridgeRouter --> |USDS| XDaiForeignBridge
    end

    subgraph "Pre upgrade configuration"
        PreConfig[Pre-Upgrade Configuration]
        PreConfig -->|Set DAI route to| BridgeRouterPreUpgrade[BridgeRouter] -->|DAI| DaiPeripheralPre[XDaiBridgePeripheralForDaiPreUsdsUpgrade]
        PreConfig  -->|Set USDS route to| BridgeRouterPreUpgrade[BridgeRouter] -->|USDS |UsdsPeripheralPre[XDaiBridgePeripheralForUsdsPreUsdsUpgrade]
        PreConfig -->|DAI as collateral| XDaiForeignBridgeDaiCollateral[XDaiForeignBridge]
    end
    PreConfig -->|Upgrade| UpgradeBundledTx


```

Test for the upgrade procedures is written in [BridgeRouter.t.sol#upgradeBridgeAndSetupRoute](./test/foundry/BridgeRouter.t.sol#L533)

### Function calls during the proxy upgrade

> > The function calls during the upgrade on BridgeProxy and Router is a bundled Safe transaction, that will be signed and executed by [bridge governors](https://docs.gnosischain.com/bridges/management/#bridge-governance).

**Call on xDAI Foreign Bridge contract**

XDaiForeignBridgeProxy=`0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016`

Caller: Bridge Owner `0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6`

```solidity
   uint256 initialVersion = 9
   address newImpl = 0x3AbD91b5564BaF7966DcA7a30Bd50EAcc9aBeD77
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

**Update routes on BridgeRouter**

Caller: BridgeRouterOwner `0x42F38ec5A75acCEc50054671233dfAC9C0E7A3F6` (same as the bridge owner)

ROUTER_ADDRESS=0x9a873656c19Efecbfb4f9FAb5B7acdeAb466a0B0
XDAI_BRIDGE_PERIPHERAL=0x3b6669727927b934753B018EB421a84Ed4eb0a43
XDAI_FOREIGNBRIDGE_PROXY=`0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016`

```solidity
router.setRoute(address(DAI), address(xDAIBridgeperipheral));
router.setRoute(address(USDS), xDAIForeignBridgeProxy);
```

## After the upgrade

### Relay token

```mermaid
graph TD
    User([User]) -->|"relayTokens: DAI"| BridgeRouter
    User -->|"relayTokens: USDS"| BridgeRouter
    User -->|"relayTokens: Other ERC20"| BridgeRouter
    User -->|"relayTokens: ETH"| BridgeRouter

    subgraph "BridgeRouter Contract"
        BridgeRouter[BridgeRouter]
    end
    subgraph "Post-Upgrade Peripheral"
        UsdsPeripheral[XDaiBridgePeripheral]
    end

    BridgeRouter -->|DAI| UsdsPeripheral
    BridgeRouter -->|USDS| XDaiForeignBridge
    BridgeRouter -->|Other ERC20| OmniBridge[Foreign OmniBridge]
    BridgeRouter -->|ETH| WETHRouter[WETH OmniBridge Router]


    UsdsPeripheral -->|"Convert DAI to USDS"| XDaiForeignBridge

    subgraph "Omnibridge contract"
        OmniBridge --> OmniBridgeHome[Mint bridged token on Gnosis Chain]
        WETHRouter --> OmniBridgeHome
    end
    subgraph "XDaiForeignBridge Contract (Post-Upgrade)"
        XDaiForeignBridge[XDaiForeignBridge] -->|"USDS as collateral"| GnosisChain[Mint xDAI on Gnosis Chain]
    end
```

### To claim token

```mermaid
graph TD


    subgraph "BridgeRouter Contract"
        BridgeRouter[BridgeRouter]
    end


    subgraph "XDaiForeignBridge Contact"
        XDaiForeignBridge[XDaiForeignBridge] -->|exeucteSignatures| DAI[unlock DAI to recipient]
        XDaiForeignBridge[XDaiForeignBridge] -->|exeucteSignaturesUSDS| Ethereum[unlock USDS to recipient]

    end

    subgraph "ForeignAMB Contract"
        ForeignAMB[ForeignAMB] --> Action[Unlock token to recipient]
    end

    %% For claim operations (pre-upgrade)
    User -->|executeSignatures| BridgeRouter
    User -->|executeSignaturesUSDS| BridgeRouter
    User -->|safeExecuteSignaturesWithAutoGasLimit| BridgeRouter
    BridgeRouter -->|executeSignatures| XDaiForeignBridge
    BridgeRouter -->|executeSignaturesUSDS| XDaiForeignBridge
    BridgeRouter -->|safeExecuteSignaturesWithAutoGasLimit| ForeignAMB[Foreign AMB]

```

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

### Function Callflow

```mermaid
sequenceDiagram
    box Ethereum
        participant User
        participant BridgeRouter
        participant XDaiBridgePeripheral
        participant DaiUsds as DaiUsds
        participant XDaiForeignBridge
    end


    box Gnosis Chain

        participant GnosisChain as xDaiHomeBridge on Gnosis Chain
         participant Receiver
    end



    %% Relay DAI Flow
    par
    Note over User,Receiver: Relay DAI
    User->>BridgeRouter: DAI.approve(BridgeRouter, amount)
    User->>BridgeRouter: relayTokens(DAI, receiver, amount)
    BridgeRouter->>XDaiBridgePeripheral: Transfer DAI
    XDaiBridgePeripheral->>DaiUsds: swapDaiToUsds()
    DaiUsds->>XDaiForeignBridge: Approve USDS
    XDaiForeignBridge->>XDaiForeignBridge: Lock USDS as collateral
    XDaiForeignBridge-->>GnosisChain: Bridging process
    GnosisChain->>Receiver: receive xDAI
    end

    %% Claim DAI Flow
    par
    Note over User,Receiver: Claim DAI
    User->>BridgeRouter: executeSignatures(message, signatures)
    BridgeRouter->>XDaiForeignBridge: executeSignatures(message, signatures)
    XDaiForeignBridge->>DaiUsds: swapUsdsToDai()
    XDaiForeignBridge->>User: Transfer DAI to receiver
    end

    %% Relay USDS Flow
    par
    Note over User,Receiver: Relay USDS
    User->>BridgeRouter: USDS.approve(BridgeRouter, amount)
    User->>BridgeRouter: relayTokens(USDS, receiver, amount)
    BridgeRouter->>XDaiForeignBridge: Direct transfer of USDS
    XDaiForeignBridge->>XDaiForeignBridge: Lock USDS as collateral
    XDaiForeignBridge-->>GnosisChain: Bridging process
    GnosisChain->>Receiver: receive xDAI
    end

    %% Claim USDS Flow
    par
    Note over User,Receiver: Claim USDS
    User->>BridgeRouter: executeSignaturesUSDS(message, signatures)
    BridgeRouter->>XDaiForeignBridge: executeSignaturesUSDS(message, signatures)
    XDaiForeignBridge->>User: Transfer USDS to receiver
    end

```

**Relay DAI**

1. DAI.approve(BridgeRouter, amount)  
   -> [BridgeRouter.relayTokens(DAI, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L44)  
   -> [XDaiBridgePeripheral.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/XDaiBridgePeripheral.sol#L35)  
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim DAI**

1. [BridgeRouter.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L83)  
   -> [xDAIForeignBridge.executeSignatures(message, signatures)](./contracts/upgradeable_contracts/BasicForeignBridge.sol#L22)  
   -> (internal)[onExecuteMessage](./contracts/upgradeable_contracts/erc20_to_native/XDaiForeignBridge.sol#L146-L156) |Here is where USDS is swap to DAI

**Relay USDS**

1. USDS.approve(bridgeRouter, amount)  
   -> [BridgeRouter.relayTokens(USDS, receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L47)  
   -> [xDAIForeignBridge.relayTokens(receiver, amount)](./contracts/upgradeable_contracts/erc20_to_native/ForeignBridgeErcToNative.sol#L64)

**Claim USDS**

1. [BridgeRouter.executeSignaturesUSDS(message, signatures)](./contracts/upgradeable_contracts/erc20_to_native/BridgeRouter.sol#L107)  
   -> [xDAIForeigbBridge.executeSignaturesUSDS(message,signatures)](./contracts/upgradeable_contracts/erc20_to_native/XDaiForeignBridge.sol#L113)

# Call to Action: Update your code

To modify your existing smart contract code to work with the xDAI bridge after USDS migration, complete the following changes:

### Relay tokens

```solidity
  >>> Previous
  xDAIForeignBridge.relayTokens(address recipient, uint256 value)

  <<< Latest
   BridgeRouter.relayTokens(address token, address recipient, uint256 value)
```

### Claim tokens

```solidity
  >>> Previous
  xDAIForeignBridge.executeSignatures(bytes message, bytes signatures)

  <<< Latest
   BridgeRouter.executeSignatures(bytes message, bytes signatures)
   // or to claim USDS after the migration
   BridgeRouter.executeSignaturesUSDS(bytes message, bytes signatures)
```
