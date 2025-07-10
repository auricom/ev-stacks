#!/bin/bash

# Configuration Template System for Rollkit Deployment
# This script handles basic environment file validation

set -euo pipefail

# Configuration validation and setup
validate_required_vars() {
    local env_file="${1:-.env}"

    echo "Validating and setting up environment configuration..."

    if [[ ! -f "$env_file" ]]; then
        echo "ERROR: Environment file not found: $env_file"
        return 1
    fi

    if [[ ! -r "$env_file" ]]; then
        echo "ERROR: Environment file is not readable: $env_file"
        return 1
    fi

    # Check for missing EVM_SIGNER_PASSPHRASE and generate if empty
    if grep -q "^EVM_SIGNER_PASSPHRASE=$" "$env_file" || ! grep -q "^EVM_SIGNER_PASSPHRASE=" "$env_file"; then
        echo "Generating random EVM signer passphrase..."
        local passphrase=$(openssl rand -base64 32 | tr -d '\n')
        sed -i "s/^EVM_SIGNER_PASSPHRASE=.*/EVM_SIGNER_PASSPHRASE=\"$passphrase\"/" "$env_file"
        echo "EVM signer passphrase generated and set"
    fi

    # Check for missing CHAIN_ID and prompt user
    if grep -q "^CHAIN_ID=$" "$env_file" || ! grep -q "^CHAIN_ID=" "$env_file"; then
        echo "Chain ID is required for the deployment."
        echo "Please enter a chain ID (e.g., 1234 for development, or your custom chain ID):"
        read -r chain_id

        # Validate chain ID is numeric
        if ! [[ "$chain_id" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Chain ID must be a number"
            return 1
        fi

        sed -i "s/^CHAIN_ID=.*/CHAIN_ID=\"$chain_id\"/" "$env_file"
        echo "Chain ID set to: $chain_id"
    fi

    echo "Environment file validation and setup completed successfully"
    return 0
}

# Usage information
show_config_usage() {
    cat << EOF
Configuration Template System for Rollkit Deployment

USAGE:
    source config-template.sh

FUNCTIONS:
    validate_required_vars [env_file]           - Validate environment file exists and is readable

EXAMPLES:
    # Validate configuration
    validate_required_vars .env

EOF
}

# Main function for standalone execution
main() {
    case "${1:-help}" in
        "validate")
            validate_required_vars "${2:-.env}"
            ;;
        "help"|*)
            show_config_usage
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
