#!/bin/bash

# Configuration Template System for Rollkit Deployment
# This script handles environment variable validation and configuration file generation

set -euo pipefail

# Configuration validation functions
validate_required_vars() {
    local env_file="${1:-.env}"
    local missing_vars=()

    # Required environment variables
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

    echo "Validating required environment variables..."

    for var in "${required_vars[@]}"; do
        if [[ -f "$env_file" ]]; then
            if ! grep -q "^${var}=" "$env_file"; then
                missing_vars+=("$var")
            fi
        else
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "ERROR: Missing required environment variables:"
        printf "  - %s\n" "${missing_vars[@]}"
        return 1
    fi

    echo "All required environment variables are present"
    return 0
}

# Interactive configuration setup
interactive_config() {
    local env_file="${1:-.env}"

    echo "Setting up Rollkit configuration interactively..."
    echo "Press Enter to use default values shown in [brackets]"
    echo ""

    # Chain configuration
    read -p "Chain ID [1234]: " chain_id
    chain_id=${chain_id:-1234}

    read -p "Public domain [localhost]: " public_domain
    public_domain=${public_domain:-localhost}

    # DA configuration
    read -p "DA RPC Port [26658]: " da_rpc_port
    da_rpc_port=${da_rpc_port:-26658}

    read -p "DA Start Height [6853148]: " da_start_height
    da_start_height=${da_start_height:-6853148}

    # Generate secure passphrase if not provided
    read -s -p "EVM Signer Passphrase (leave empty to generate): " evm_passphrase
    echo ""
    if [[ -z "$evm_passphrase" ]]; then
        evm_passphrase=$(openssl rand -base64 32)
        echo "Generated secure passphrase"
    fi

    # Generate DA auth token if not provided
    read -p "DA Auth Token (leave empty to use default): " da_auth_token
    if [[ -z "$da_auth_token" ]]; then
        da_auth_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJwdWJsaWMiLCJyZWFkIiwid3JpdGUiXSwiTm9uY2UiOiJGVVNSbVhVUEFJdXJXekRwNWVOTXBCSWpLdThhWWFwWG9nbS84dUtRZVlZPSIsIkV4cGlyZXNBdCI6IjAwMDEtMDEtMDFUMDA6MDA6MDBaIn0.o3_GsLOPOPUSwHgXBImXKnHnDoqUzd9ebcphwy-VCqo"
    fi

    # Sequencer configuration
    read -p "Sequencer RPC Port [7331]: " sequencer_rpc_port
    sequencer_rpc_port=${sequencer_rpc_port:-7331}

    read -p "Sequencer Prometheus Port [26660]: " sequencer_prometheus_port
    sequencer_prometheus_port=${sequencer_prometheus_port:-26660}

    # Generate .env file
    cat > "$env_file" << EOF
# Rollkit Configuration
# Generated on $(date)

# Chain Configuration
CHAIN_ID="$chain_id"
PUBLIC_DOMAIN="$public_domain"

# DA Layer Configuration
DA_RPC_PORT="$da_rpc_port"
DA_AUTH_TOKEN="$da_auth_token"
DA_START_HEIGHT="$da_start_height"

# EVM Configuration
EVM_SIGNER_PASSPHRASE="$evm_passphrase"

# Sequencer Configuration
SEQUENCER_RPC_PORT="$sequencer_rpc_port"
SEQUENCER_PROMETHEUS_PORT="$sequencer_prometheus_port"
EOF

    echo "Configuration saved to $env_file"
}

# Generate configuration from template
generate_config_from_template() {
    local template_file="$1"
    local output_file="$2"
    local env_file="${3:-.env}"

    if [[ ! -f "$template_file" ]]; then
        echo "ERROR: Template file not found: $template_file"
        return 1
    fi

    if [[ ! -f "$env_file" ]]; then
        echo "ERROR: Environment file not found: $env_file"
        return 1
    fi

    echo "Generating configuration from template..."

    # Source environment variables
    set -a
    source "$env_file"
    set +a

    # Process template with environment variable substitution
    envsubst < "$template_file" > "$output_file"

    echo "Configuration generated: $output_file"
}

# Secret management functions
generate_jwt_secret() {
    local output_file="${1:-jwt.hex}"

    echo "Generating JWT secret..."
    openssl rand -hex 32 | tr -d '\n' > "$output_file"
    chmod 600 "$output_file"
    echo "JWT secret generated: $output_file"
}

generate_secure_passphrase() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d '\n'
}

