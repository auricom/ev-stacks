#!/bin/bash

# Rollkit One-Liner Deployment Script
# This script provides a complete deployment framework for Rollkit sequencer nodes and Celestia DA
# Usage: curl -fsSL https://raw.githubusercontent.com/auricom/ev-stacks/main/scripts/deploy-rollkit.sh | bash

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME="deploy-rollkit"
readonly REPO_URL="https://github.com/auricom/ev-stacks"
readonly DEPLOYMENT_DIR="$HOME/rollkit-deployment"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
VERBOSE=false
DRY_RUN=false
FORCE_INSTALL=false
LOG_FILE=""
CLEANUP_ON_EXIT=true
DEPLOY_DA_CELESTIA=false
SELECTED_DA=""

# Logging functions with emojis
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo -e "ℹ️  [$timestamp] ${GREEN}INFO${NC}: $message" >&2
            ;;
        "SUCCESS")
            echo -e "✅ [$timestamp] ${GREEN}SUCCESS${NC}: $message" >&2
            ;;
        "WARN")
            echo -e "⚠️  [$timestamp] ${YELLOW}WARN${NC}: $message" >&2
            ;;
        "ERROR")
            echo -e "❌ [$timestamp] ${RED}ERROR${NC}: $message" >&2
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "🔍 [$timestamp] ${BLUE}DEBUG${NC}: $message" >&2
            fi
            ;;
        "DOWNLOAD")
            echo -e "⬇️  [$timestamp] ${BLUE}DOWNLOAD${NC}: $message" >&2
            ;;
        "INIT")
            echo -e "🚀 [$timestamp] ${GREEN}INIT${NC}: $message" >&2
            ;;
        "CONFIG")
            echo -e "⚙️  [$timestamp] ${YELLOW}CONFIG${NC}: $message" >&2
            ;;
        "DEPLOY")
            echo -e "🚢 [$timestamp] ${GREEN}DEPLOY${NC}: $message" >&2
            ;;
    esac

    # Log to file if specified
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    log "DEBUG" "Cleanup function called with exit code: $exit_code"

    if [[ "$CLEANUP_ON_EXIT" == "true" && $exit_code -ne 0 ]]; then
        log "INFO" "Cleaning up due to error..."

        # Stop any running containers
        if command -v docker compose >/dev/null 2>&1; then
            if [[ -f "$DEPLOYMENT_DIR/single-sequencer/docker-compose.yml" ]]; then
                log "DEBUG" "Stopping single-sequencer Docker containers..."
                cd "$DEPLOYMENT_DIR/single-sequencer" && docker compose down --remove-orphans 2>/dev/null || true
            fi

            if [[ -f "$DEPLOYMENT_DIR/da-celestia/docker-compose.yml" ]]; then
                log "DEBUG" "Stopping da-celestia Docker containers..."
                cd "$DEPLOYMENT_DIR/da-celestia" && docker compose down --remove-orphans 2>/dev/null || true
            fi
        fi

        # Remove deployment directory if it was created by this script
        if [[ -d "$DEPLOYMENT_DIR" && -f "$DEPLOYMENT_DIR/.created_by_script" ]]; then
            log "DEBUG" "Removing deployment directory..."
            rm -rf "$DEPLOYMENT_DIR"
        fi
    fi

    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT
trap 'error_exit "Script interrupted by user" 130' INT
trap 'error_exit "Script terminated" 143' TERM

# Interactive DA selection
select_da_layer() {
    log "CONFIG" "Selecting Data Availability layer..."

    echo ""
    echo "🌌 Available Data Availability (DA) layers:"
    echo "  1) da-celestia - Celestia modular DA network"
    echo "  2) none - Single sequencer only (no external DA)"
    echo ""

    while true; do
        echo -n "Please select a DA layer (1-2): "
        read -r choice

        case $choice in
            1)
                SELECTED_DA="da-celestia"
                DEPLOY_DA_CELESTIA=true
                log "SUCCESS" "Selected DA layer: Celestia"
                break
                ;;
            2)
                SELECTED_DA="none"
                DEPLOY_DA_CELESTIA=false
                log "SUCCESS" "Selected: Single sequencer only (no external DA)"
                break
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done

    echo ""
}

