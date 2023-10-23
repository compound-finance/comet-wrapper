#!/bin/bash

set -exo pipefail

if [ -n "$RPC_URL" ]; then
  rpc_args="--rpc-url $RPC_URL"
else
  rpc_args=""
fi

if [ -n "$DEPLOYER_PK" ]; then
  wallet_args="--private-key $DEPLOYER_PK"
else
  wallet_args="--unlocked"
fi

if [ -n "$ETHERSCAN_KEY" ]; then
  etherscan_args="--verify --etherscan-api-key $ETHERSCAN_KEY"
else
  etherscan_args=""
fi

if [ -z "$COMET_ADDRESS" ]; then
  echo "COMET_ADDRESS is not set"
  exit 1
fi

if [ -z "$REWARDS_ADDRESS" ]; then
  echo "REWARDS_ADDRESS is not set"
  exit 1
fi

if [ -z "$PROXY_ADMIN_ADDRESS" ]; then
  echo "PROXY_ADMIN_ADDRESS is not set"
  exit 1
fi

if [ -z "$TOKEN_NAME" ]; then
  echo "TOKEN_NAME is not set"
  exit 1
fi

if [ -z "$TOKEN_SYMBOL" ]; then
  echo "TOKEN_SYMBOL is not set"
  exit 1
fi

forge script \
    $rpc_args \
    $wallet_args \
    $etherscan_args \
    --broadcast \
    $@ \
    script/DeployCometWrapper.s.sol:DeployCometWrapper