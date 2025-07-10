# Rollkit One-Liner Deployment Framework

This directory contains the core deployment shell script framework for Rollkit sequencer nodes, implementing Task 1 from the deployment roadmap.

## Overview

The framework provides a complete one-liner deployment solution that handles:
- System requirements validation
- Docker and Docker Compose installation
- Configuration management
- Service orchestration
- Health monitoring
- Error handling and cleanup

## Scripts

### 1. `deploy-rollkit.sh` - Main Deployment Script

The primary deployment script that orchestrates the entire deployment process.

**Features:**
- ✅ Docker/Docker Compose availability check
- ✅ Automatic file downloading from repository
- ✅ Configuration validation and setup
- ✅ Deployment file preparation
- ✅ Comprehensive error handling and cleanup
- ✅ Progress reporting and status display

**Usage:**
```bash
# Local execution
./deploy-rollkit.sh

# One-liner remote execution
curl -fsSL https://raw.githubusercontent.com/auricom/ev-stacks/main/scripts/deploy-rollkit.sh | bash

# With options
./deploy-rollkit.sh --verbose --log-file deployment.log

# Dry run
./deploy-rollkit.sh --dry-run
```

**Options:**
- `-h, --help`: Show help message
- `-v, --verbose`: Enable verbose output
- `-d, --dry-run`: Show what would be done without executing
- `-f, --force`: Force installation even if components exist
- `-l, --log-file FILE`: Log output to specified file
- `--no-cleanup`: Don't cleanup on error
- `--deployment-dir DIR`: Use custom deployment directory

### 2. `config-template.sh` - Configuration Management

Handles environment variable validation and configuration file generation.

**Features:**
- ✅ Interactive configuration setup
- ✅ Environment variable validation
- ✅ Secure secret generation (JWT tokens, passphrases)
- ✅ Port availability checking
- ✅ Configuration backup and restore
- ✅ Template processing with variable substitution

**Usage:**
```bash
# Interactive configuration
./config-template.sh interactive

# Validate existing configuration
./config-template.sh validate .env

# Generate JWT secret
./config-template.sh generate-jwt jwt.hex

# Check port availability
./config-template.sh validate-ports .env

# Generate default configuration
./config-template.sh default .env
```

**Functions (when sourced):**
- `validate_required_vars [env_file]`
- `interactive_config [env_file]`
- `generate_jwt_secret [output_file]`
- `generate_secure_passphrase [length]`
- `validate_ports [env_file]`
- `generate_default_config [env_file]`
- `backup_config [env_file]`
- `restore_config backup_file [env_file]`


## System Requirements

### Minimum Requirements
- **OS**: Linux (Ubuntu/Debian recommended)
- **Architecture**: x86_64 or aarch64
- **Memory**: 4GB RAM
- **Storage**: 50GB available disk space
- **CPU**: 2 cores minimum

### Software Dependencies
- Docker (must be pre-installed)
- Docker Compose (must be pre-installed)
- curl (for downloading files)
- openssl (for generating secrets)

## Deployment Process

The deployment follows these steps:

1. **Dependency Check**
   - Verify Docker is installed and running
   - Verify Docker Compose is available

2. **File Download**
   - Download Docker Compose configuration
   - Download service configurations
   - Download genesis block configuration
   - Set appropriate permissions

3. **Configuration Setup**
   - Validate environment variables
   - Generate JWT secrets
   - Setup service configurations

4. **Deployment Preparation**
   - Validate Docker Compose configuration
   - Prepare all deployment files
   - Display next steps for manual service startup

**Note**: The script prepares everything for deployment but does not automatically start services. After the script completes, you need to manually run `docker-compose up -d` to start the services.

## Configuration

### Environment Variables

The deployment uses the following environment variables:

```bash
# Chain Configuration
CHAIN_ID="1234"
PUBLIC_DOMAIN="localhost"

# DA Layer Configuration
DA_RPC_PORT="26658"
DA_AUTH_TOKEN="<jwt-token>"
DA_START_HEIGHT="6853148"

# EVM Configuration
EVM_SIGNER_PASSPHRASE="<secure-passphrase>"

# Sequencer Configuration
SEQUENCER_RPC_PORT="7331"
SEQUENCER_PROMETHEUS_PORT="26660"
```

### Service Endpoints

After deployment, the following endpoints are available:

- **Reth RPC**: `http://localhost:8545`
- **Sequencer RPC**: `http://localhost:7331`
- **Sequencer Health**: `http://localhost:7331/health/live`
- **HAProxy Stats**: `http://localhost:8404`
- **Prometheus Metrics**: `http://localhost:26660/metrics`

## Error Handling

The framework includes comprehensive error handling:

- **Automatic Cleanup**: Failed deployments are automatically cleaned up
- **Signal Handling**: Graceful handling of interruption signals
- **Rollback Capability**: Services can be stopped and removed on failure
- **Detailed Logging**: All operations are logged with timestamps
- **Exit Codes**: Proper exit codes for automation integration

## Security Features

- **Secure Secret Generation**: Cryptographically secure JWT tokens and passphrases
- **File Permissions**: Proper file permissions for sensitive files
- **Input Validation**: All user inputs are validated
- **Container Isolation**: Services run in isolated Docker containers

## Monitoring and Maintenance

### Health Monitoring
```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs -f

# Test endpoints manually
curl http://localhost:8545
curl http://localhost:7331/health/live
```

### Service Management
```bash
# View service status
docker-compose ps

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update services
docker-compose pull && docker-compose up -d
```

### Troubleshooting

Common issues and solutions:

1. **Port Conflicts**
   ```bash
   # Check port usage
   ./config-template.sh validate-ports

   # Modify ports in .env file
   nano .env
   ```

2. **Service Startup Issues**
   ```bash
   # Check service logs
   docker-compose logs <service-name>

   # Restart specific service
   docker-compose restart <service-name>
   ```

3. **Network Connectivity**
   ```bash
   # Test RPC endpoints
   curl -X POST -H "Content-Type: application/json" \
     --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     http://localhost:8545

   # Check container networking
   docker network ls
   ```

## Integration with Existing Infrastructure

This framework is designed to integrate with the existing Ansible-based infrastructure:

- **File Compatibility**: Uses the same Docker Compose and configuration files
- **Service Definitions**: Compatible with existing service definitions
- **Network Configuration**: Maintains existing network topology
- **Volume Management**: Preserves data persistence patterns

## Future Extensions

The framework is designed to support future enhancements:

- **Module System**: Pluggable modules for additional services
- **Configuration Templates**: Support for different deployment scenarios
- **Monitoring Integration**: Integration with Prometheus and Grafana
- **Backup and Recovery**: Automated backup and recovery procedures
- **Multi-Node Support**: Support for multi-node deployments

## Testing

### Unit Testing
Each function can be tested independently:

```bash
# Test Docker availability
source deploy-rollkit.sh && check_docker

# Test configuration validation
source config-template.sh && validate_required_vars .env

# Test deployment file validation
source deploy-rollkit.sh && validate_deployment_files
```

### Integration Testing
```bash
# Dry run deployment
./deploy-rollkit.sh --dry-run

# Test in clean environment
docker system prune -af && ./deploy-rollkit.sh
```

## Contributing

When contributing to this framework:

1. **Follow Shell Best Practices**: Use `set -euo pipefail`, proper quoting, and error handling
2. **Maintain Compatibility**: Ensure changes work with existing infrastructure
3. **Add Tests**: Include tests for new functionality
4. **Update Documentation**: Keep this README updated with changes
5. **Use Consistent Logging**: Follow the established logging patterns

## License

This deployment framework is part of the 01builders infrastructure project and follows the same licensing terms.