# Download deployment files for single-sequencer
download_sequencer_files() {
    log "DOWNLOAD" "Downloading single-sequencer deployment files..."

    # Create deployment directory and single-sequencer subfolder
    mkdir -p "$DEPLOYMENT_DIR/single-sequencer" || error_exit "Failed to create single-sequencer directory"

    cd "$DEPLOYMENT_DIR/single-sequencer" || error_exit "Failed to change to single-sequencer directory"

    # Download files from the repository
    local base_url="https://raw.githubusercontent.com/auricom/ev-stacks/main"

    # Choose the appropriate docker-compose file based on DA selection
    local docker_compose_file
    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        docker_compose_file="stacks/single-sequencer/docker-compose.da.celestia.yml"
        log "CONFIG" "Using DA Celestia integrated docker-compose file"
    else
        docker_compose_file="stacks/single-sequencer/docker-compose.yml"
        log "CONFIG" "Using standalone docker-compose file"
    fi

    local files=(
        "stacks/single-sequencer/.env"
        "$docker_compose_file"
        "stacks/single-sequencer/entrypoint.sequencer.sh"
        "stacks/single-sequencer/genesis.json"
        "stacks/single-sequencer/single-sequencer.Dockerfile"
    )

    for file in "${files[@]}"; do
        log "DEBUG" "Downloading $file..."
        local filename=$(basename "$file")
        # Always save as docker-compose.yml regardless of source file name
        if [[ "$filename" == "docker-compose.da.celestia.yml" ]]; then
            filename="docker-compose.yml"
        fi
        curl -fsSL "$base_url/$file" -o "$filename" || error_exit "Failed to download $filename"
    done

    log "SUCCESS" "Single-sequencer deployment files downloaded successfully"
}

# Download deployment files for da-celestia
download_da_celestia_files() {
    log "DOWNLOAD" "Downloading da-celestia deployment files..."

    # Create da-celestia subfolder
    mkdir -p "$DEPLOYMENT_DIR/da-celestia" || error_exit "Failed to create da-celestia directory"

    cd "$DEPLOYMENT_DIR/da-celestia" || error_exit "Failed to change to da-celestia directory"

    # Download files from the repository
    local base_url="https://raw.githubusercontent.com/auricom/ev-stacks/main"

    local files=(
        "stacks/da-celestia/.env"
        "stacks/da-celestia/celestia-app.Dockerfile"
        "stacks/da-celestia/docker-compose.yml"
        "stacks/da-celestia/entrypoint.appd.sh"
        "stacks/da-celestia/entrypoint.da.sh"
    )

    for file in "${files[@]}"; do
        log "DEBUG" "Downloading $file..."
        local filename=$(basename "$file")
        curl -fsSL "$base_url/$file" -o "$filename" || error_exit "Failed to download $filename"
    done

    # Make entrypoint scripts executable
    chmod +x entrypoint.appd.sh entrypoint.da.sh || error_exit "Failed to make entrypoint scripts executable"

    log "SUCCESS" "DA-Celestia deployment files downloaded successfully"
}

# Download deployment files
download_deployment_files() {
    log "INIT" "Downloading deployment files..."

    # Create main deployment directory
    mkdir -p "$DEPLOYMENT_DIR" || error_exit "Failed to create deployment directory"
    touch "$DEPLOYMENT_DIR/.created_by_script"

    # Download single-sequencer files
    download_sequencer_files

    # Download da-celestia files if requested
    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        download_da_celestia_files
    fi

    log "SUCCESS" "All deployment files downloaded successfully"
}

