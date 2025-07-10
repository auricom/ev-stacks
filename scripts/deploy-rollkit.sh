#!/bin/bash

# Rollkit One-Liner Deployment Script
# This script provides a complete deployment framework for Rollkit sequencer nodes
# Usage: curl -fsSL https://raw.githubusercontent.com/01builders/infra/main/scripts/deploy-rollkit.sh | bash

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
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

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message" >&2
            fi
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
        if command -v docker-compose >/dev/null 2>&1; then
            if [[ -f "$DEPLOYMENT_DIR/docker-compose.yml" ]]; then
                log "DEBUG" "Stopping Docker containers..."
                cd "$DEPLOYMENT_DIR" && docker-compose down --remove-orphans 2>/dev/null || true
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


# Docker installation check
check_docker() {
    log "INFO" "Checking Docker installation..."

    if ! command -v docker >/dev/null 2>&1; then
        error_exit "Docker not found. Please install Docker before running this script."
    fi

    local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log "DEBUG" "Docker version: $docker_version"

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        error_exit "Docker daemon is not running. Please start Docker service before running this script."
    fi

    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        error_exit "Docker Compose not found. Please install Docker Compose before running this script."
    fi

    local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
    log "DEBUG" "Docker Compose version: $compose_version"

    log "INFO" "Docker installation check completed successfully"
}


# Download deployment files
download_deployment_files() {
    log "INFO" "Downloading deployment files..."

    # Create deployment directory
    mkdir -p "$DEPLOYMENT_DIR" || error_exit "Failed to create deployment directory"
    touch "$DEPLOYMENT_DIR/.created_by_script"

    cd "$DEPLOYMENT_DIR" || error_exit "Failed to change to deployment directory"

    # Download files from the repository
    local base_url="https://raw.githubusercontent.com/auricom/ev-stacks/main/stacks/single-sequencer"

    local files=(
        ".env"
        "docker-compose.yml"
        "entrypoint.sequencer.sh"
        "evm-single.Dockerfile"
        "genesis.json"
    )

    for file in "${files[@]}"; do
        log "DEBUG" "Downloading $file..."
        curl -fsSL "$base_url/$file" -o "$file" || error_exit "Failed to download $file"
    done

    # Make entrypoint script executable
    chmod +x entrypoint.sequencer.sh || error_exit "Failed to make entrypoint script executable"

    log "INFO" "Deployment files downloaded successfully"
}

# Configuration management
setup_configuration() {
    log "INFO" "Setting up configuration..."

    # Source configuration template functions
    if [[ -f "$(dirname "$0")/config-template.sh" ]]; then
        source "$(dirname "$0")/config-template.sh"
    else
        log "WARN" "Configuration template script not found, using basic validation"
    fi

    # Check if .env file exists
    if [[ ! -f ".env" ]]; then
        log "WARN" ".env file not found, generating default configuration..."
        if command -v generate_default_config >/dev/null 2>&1; then
            generate_default_config ".env"
        else
            # Fallback basic .env generation
            cat > .env << 'EOF'
DA_RPC_PORT="26658"
DA_AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJwdWJsaWMiLCJyZWFkIiwid3JpdGUiXSwiTm9uY2UiOiJGVVNSbVhVUEFJdXJXekRwNWVOTXBCSWpLdThhWWFwWG9nbS84dUtRZVlZPSIsIkV4cGlyZXNBdCI6IjAwMDEtMDEtMDFUMDA6MDA6MDBaIn0.o3_GsLOPOPUSwHgXBImXKnHnDoqUzd9ebcphwy-VCqo"
EVM_SIGNER_PASSPHRASE="$(openssl rand -base64 32)"
SEQUENCER_PROMETHEUS_PORT="26660"
SEQUENCER_RPC_PORT="7331"
DA_START_HEIGHT="6853148"
PUBLIC_DOMAIN="localhost"
CHAIN_ID="1234"
EOF
        fi
    fi

    # Validate configuration using config-template functions if available
    if command -v validate_required_vars >/dev/null 2>&1; then
        if ! validate_required_vars ".env"; then
            error_exit "Configuration validation failed"
        fi
    else
        # Fallback basic validation
        local required_vars=(
            "DA_RPC_PORT"
            "DA_AUTH_TOKEN"
            "EVM_SIGNER_PASSPHRASE"
            "SEQUENCER_PROMETHEUS_PORT"
            "SEQUENCER_RPC_PORT"
            "DA_START_HEIGHT"
            "PUBLIC_DOMAIN"
            "CHAIN_ID"
        )

        log "DEBUG" "Validating environment variables..."
        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}=" .env; then
                log "WARN" "Required variable $var not found in .env file"
            fi
        done
    fi


    log "INFO" "Configuration setup completed"
}


