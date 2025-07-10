#!/bin/bash
# Fail on any error
set -e

# Fail on any error in a pipeline
set -o pipefail

# Fail when using undeclared variables
set -u

set -x

# Logging function with emojis
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo "ℹ️  [$timestamp] INFO: $message"
            ;;
        "SUCCESS")
            echo "✅ [$timestamp] SUCCESS: $message"
            ;;
        "WARNING")
            echo "⚠️  [$timestamp] WARNING: $message"
            ;;
        "ERROR")
            echo "❌ [$timestamp] ERROR: $message"
            ;;
        "DEBUG")
            echo "🔍 [$timestamp] DEBUG: $message"
            ;;
        "DOWNLOAD")
            echo "⬇️  [$timestamp] DOWNLOAD: $message"
            ;;
        "INIT")
            echo "🚀 [$timestamp] INIT: $message"
            ;;
        *)
            echo "📝 [$timestamp] $level: $message"
            ;;
    esac
}

APPD_NODE_CONFIG_PATH=/home/celestia/.celestia/config/config.toml
MONIKER=${MONIKER:-bb-node}

log "INIT" "Starting Celestia App Daemon initialization"
log "INFO" "Using moniker: $MONIKER"
log "INFO" "Using DA network: $DA_NETWORK"
log "INFO" "Config path: $APPD_NODE_CONFIG_PATH"

# Initializing the app node
if [ ! -f "$APPD_NODE_CONFIG_PATH" ]; then
    log "INFO" "Config file does not exist. Initializing the appd node"

    log "INIT" "Initializing celestia-appd with moniker: $MONIKER and chain-id: $DA_NETWORK"
    celestia-appd init ${MONIKER} --chain-id ${DA_NETWORK}
    log "SUCCESS" "celestia-appd initialization completed"

    log "DOWNLOAD" "Downloading genesis file for network: $DA_NETWORK"
    celestia-appd download-genesis ${DA_NETWORK}
    log "SUCCESS" "Genesis file downloaded successfully"

    # Seeds
    log "INFO" "Fetching seeds configuration"
    SEEDS=$(curl -sL https://raw.githubusercontent.com/celestiaorg/networks/master/${DA_NETWORK}/seeds.txt | tr '\n' ',')
    log "SUCCESS" "Seeds fetched: $SEEDS"

    log "INFO" "Updating seeds configuration in config.toml"
    # Escape special characters in SEEDS for sed
    SEEDS_ESCAPED=$(printf '%s\n' "$SEEDS" | sed 's/[[\.*^$()+?{|]/\\&/g')
    sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS_ESCAPED\"/" /home/celestia/.celestia-app/config/config.toml
    log "SUCCESS" "Seeds configuration updated"

    # Quick sync
    log "INFO" "Preparing for quick sync - cleaning existing data"
    rm -rf /home/celestia/.celestia-app/data
    mkdir -p /home/celestia/.celestia-app/data
    log "SUCCESS" "Data directory prepared"

    log "INFO" "Fetching snapshot information"
    snapshot_url="https://server-5.itrocket.net/testnet/celestia/.current_state.json"
    log "DOWNLOAD" "Fetching snapshot metadata from: $snapshot_url"

    if ! response=$(curl -fsSL "$snapshot_url" 2>/dev/null); then
        log "ERROR" "Failed to fetch snapshot information from $snapshot_url"
        exit 1
    fi
    log "SUCCESS" "Snapshot metadata fetched successfully"

    # Extract snapshot name using jq
    log "INFO" "Parsing snapshot information"
    if ! snapshot_name=$(echo "$response" | jq -r '.snapshot_name // empty' 2>/dev/null); then
        log "ERROR" "Failed to parse JSON response with jq"
        exit 1
    fi

    if [[ -z "$snapshot_name" || "$snapshot_name" == "null" ]]; then
        log "ERROR" "Snapshot name not found in response"
        exit 1
    fi

    log "SUCCESS" "Found snapshot: $snapshot_name"

    # Download snapshot using curl instead of aria2c
    snapshot_download_url="https://server-5.itrocket.net/testnet/celestia/$snapshot_name"
    log "DOWNLOAD" "Downloading snapshot from: $snapshot_download_url"
    log "INFO" "This may take several minutes depending on your connection speed..."

    if ! curl -fL --progress-bar -o /tmp/celestia-archive-snap.tar.lz4 "$snapshot_download_url"; then
        log "ERROR" "Failed to download snapshot from $snapshot_download_url"
        exit 1
    fi
    log "SUCCESS" "Snapshot downloaded successfully to /tmp/celestia-archive-snap.tar.lz4"

    log "INFO" "Extracting snapshot archive"
    if ! tar -I lz4 -xvf /tmp/celestia-archive-snap.tar.lz4 -C $HOME/.celestia-app; then
        log "ERROR" "Failed to extract snapshot archive"
        exit 1
    fi
    log "SUCCESS" "Snapshot extracted successfully"

    log "INFO" "Cleaning up temporary files"
    rm /tmp/celestia-archive-snap.tar.lz4
    log "SUCCESS" "Temporary files cleaned up"

else
    log "INFO" "Config file already exists at $APPD_NODE_CONFIG_PATH"
    log "INFO" "Skipping initialization - node already configured"
fi

log "INIT" "Starting celestia-appd with chain-id: $DA_NETWORK"
log "INFO" "Node is now starting up..."
celestia-appd start --chain-id ${DA_NETWORK}
