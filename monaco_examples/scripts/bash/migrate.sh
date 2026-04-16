#!/bin/bash
#
# Dynatrace Monaco Configuration Migration Script
#
# This script clones and migrates Dynatrace configuration from a source tenant
# to a target tenant using Monaco.
#
# Usage:
#   ./migrate.sh [OPTIONS]
#
# Examples:
#   # Using environment variables
#   export SOURCE_TENANT_URL="https://source.live.dynatrace.com"
#   export SOURCE_TENANT_TOKEN="your_token"
#   ./migrate.sh
#
#   # Using command-line arguments
#   ./migrate.sh \
#     --source-url https://source.live.dynatrace.com \
#     --target-url https://target.live.dynatrace.com \
#     --source-token YOUR_TOKEN \
#     --target-token YOUR_TOKEN
#
#   # Dry run
#   ./migrate.sh --dry-run
#

set -o errexit  # Exit on error
set -o pipefail # Exit on pipe failure
set -o nounset  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
CONFIG_DIR="config"
BACKUP_DIR=""

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

#
# Print help message
#
print_help() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    --source-url URL            Source Dynatrace tenant URL
    --target-url URL            Target Dynatrace tenant URL
    --source-token TOKEN        API token for source tenant
    --target-token TOKEN        API token for target tenant
    --config-dir DIR            Configuration directory (default: config)
    --dry-run                   Preview changes without applying
    --config-types TYPES        Comma-separated config types to migrate
    --no-backup                 Skip backup of target configuration
    --list-types                List all available configuration types
    --help                      Show this help message

ENVIRONMENT VARIABLES:
    SOURCE_TENANT_URL           Source Dynatrace tenant URL
    SOURCE_TENANT_TOKEN         API token for source tenant
    TARGET_TENANT_URL           Target Dynatrace tenant URL
    TARGET_TENANT_TOKEN         API token for target tenant

EXAMPLES:
    # Using environment variables
    source .env
    $0

    # Using arguments
    $0 \\
      --source-url https://source.live.dynatrace.com \\
      --target-url https://target.live.dynatrace.com \\
      --source-token YOUR_TOKEN \\
      --target-token YOUR_TOKEN

    # Dry run
    $0 --dry-run

EOF
    exit 0
}

#
# List available configuration types
#
list_config_types() {
    cat << EOF

Available Configuration Types:

Type                                        Description
────────────────────────────────────────────────────────────────────────────────
alert-profiles                              Alert notification rules
app-detection-rule                          Application detection rules
auto-tag                                    Auto-tagging rules
calculated-metrics-log                      Calculated metrics for logs
calculated-metrics-service                  Calculated metrics for services
calculated-synthetic-events                 Calculated synthetic events
credential                                  Stored credentials
custom-app-configs                          Custom app configurations
custom-app-crashes-allowlist                Custom app crash allowlists
dashboard                                   Gen3 dashboards
extension                                   Extensions
host-monitoring-advanced-configuration      Host monitoring advanced config
kubernetes-app                              Kubernetes app monitoring
log-custom-source                           Custom log sources
log-events-to-metric-v2                     Log event to metric rules
log-processing-rule                         Log processing rules
management-zone                             Management zones
notification                                Notification configurations
request-naming                              Request naming rules
service-detection-rule                      Service detection rules
settings                                    Settings (various)
synthetic-location                          Synthetic test locations
synthetic-monitor                           Synthetic monitors

EOF
}

#
# Parse command-line arguments
#
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source-url)
                SOURCE_TENANT_URL="$2"
                shift 2
                ;;
            --target-url)
                TARGET_TENANT_URL="$2"
                shift 2
                ;;
            --source-token)
                SOURCE_TENANT_TOKEN="$2"
                shift 2
                ;;
            --target-token)
                TARGET_TENANT_TOKEN="$2"
                shift 2
                ;;
            --config-dir)
                CONFIG_DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --config-types)
                CONFIG_TYPES="$2"
                shift 2
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            --list-types)
                list_config_types
                exit 0
                ;;
            --help)
                print_help
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                ;;
        esac
    done
}

#
# Verify Monaco is installed and accessible
#
verify_monaco_installed() {
    log_info "Checking Monaco installation..."

    if ! command -v monaco &> /dev/null; then
        log_error "Monaco CLI not found"
        log_error "Please install Monaco first:"
        log_error "  - Download from: https://github.com/Dynatrace/dynatrace-configuration-as-code/releases"
        log_error "  - Add to PATH: export PATH=\"\$PATH:\$HOME/tools/monaco\""
        return 1
    fi

    local monaco_version
    monaco_version=$(monaco --version 2>&1 || echo "unknown")
    log_success "Monaco found: $monaco_version"
    return 0
}

#
# Verify connection to a Dynatrace tenant
#
verify_tenant_connection() {
    local url=$1
    local token=$2
    local name=$3

    log_info "Verifying connection to $name tenant..."

    if ! command -v curl &> /dev/null; then
        log_warning "curl not found, skipping connection verification"
        return 0
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Api-Token $token" \
        "$url/api/v2/environments" 2>&1 || true)

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" == "200" ]]; then
        log_success "✓ $name tenant connection verified"
        return 0
    else
        log_error "✗ $name tenant returned HTTP $http_code"
        return 1
    fi
}