# Configuration management for single-sequencer
setup_sequencer_configuration() {
    log "CONFIG" "Setting up single-sequencer configuration..."

    # Change to single-sequencer directory
    cd "$DEPLOYMENT_DIR/single-sequencer" || error_exit "Failed to change to single-sequencer directory"

    local env_file=".env"

    if [[ ! -f "$env_file" ]]; then
        error_exit "Environment file not found: $env_file"
    fi

    if [[ ! -r "$env_file" ]]; then
        error_exit "Environment file is not readable: $env_file"
    fi

    # Check for missing EVM_SIGNER_PASSPHRASE and generate if empty
    if grep -q "^EVM_SIGNER_PASSPHRASE=$" "$env_file" || ! grep -q "^EVM_SIGNER_PASSPHRASE=" "$env_file"; then
        log "CONFIG" "Generating random EVM signer passphrase..."
        local passphrase=$(openssl rand -base64 32 | tr -d '\n')
        # Escape special characters for sed and use | as delimiter to avoid conflicts with /
        local passphrase_escaped=$(printf '%s\n' "$passphrase" | sed 's/[[\.*^$()+?{|]/\\&/g')
        sed -i "s|^EVM_SIGNER_PASSPHRASE=.*|EVM_SIGNER_PASSPHRASE=\"$passphrase_escaped\"|" "$env_file"
        log "SUCCESS" "EVM signer passphrase generated and set"
    fi

    # Check for missing CHAIN_ID and prompt user
    if grep -q "^CHAIN_ID=$" "$env_file" || ! grep -q "^CHAIN_ID=" "$env_file"; then
        echo "Chain ID is required for the deployment."
        echo "Please enter a chain ID (e.g., 1234 for development, or your custom chain ID):"
        read -r chain_id

        # Validate chain ID is numeric
        if ! [[ "$chain_id" =~ ^[0-9]+$ ]]; then
            error_exit "Chain ID must be a number"
        fi

        # Update chain ID in .env file
        # Escape special characters for sed and use | as delimiter
        local chain_id_escaped=$(printf '%s\n' "$chain_id" | sed 's/[[\.*^$()+?{|]/\\&/g')
        sed -i "s|^CHAIN_ID=.*|CHAIN_ID=\"$chain_id_escaped\"|" "$env_file"

        # Update chainId in genesis.json file
        if [[ -f "genesis.json" ]]; then
            sed -i "s|\"chainId\": [0-9]*|\"chainId\": $chain_id|" "genesis.json"
            log "SUCCESS" "Updated chainId in genesis.json to: $chain_id"
        else
            log "WARN" "genesis.json not found, skipping chainId update"
        fi

        log "SUCCESS" "Chain ID set to: $chain_id"
    fi

    # If DA Celestia is deployed, add DA configuration to single-sequencer
    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        log "CONFIG" "Configuring single-sequencer for DA Celestia integration..."

        # Get DA_NAMESPACE from da-celestia .env file
        local da_celestia_env="$DEPLOYMENT_DIR/da-celestia/.env"
        if [[ -f "$da_celestia_env" ]]; then
            local da_namespace=$(grep "^DA_NAMESPACE=" "$da_celestia_env" | cut -d'=' -f2 | tr -d '"')

            if [[ -n "$da_namespace" ]]; then
                # Add or update DA_NAMESPACE in single-sequencer .env
                if grep -q "^DA_NAMESPACE=" "$env_file"; then
                    sed -i "s|^DA_NAMESPACE=.*|DA_NAMESPACE=\"$da_namespace\"|" "$env_file"
                else
                    echo "DA_NAMESPACE=\"$da_namespace\"" >> "$env_file"
                fi
                log "SUCCESS" "DA_NAMESPACE set to: $da_namespace"
            else
                log "WARN" "DA_NAMESPACE is empty in da-celestia .env file. Single-sequencer may show warnings."
                # Still add the empty DA_NAMESPACE to single-sequencer .env to avoid undefined variable warnings
                if ! grep -q "^DA_NAMESPACE=" "$env_file"; then
                    echo "DA_NAMESPACE=" >> "$env_file"
                fi
            fi
        else
            log "WARN" "DA-Celestia .env file not found. Adding empty DA_NAMESPACE to prevent warnings."
            # Add empty DA_NAMESPACE to single-sequencer .env to avoid undefined variable warnings
            if ! grep -q "^DA_NAMESPACE=" "$env_file"; then
                echo "DA_NAMESPACE=" >> "$env_file"
            fi
        fi
    fi

    log "SUCCESS" "Single-sequencer configuration setup completed"
}