# Configuration validation
validate_ports() {
    local env_file="${1:-.env}"

    if [[ ! -f "$env_file" ]]; then
        echo "ERROR: Environment file not found: $env_file"
        return 1
    fi

    # Source environment variables
    set -a
    source "$env_file"
    set +a

    local ports=(
        "$DA_RPC_PORT"
        "$SEQUENCER_PROMETHEUS_PORT"
        "$SEQUENCER_RPC_PORT"
    )

    echo "Validating port availability..."

    for port in "${ports[@]}"; do
        if [[ -n "$port" ]]; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                echo "WARNING: Port $port is already in use"
            else
                echo "Port $port is available"
            fi
        fi
    done
}

# Default configuration generation
generate_default_config() {
    local env_file="${1:-.env}"

    echo "Generating default configuration..."

    # Generate secure values
    local jwt_secret=$(openssl rand -hex 32)
    local evm_passphrase=$(generate_secure_passphrase)

    cat > "$env_file" << EOF
# Rollkit Default Configuration
# Generated on $(date)

# Chain Configuration
CHAIN_ID="1234"
PUBLIC_DOMAIN="localhost"

# DA Layer Configuration
DA_RPC_PORT="26658"
DA_AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJwdWJsaWMiLCJyZWFkIiwid3JpdGUiXSwiTm9uY2UiOiJGVVNSbVhVUEFJdXJXekRwNWVOTXBCSWpLdThhWWFwWG9nbS84dUtRZVlZPSIsIkV4cGlyZXNBdCI6IjAwMDEtMDEtMDFUMDA6MDA6MDBaIn0.o3_GsLOPOPUSwHgXBImXKnHnDoqUzd9ebcphwy-VCqo"
DA_START_HEIGHT="6853148"

# EVM Configuration
EVM_SIGNER_PASSPHRASE="$evm_passphrase"

# Sequencer Configuration
SEQUENCER_RPC_PORT="7331"
SEQUENCER_PROMETHEUS_PORT="26660"

# Generated Secrets
JWT_SECRET="$jwt_secret"
EOF

    echo "Default configuration saved to $env_file"
}

# Configuration backup and restore
backup_config() {
    local env_file="${1:-.env}"
    local backup_file="${env_file}.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$env_file" ]]; then
        cp "$env_file" "$backup_file"
        echo "Configuration backed up to: $backup_file"
    else
        echo "No configuration file to backup"
    fi
}

restore_config() {
    local backup_file="$1"
    local env_file="${2:-.env}"

    if [[ ! -f "$backup_file" ]]; then
        echo "ERROR: Backup file not found: $backup_file"
        return 1
    fi

    cp "$backup_file" "$env_file"
    echo "Configuration restored from: $backup_file"
}

# Usage information
show_config_usage() {
    cat << EOF
Configuration Template System for Rollkit Deployment

USAGE:
    source config-template.sh

FUNCTIONS:
    validate_required_vars [env_file]           - Validate required environment variables
    interactive_config [env_file]               - Interactive configuration setup
    generate_config_from_template template output [env_file] - Generate config from template
    generate_jwt_secret [output_file]           - Generate JWT secret
    generate_secure_passphrase [length]         - Generate secure passphrase
    validate_ports [env_file]                   - Check port availability
    generate_default_config [env_file]          - Generate default configuration
    backup_config [env_file]                    - Backup configuration
    restore_config backup_file [env_file]       - Restore configuration

EXAMPLES:
    # Interactive setup
    interactive_config

    # Validate configuration
    validate_required_vars .env

    # Generate JWT secret
    generate_jwt_secret jwt.hex

    # Check port availability
    validate_ports .env

EOF
}

# Main function for standalone execution
main() {
    case "${1:-help}" in
        "validate")
            validate_required_vars "${2:-.env}"
            ;;
        "interactive")
            interactive_config "${2:-.env}"
            ;;
        "generate-template")
            generate_config_from_template "$2" "$3" "${4:-.env}"
            ;;
        "generate-jwt")
            generate_jwt_secret "${2:-jwt.hex}"
            ;;
        "generate-passphrase")
            generate_secure_passphrase "${2:-32}"
            ;;
        "validate-ports")
            validate_ports "${2:-.env}"
            ;;
        "default")
            generate_default_config "${2:-.env}"
            ;;
        "backup")
            backup_config "${2:-.env}"
            ;;
        "restore")
            restore_config "$2" "${3:-.env}"
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
