#!/usr/bin/env bash
pkill anvil
source .env
anvil --fork-url $RPC_MAINNET