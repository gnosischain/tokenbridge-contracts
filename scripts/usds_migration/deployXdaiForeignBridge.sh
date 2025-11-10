#!/usr/bin/env bash
source .env
JSON_OUTPUT=$(forge create --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY --json --optimize --verify --etherscan-api-key $ETHERSCAN_API_KEY_MAINNET XDaiForeignBridge)

DEPLOYED_TO=$(jq -r '.deployedTo' <<< "$JSON_OUTPUT")

# Update the NEW_IMPLEMENTATION variable in the .env file with the value of DEPLOYED_TO 
# Requires .env and variable to already be declared!
sed -i "s/^XDAI_FOREIGNBRIDGE_NEW_IMPLEMENTATION=.*/XDAI_FOREIGNBRIDGE_NEW_IMPLEMENTATION=$DEPLOYED_TO/" .env
