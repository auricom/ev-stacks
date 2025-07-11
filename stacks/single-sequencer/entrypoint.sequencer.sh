#!/bin/sh
set -e

sleep 5

# Function to extract --home value from arguments
get_home_dir() {
  home_dir="$HOME/.evm-single"

  # Parse arguments to find --home
  while [ $# -gt 0 ]; do
    case "$1" in
      --home)
        if [ -n "$2" ]; then
          home_dir="$2"
          break
        fi
        ;;
      --home=*)
        home_dir="${1#--home=}"
        break
        ;;
    esac
    shift
  done

  echo "$home_dir"
}

# Get the home directory (either from --home flag or default)
CONFIG_HOME=$(get_home_dir "$@")

if [ ! -f "$CONFIG_HOME/config/node_key.json" ]; then

  # Build init flags array
  init_flags="--home=$CONFIG_HOME"

  # Add required flags if environment variables are set
  if [ -n "$EVM_SIGNER_PASSPHRASE" ]; then
    init_flags="$init_flags --rollkit.node.aggregator=true --rollkit.signer.passphrase $EVM_SIGNER_PASSPHRASE"
  fi

  INIT_COMMAND="evm-single init $init_flags"
  echo "Create default config with command:"
  echo "$INIT_COMMAND"
  $INIT_COMMAND
fi

# Importing DA auth token
if [ -n "$DA_AUTH_TOKEN_PATH" ]; then
    if [ -f "$DA_AUTH_TOKEN_PATH" ]; then
        DA_AUTH_TOKEN=$(cat ${DA_AUTH_TOKEN_PATH})
    fi
fi

# Auto-retrieve genesis hash if not provided
if [ -z "$EVM_GENESIS_HASH" ] && [ -n "$EVM_ETH_URL" ]; then
    echo "EVM_GENESIS_HASH not provided, attempting to retrieve from reth-sequencer..."

    # Wait for reth-sequencer to be ready (max 60 seconds)
    retry_count=0
    max_retries=12
    while [ $retry_count -lt $max_retries ]; do
        if curl -s --connect-timeout 5 "$EVM_ETH_URL" >/dev/null 2>&1; then
            echo "Reth-sequencer is ready, retrieving genesis hash..."
            break
        fi
        echo "Waiting for reth-sequencer to be ready... (attempt $((retry_count + 1))/$max_retries)"
        sleep 5
        retry_count=$((retry_count + 1))
    done

    if [ $retry_count -eq $max_retries ]; then
        echo "Warning: Could not connect to reth-sequencer at $EVM_ETH_URL after $max_retries attempts"
        echo "Proceeding without auto-retrieved genesis hash..."
    else
        # Retrieve genesis block hash using curl and shell parsing
        genesis_response=$(curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0", false],"id":1}' \
            "$EVM_ETH_URL" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$genesis_response" ]; then
            # Extract hash using shell parameter expansion and sed
            # Look for "hash":"0x..." pattern and extract the hash value
            genesis_hash=$(echo "$genesis_response" | sed -n 's/.*"hash":"\([^"]*\)".*/\1/p')

            if [ -n "$genesis_hash" ] && [ "${genesis_hash#0x}" != "$genesis_hash" ]; then
                EVM_GENESIS_HASH="$genesis_hash"
                echo "Successfully retrieved genesis hash: $EVM_GENESIS_HASH"
            else
                echo "Warning: Could not parse genesis hash from response"
                echo "Response: $genesis_response"
            fi
        else
            echo "Warning: Failed to retrieve genesis block from reth-sequencer"
        fi
    fi
fi

# Build start flags array
default_flags="--home=$CONFIG_HOME"

# Add required flags if environment variables are set
if [ -n "$EVM_JWT_SECRET" ]; then
  default_flags="$default_flags --evm.jwt-secret $EVM_JWT_SECRET"
fi

if [ -n "$EVM_GENESIS_HASH" ]; then
  default_flags="$default_flags --evm.genesis-hash $EVM_GENESIS_HASH"
fi

if [ -n "$EVM_ENGINE_URL" ]; then
  default_flags="$default_flags --evm.engine-url $EVM_ENGINE_URL"
fi

if [ -n "$EVM_ETH_URL" ]; then
  default_flags="$default_flags --evm.eth-url $EVM_ETH_URL"
fi

if [ -n "$EVM_BLOCK_TIME" ]; then
  default_flags="$default_flags --rollkit.node.block_time $EVM_BLOCK_TIME"
fi

if [ -n "$EVM_SIGNER_PASSPHRASE" ]; then
  default_flags="$default_flags --rollkit.node.aggregator=true --rollkit.signer.passphrase $EVM_SIGNER_PASSPHRASE"
fi

# Conditionally add DA-related flags
if [ -n "$DA_ADDRESS" ]; then
  default_flags="$default_flags --rollkit.da.address $DA_ADDRESS"
fi

if [ -n "$DA_AUTH_TOKEN" ]; then
  default_flags="$default_flags --rollkit.da.auth_token $DA_AUTH_TOKEN"
fi

if [ -n "$DA_NAMESPACE" ]; then
  default_flags="$default_flags --rollkit.da.namespace $DA_NAMESPACE"
fi

# If no arguments passed, show help
if [ $# -eq 0 ]; then
  exec evm-single
fi

# If first argument is "start", apply default flags
if [ "$1" = "start" ]; then
  shift
  START_COMMAND="evm-single start $default_flags"
  echo "Create default config with command:"
  echo "$START_COMMAND \"$@\""
  exec $START_COMMAND "$@"

else
  # For any other command/subcommand, pass through directly
  exec evm-single "$@"
fi