# Configuration management for da-celestia
setup_da_celestia_configuration() {
    log "CONFIG" "Setting up da-celestia configuration..."

    # Change to da-celestia directory
    cd "$DEPLOYMENT_DIR/da-celestia" || error_exit "Failed to change to da-celestia directory"

    local env_file=".env"

    if [[ ! -f "$env_file" ]]; then
        error_exit "DA-Celestia environment file not found: $env_file"
    fi

    if [[ ! -r "$env_file" ]]; then
        error_exit "DA-Celestia environment file is not readable: $env_file"
    fi

    # Check for missing DA_NAMESPACE and prompt user
    if grep -q "^DA_NAMESPACE=$" "$env_file" || ! grep -q "^DA_NAMESPACE=" "$env_file"; then
        echo ""
        echo "🌌 DA Namespace is required for Celestia data availability."
        echo "This should be a unique identifier for your rollup (e.g., 'myrollup', 'testchain')."
        echo "Please enter a DA namespace (alphanumeric characters only):"
        read -r da_namespace

        # Validate DA namespace (alphanumeric only)
        if ! [[ "$da_namespace" =~ ^[a-zA-Z0-9]+$ ]]; then
            error_exit "DA namespace must contain only alphanumeric characters"
        fi

        # Update DA_NAMESPACE in .env file
        # Escape special characters for sed and use | as delimiter
        local da_namespace_escaped=$(printf '%s\n' "$da_namespace" | sed 's/[[\.*^$()+?{|]/\\&/g')
        sed -i "s|^DA_NAMESPACE=.*|DA_NAMESPACE=\"$da_namespace_escaped\"|" "$env_file"

        log "SUCCESS" "DA namespace set to: $da_namespace"
    fi

    log "SUCCESS" "DA-Celestia configuration setup completed"
}

# Configuration management
setup_configuration() {
    log "CONFIG" "Setting up configuration..."

    # Setup da-celestia configuration first if deployed (so DA_NAMESPACE is available for single-sequencer)
    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        setup_da_celestia_configuration
    fi

    # Setup single-sequencer configuration
    setup_sequencer_configuration

    log "SUCCESS" "All configuration setup completed"
}

# Create shared volume for DA auth token
create_shared_volume() {
    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        log "CONFIG" "Creating shared volume for DA auth token..."

        # Create the celestia-node-export volume if it doesn't exist
        if ! docker volume inspect celestia-node-export >/dev/null 2>&1; then
            if ! docker volume create celestia-node-export; then
                error_exit "Failed to create shared volume celestia-node-export"
            fi
            log "SUCCESS" "Created shared volume: celestia-node-export"
        else
            log "INFO" "Shared volume celestia-node-export already exists"
        fi
    fi
}

# Deployment preparation
prepare_deployment() {
    log "DEPLOY" "Preparing deployment files..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Deployment files prepared. Ready to run services"
        return 0
    fi

    # Create shared volume for DA integration
    create_shared_volume

    log "SUCCESS" "Deployment files prepared successfully"
}