# Deployment preparation
prepare_deployment() {
    log "INFO" "Preparing deployment files..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Deployment files prepared. Ready to run: docker-compose up -d"
        return 0
    fi

    log "INFO" "Deployment files prepared successfully"
    log "INFO" "To start the services, run: cd $DEPLOYMENT_DIR && docker-compose up -d"
}

# Validate deployment files
validate_deployment_files() {
    log "INFO" "Validating deployment files..."

    local required_files=(
        "docker-compose.yml"
        ".env"
        "genesis.json"
        "entrypoint.sequencer.sh"
        "evm-single.Dockerfile"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error_exit "Required file not found: $file"
        fi
    done

    # Validate Docker Compose file syntax
    if ! docker-compose config >/dev/null 2>&1; then
        error_exit "Invalid Docker Compose configuration"
    fi

    log "INFO" "Deployment files validation completed successfully"
}

# Progress reporting
show_deployment_status() {
    log "INFO" "Deployment Setup Complete"
    echo "=========================="
    echo "Deployment Directory: $DEPLOYMENT_DIR"
    echo ""
    echo "Next Steps:"
    echo "  1. cd $DEPLOYMENT_DIR"
    echo "  2. docker-compose up -d"
    echo ""
    echo "After starting services, endpoints will be available at:"
    echo "  - Reth RPC: http://localhost:8545"
    echo "  - Sequencer RPC: http://localhost:7331"
    echo "  - Prometheus Metrics: http://localhost:26660"
    echo ""
    echo "Service Management:"
    echo "  - View status: docker-compose ps"
    echo "  - View logs: docker-compose logs -f"
    echo "  - Stop services: docker-compose down"
    echo "  - Restart services: docker-compose restart"
    echo ""
    echo "Health Monitoring:"
    echo "  - Check service status: docker-compose ps"
    echo "  - Test endpoints manually using curl"
    echo "  - View service logs: docker-compose logs -f"
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

EXAMPLES:
    # Basic deployment
    $0

    # Verbose deployment with logging
    $0 --verbose --log-file deployment.log

    # Dry run to see what would be done
    $0 --dry-run

    # One-liner remote execution
    curl -fsSL https://raw.githubusercontent.com/auricom/ev-stacks/main/scripts/deploy-rollkit.sh | bash

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
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}

# Main deployment function
main() {
    log "INFO" "Starting Rollkit deployment v$SCRIPT_VERSION"

    # Initialize log file if specified
    if [[ -n "$LOG_FILE" ]]; then
        touch "$LOG_FILE" || error_exit "Failed to create log file: $LOG_FILE"
        log "INFO" "Logging to: $LOG_FILE"
    fi

    # Run deployment steps
    check_docker
    download_deployment_files
    setup_configuration
    validate_deployment_files
    prepare_deployment
    show_deployment_status

    log "INFO" "Rollkit deployment setup completed successfully!"
    log "INFO" "Run 'cd $DEPLOYMENT_DIR && docker-compose up -d' to start your Rollkit sequencer."

    # Disable cleanup on successful exit
    CLEANUP_ON_EXIT=false
}

# Script entry point
# Handle both direct execution and piped execution
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]] || [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    parse_arguments "$@"
    main
fi
