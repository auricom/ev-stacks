#!/bin/bash

# Configuration Template System for Rollkit Deployment
# This script handles basic environment file validation

set -euo pipefail

# Simple configuration validation - just check if .env file exists and is readable
validate_required_vars() {
    local env_file="${1:-.env}"

    echo "Validating environment configuration..."

    if [[ ! -f "$env_file" ]]; then
        echo "ERROR: Environment file not found: $env_file"
        return 1
    fi

    if [[ ! -r "$env_file" ]]; then
        echo "ERROR: Environment file is not readable: $env_file"
        return 1
    fi

    echo "Environment file validation completed successfully"
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
