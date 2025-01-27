#!/usr/bin/env bash
source .env
JSON_OUTPUT=$(forge create --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --json --optimize XDaiForeignBridge)

DEPLOYED_TO=$(jq -r '.deployedTo' <<< "$JSON_OUTPUT")

# Update the NEW_IMPLEMENTATION variable in the .env file with the value of DEPLOYED_TO 
# Requires .env and variable to already be declared!
sed -i "s/^NEW_IMPLEMENTATION=.*/NEW_IMPLEMENTATION=$DEPLOYED_TO/" .env

forge test --fork-url "http://localhost:8545" -vvv
#forge snapshot --fork-url "http://localhost:8545" --silent
#cat .gas-snapshot