#
# Create environments.yaml configuration file
#
create_environments_yaml() {
    log_info "Creating environments.yaml..."

    mkdir -p "$CONFIG_DIR"

    cat > "$CONFIG_DIR/environments.yaml" << EOF
environments:
  source:
    name: source
    url: $SOURCE_TENANT_URL
    token: $SOURCE_TENANT_TOKEN
  
  target:
    name: target
    url: $TARGET_TENANT_URL
    token: $TARGET_TENANT_TOKEN
EOF

    log_success "Created: $CONFIG_DIR/environments.yaml"
}

#
# Download configuration from tenant
#
download_configuration() {
    local environment=$1
    local target_dir=$2

    log_info "Downloading configuration from $environment environment..."

    mkdir -p "$target_dir"

    local cmd=("monaco" "download"
        "--environment" "$environment"
        "--config-file" "$CONFIG_DIR/environments.yaml"
        "--output-folder" "$target_dir")

    if [[ -n "${CONFIG_TYPES:-}" ]]; then
        for config_type in $(echo "$CONFIG_TYPES" | tr ',' ' '); do
            cmd+=("--config-type" "$config_type")
        done
    fi

    log_info "Running: ${cmd[*]}"

    if "${cmd[@]}"; then
        log_success "✓ Configuration downloaded from $environment"
        return 0
    else
        log_error "✗ Error downloading configuration from $environment"
        return 1
    fi
}

#
# Validate YAML configuration files
#
validate_configuration() {
    local config_dir=$1

    log_info "Validating configuration files..."

    if ! command -v python3 &> /dev/null; then
        log_warning "Python3 not found, skipping YAML validation"
        return 0
    fi

    local yaml_files
    yaml_files=$(find "$config_dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null || true)

    if [[ -z "$yaml_files" ]]; then
        log_warning "No configuration files found in $config_dir"
        return 0
    fi

    while IFS= read -r yaml_file; do
        if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
            log_info "  ✓ Valid: $(basename "$yaml_file")"
        else
            log_error "  ✗ Invalid YAML: $yaml_file"
            return 1
        fi
    done << EOF
$yaml_files
EOF

    log_success "✓ Configuration validation passed"
    return 0
}

#
# Deploy configuration to tenant
#
deploy_configuration() {
    local config_dir=$1
    local environment=$2

    log_info "Deploying configuration to $environment environment..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Configuration would be deployed (not actually deploying)"
        return 0
    fi

    local cmd=("monaco" "deploy"
        "--environment" "$environment"
        "--config-file" "$CONFIG_DIR/environments.yaml"
        "$config_dir")

    log_info "Running: ${cmd[*]}"

    if "${cmd[@]}"; then
        log_success "✓ Configuration deployed to $environment"
        return 0
    else
        log_error "✗ Error deploying configuration to $environment"
        return 1
    fi
}

#
# Backup target configuration
#
backup_configuration() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$CONFIG_DIR/backups/$timestamp"

    log_info "Creating backup of target configuration..."

    mkdir -p "$BACKUP_DIR"

    if download_configuration "target" "$BACKUP_DIR"; then
        log_success "✓ Backup created at: $BACKUP_DIR"
        return 0
    else
        log_warning "Failed to create backup (continuing with migration)"
        return 0
    fi
}

#
# Main migration process
#
main() {
    log_info "========================================="
    log_info "Dynatrace Configuration Migration"
    log_info "========================================="

    # Load environment variables if .env exists
    if [[ -f ".env" ]]; then
        log_info "Loading environment variables from .env"
        set -a
        # shellcheck source=/dev/null
        source .env
        set +a
    fi

    # Parse command-line arguments
    parse_arguments "$@"

    # Validate required variables
    if [[ -z "${SOURCE_TENANT_URL:-}" ]] || \
       [[ -z "${TARGET_TENANT_URL:-}" ]] || \
       [[ -z "${SOURCE_TENANT_TOKEN:-}" ]] || \
       [[ -z "${TARGET_TENANT_TOKEN:-}" ]]; then
        log_error "Missing required environment variables or arguments"
        log_error "Set: SOURCE_TENANT_URL, TARGET_TENANT_URL, SOURCE_TENANT_TOKEN, TARGET_TENANT_TOKEN"
        print_help
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "[DRY RUN MODE] No changes will be applied"
    fi

    # Step 1: Verify Monaco installation
    if ! verify_monaco_installed; then
        return 1
    fi

    # Step 2: Create environments configuration
    create_environments_yaml

    # Step 3: Verify API connections
    if ! verify_tenant_connection "$SOURCE_TENANT_URL" "$SOURCE_TENANT_TOKEN" "source"; then
        return 1
    fi

    if ! verify_tenant_connection "$TARGET_TENANT_URL" "$TARGET_TENANT_TOKEN" "target"; then
        return 1
    fi

    log_success "✓ API connections verified"

    # Step 4: Backup target configuration
    if [[ "${NO_BACKUP:-false}" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        if ! backup_configuration; then
            return 1
        fi
    fi

    # Step 5: Download source configuration
    local source_config_dir="$CONFIG_DIR/source"
    if ! download_configuration "source" "$source_config_dir"; then
        return 1
    fi

    # Step 6: Validate configuration
    if ! validate_configuration "$source_config_dir"; then
        log_error "Configuration validation failed"
        return 1
    fi

    # Step 7: Deploy to target
    if ! deploy_configuration "$source_config_dir" "target"; then
        return 1
    fi

    log_info "========================================="
    log_success "✓ Migration completed successfully!"
    log_info "========================================="
    return 0
}

# Run main function
main "$@"
