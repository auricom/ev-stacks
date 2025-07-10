#!/bin/sh
set -x
set -e

sleep 5

if [ ! -f "$ROLLKIT_HOME/config/signer.json" ]; then
    evm-single init --chain_id="$CHAIN_ID" --rollkit.node.aggregator=true --rollkit.signer.passphrase "$EVM_SIGNER_PASSPHRASE" --home "${ROLLKIT_HOME}"
fi

# Importing DA auth token
if [ -n "$DA_AUTH_TOKEN_PATH" ]; then
    if [ -f "$DA_AUTH_TOKEN_PATH" ]; then
        DA_AUTH_TOKEN=$(cat ${DA_AUTH_TOKEN_PATH})
    fi
fi

# Importing JWT token
if [ -n "$EVM_JWT_PATH" ]; then
    if [ -f "$EVM_JWT_PATH" ]; then
        EVM_JWT_SECRET=$(cat ${EVM_JWT_PATH})
    fi
fi

# Conditionally add --rollkit.da.address if ROLLKIT_DA_ADDRESS is set
da_flag=""
if [ -n "$DA_ADDRESS" ]; then
    da_flag="--rollkit.da.address $DA_ADDRESS"
fi

# Conditionally add --rollkit.da.auth_token if ROLLKIT_DA_AUTH_TOKEN is set
da_auth_token_flag=""
if [ -n "$DA_AUTH_TOKEN" ]; then
    da_auth_token_flag="--rollkit.da.auth_token $DA_AUTH_TOKEN"
fi

# Conditionally add --rollkit.da.namespace if ROLLKIT_DA_NAMESPACE is set
da_namespace_flag=""
if [ -n "$DA_NAMESPACE" ]; then
    da_namespace_flag="--rollkit.da.namespace $DA_NAMESPACE"
fi

# Conditionally add --rollkit.da.block_time if DA_BLOCK_TIME is set
da_block_time_flag=""
if [ -n "$DA_BLOCK_TIME" ]; then
    da_block_time_flag="--rollkit.da.block_time $DA_BLOCK_TIME"
fi

# Conditionally add --rollkit.da.namespace if ROLLKIT_DA_START_HEIGHT is set
da_start_height_flag=""
if [ -n "$DA_START_HEIGHT" ]; then
    da_start_height_flag="--rollkit.da.start_height $DA_START_HEIGHT"
fi

exec evm-single start \
    --chain_id="$CHAIN_ID" \
    --evm.jwt-secret $EVM_JWT_SECRET \
    --evm.genesis-hash $EVM_GENESIS_HASH \
    --evm.engine-url $EVM_ENGINE_URL \
    --evm.eth-url $EVM_ETH_URL \
    --rollkit.node.block_time $EVM_BLOCK_TIME \
    --rollkit.node.aggregator=true \
    --rollkit.signer.passphrase $EVM_SIGNER_PASSPHRASE \
    --rollkit.instrumentation.prometheus=true \
    --rollkit.instrumentation.prometheus_listen_addr=":26660" \
    --rollkit.p2p.listen_address="/ip4/0.0.0.0/tcp/7676" \
    --rollkit.rpc.address=0.0.0.0:7331 \
    --rollkit.log.level=debug \
    $da_flag \
    $da_auth_token_flag \
    $da_namespace_flag \
    $da_block_time_flag \
    --home $ROLLKIT_HOME