# Validate deployment files for single-sequencer
validate_sequencer_files() {
    log "DEBUG" "Validating single-sequencer deployment files..."

    # Change to single-sequencer directory
    cd "$DEPLOYMENT_DIR/single-sequencer" || error_exit "Failed to change to single-sequencer directory"

    local required_files=(
        "docker-compose.yml"
        ".env"
        "genesis.json"
        "entrypoint.sequencer.sh"
        "single-sequencer.Dockerfile"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error_exit "Required single-sequencer file not found: $file"
        fi
    done

    log "SUCCESS" "Single-sequencer files validation completed"
}

# Validate deployment files for da-celestia
validate_da_celestia_files() {
    log "DEBUG" "Validating da-celestia deployment files..."

    # Change to da-celestia directory
    cd "$DEPLOYMENT_DIR/da-celestia" || error_exit "Failed to change to da-celestia directory"

    local required_files=(
        "docker-compose.yml"
        ".env"
        "entrypoint.appd.sh"
        "entrypoint.da.sh"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error_exit "Required da-celestia file not found: $file"
        fi
    done

    log "SUCCESS" "DA-Celestia files validation completed"
}

# Validate deployment files
validate_deployment_files() {
    log "INFO" "Validating deployment files..."

    # Validate single-sequencer files
    validate_sequencer_files

    # Validate da-celestia files if deployed
    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        validate_da_celestia_files
    fi

    log "SUCCESS" "All deployment files validation completed successfully"
}

# Progress reporting
show_deployment_status() {
    log "SUCCESS" "Deployment Setup Complete"
    echo "🎉 =========================="
    echo "📁 Deployment Directory: $DEPLOYMENT_DIR"
    echo ""
    echo "🚀 Available Stacks:"
    echo "  📦 Single Sequencer: $DEPLOYMENT_DIR/single-sequencer"

    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        echo "  🌌 DA Celestia: $DEPLOYMENT_DIR/da-celestia"
    fi

    echo ""
    echo "▶️  Next Steps:"
    echo ""
    echo "🔹 Single Sequencer:"
    echo "  1. cd $DEPLOYMENT_DIR/single-sequencer"
    echo "  2. docker compose up -d"
    echo ""

    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        echo "🔹 DA Celestia (run in separate terminal):"
        echo "  1. cd $DEPLOYMENT_DIR/da-celestia"
        echo "  2. docker compose up -d"
        echo ""
    fi

    echo "🌐 Service Endpoints:"
    echo "  📡 Single Sequencer:"
    echo "    - Reth RPC: http://localhost:8545"
    echo "    - Sequencer RPC: http://localhost:7331"
    echo "    - Prometheus Metrics: http://localhost:26660"

    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        echo "  🌌 DA Celestia:"
        echo "    - Light Node RPC: http://localhost:26658"
        echo "    - App Daemon RPC: http://localhost:26657"
    fi

    echo ""
    echo "🛠️  Service Management:"
    echo "  - View status: docker compose ps"
    echo "  - View logs: docker compose logs -f"
    echo "  - Stop services: docker compose down"
    echo "  - Restart services: docker compose restart"
    echo ""
    echo "🔍 Health Monitoring:"
    echo "  - Check service status: docker compose ps"
    echo "  - Test endpoints manually using curl"
    echo "  - View service logs: docker compose logs -f"
}

# Usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Rollkit One-Liner Deployment Script v$SCRIPT_VERSION

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Show what would be done without executing
    -f, --force             Force installation even if components exist
    -l, --log-file FILE     Log output to specified file
    --no-cleanup            Don't cleanup on error
    --deployment-dir DIR    Use custom deployment directory (default: $DEPLOYMENT_DIR)
    --with-da-celestia      Also deploy DA Celestia stack

EXAMPLES:
    # Basic single-sequencer deployment
    $0

    # Deploy both single-sequencer and DA Celestia
    $0 --with-da-celestia

    # Verbose deployment with logging
    $0 --verbose --log-file deployment.log --with-da-celestia

    # Dry run to see what would be done
    $0 --dry-run --with-da-celestia

    # One-liner remote execution with DA Celestia
    curl -fsSL https://raw.githubusercontent.com/auricom/ev-stacks/main/scripts/deploy-rollkit.sh | bash -s -- --with-da-celestia

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -l|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            --no-cleanup)
                CLEANUP_ON_EXIT=false
                shift
                ;;
            --deployment-dir)
                DEPLOYMENT_DIR="$2"
                shift 2
                ;;
            --with-da-celestia)
                DEPLOY_DA_CELESTIA=true
                shift
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}

# Main deployment function
main() {
    log "INIT" "Starting Rollkit deployment v$SCRIPT_VERSION"

    # Initialize log file if specified
    if [[ -n "$LOG_FILE" ]]; then
        touch "$LOG_FILE" || error_exit "Failed to create log file: $LOG_FILE"
        log "INFO" "Logging to: $LOG_FILE"
    fi

    # Interactive DA selection if not specified via command line
    if [[ "$DEPLOY_DA_CELESTIA" == "false" && -z "$SELECTED_DA" ]]; then
        select_da_layer
    fi

    # Show what will be deployed
    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        log "INFO" "Deploying: Single Sequencer + DA Celestia stacks"
    else
        log "INFO" "Deploying: Single Sequencer stack only"
    fi

    # Run deployment steps
    download_deployment_files
    setup_configuration
    validate_deployment_files
    prepare_deployment
    show_deployment_status

    log "SUCCESS" "Rollkit deployment setup completed successfully!"

    if [[ "$DEPLOY_DA_CELESTIA" == "true" ]]; then
        log "INFO" "🚀 Start DA Celestia first: cd $DEPLOYMENT_DIR/da-celestia && docker compose up -d"
        log "INFO" "🚀 Then start Sequencer: cd $DEPLOYMENT_DIR/single-sequencer && docker compose up -d"
    else
        log "INFO" "🚀 Start your Rollkit sequencer: cd $DEPLOYMENT_DIR/single-sequencer && docker compose up -d"
    fi

    # Disable cleanup on successful exit
    CLEANUP_ON_EXIT=false
}

# Script entry point
# Handle both direct execution and piped execution
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]] || [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    parse_arguments "$@"
    main
fi
