#!/usr/bin/env bash
source .env

forge test --fork-url $RPC_MAINNET -vvv
#forge snapshot --fork-url "http://localhost:8545" --silent
#cat .gas-snapshot