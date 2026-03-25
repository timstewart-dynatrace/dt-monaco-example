#!/bin/bash
#
# Clone and prepare Monaco configuration from source tenant
# This helper script downloads configuration and prepares it for deployment
#
# Usage:
#   ./clone-config.sh source-url source-token [config-types]
#

set -o errexit
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Validate arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source-url> <source-token> [config-types]"
    echo ""
    echo "Examples:"
    echo "  $0 https://tenant.live.dynatrace.com token_xyz"
    echo "  $0 https://tenant.live.dynatrace.com token_xyz dashboard,alerting-profiles"
    exit 1
fi

SOURCE_URL="${1%/}"  # Remove trailing slash
SOURCE_TOKEN="$2"
CONFIG_TYPES="${3:-}"

OUTPUT_DIR="config/cloned-$(date +%Y%m%d-%H%M%S)"

log_info "Cloning configuration from $SOURCE_URL"
log_info "Output directory: $OUTPUT_DIR"

# Create environments config
mkdir -p "$OUTPUT_DIR"
cat > "$OUTPUT_DIR/environments.yaml" << EOF
environments:
  source:
    name: source
    url: $SOURCE_URL
    token: $SOURCE_TOKEN
EOF

# Build monaco command
CMD="monaco download"
CMD="$CMD --environment source"
CMD="$CMD --config-file $OUTPUT_DIR/environments.yaml"
CMD="$CMD --output-folder $OUTPUT_DIR"

if [[ -n "$CONFIG_TYPES" ]]; then
    for type in $(echo "$CONFIG_TYPES" | tr ',' ' '); do
        CMD="$CMD --config-type $type"
    done
fi

log_info "Running: $CMD"

if eval "$CMD"; then
    log_success "Configuration cloned successfully"
    log_info "Location: $(pwd)/$OUTPUT_DIR"
    echo ""
    echo "Next steps:"
    echo "1. Review the configuration: ls -la $OUTPUT_DIR"
    echo "2. Customize as needed"
    echo "3. Deploy with: monaco deploy --environment target --config-file $OUTPUT_DIR/environments.yaml $OUTPUT_DIR"
else
    log_error "Failed to clone configuration"
    exit 1
fi
