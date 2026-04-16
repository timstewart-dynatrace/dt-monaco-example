#!/bin/bash

set -euo pipefail

# Color output for messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Trap errors and perform cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Error: Script failed with exit code $exit_code${NC}"
        echo -e "${YELLOW}Cleaning up temporary files...${NC}"
        rm -f monaco "monaco-"* monaco_checksum manifest.yaml
    fi
    exit $exit_code
}
trap cleanup EXIT

# Check for required dependencies
for cmd in curl jq grep awk; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: Required command '$cmd' not found. Please install it.${NC}"
        exit 1
    fi
done

# Check if the tenant ID is provided as an argument
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <tenantId> [environment-url-base]"
    echo "  tenantId: Dynatrace tenant ID"
    echo "  environment-url-base: Optional. Base URL (default: live.dynatrace.com)"
    exit 1
fi

# Check if the environment variable ENV_TOKEN is set
if [ -z "${ENV_TOKEN:+x}" ]; then
    echo -e "${RED}Error: ENV_TOKEN environment variable is not set.${NC}"
    exit 1
fi

# Set the tenant ID and environment
tenantId="$1"
environment_url_base="${2:-live.dynatrace.com}"
tenantUrl="https://${tenantId}.${environment_url_base}"

# Set the platform architecture based on the system
if [ "$(uname)" == "Darwin" ]; then
    if [ "$(uname -m)" == "x86_64" ]; then
        platform="darwin-amd64"
    elif [ "$(uname -m)" == "arm64" ]; then
        platform="darwin-arm64"
    else
        echo "Error: Unsupported architecture for macOS."
        exit 1
    fi
elif [ "$(uname)" == "Linux" ]; then
    if [ "$(uname -m)" == "x86_64" ]; then
        platform="linux-amd64"
    elif [ "$(uname -m)" == "i386" ]; then
        platform="linux-386"
    else
        echo "Error: Unsupported architecture for Linux."
        exit 1
    fi
else
    echo "Error: Unsupported operating system."
    exit 1
fi

# URLs for downloading Monaco and its checksum
MONACO_VERSION="2.12.0"
binary_url="https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/download/v${MONACO_VERSION}/monaco-${platform}"
checksum_url="${binary_url}.sha256"

# Download Monaco binary and its checksum
echo -e "${GREEN}Downloading Monaco v${MONACO_VERSION} binary...${NC}"
if ! curl -L -f -o "monaco-${platform}" "${binary_url}"; then
    echo -e "${RED}Error: Failed to download Monaco binary from ${binary_url}${NC}"
    exit 1
fi

if ! curl -L -f -o monaco_checksum "${checksum_url}"; then
    echo -e "${RED}Error: Failed to download checksum from ${checksum_url}${NC}"
    exit 1
fi

# Verify the checksum
echo -e "${GREEN}Verifying checksum...${NC}"

if command -v sha256sum &> /dev/null; then
    # Linux
    if ! sha256sum -c monaco_checksum --status; then
        echo -e "${RED}Error: Checksum verification failed.${NC}"
        exit 1
    fi
elif command -v shasum &> /dev/null; then
    # macOS
    if ! shasum -a 256 -c monaco_checksum --strict &> /dev/null; then
        echo -e "${RED}Error: Checksum verification failed.${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: No checksum utility available (sha256sum or shasum).${NC}"
    exit 1
fi

echo -e "${GREEN}Checksum verified.${NC}"

# Rename the binary to "monaco" and make it executable
mv "monaco-${platform}" monaco
chmod +x monaco

# Generate Environment token
echo -e "${GREEN}Generating Monaco API token...${NC}"
token_response=$(curl -s -X POST "${tenantUrl}/api/v2/apiTokens" \
  -H "accept: application/json; charset=utf-8" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Authorization: Api-Token ${ENV_TOKEN}" \
  -d '{"name":"rs-monaco-test","scopes":["attacks.read","entities.read","extensionConfigurations.read","extensionEnvironment.read","extensions.read","geographicRegions.read","javaScriptMappingFiles.read","networkZones.read","settings.read","slo.read","syntheticExecutions.read","syntheticLocations.read","DataExport","DssFileManagement","ExternalSyntheticIntegration","ReadConfig","ReadSyntheticData","RumJavaScriptTagManagement"]}')

export MONACO_TOKEN=$(echo "${token_response}" | jq -r '.token // empty')
MONACO_TOKEN_ID=$(echo "${token_response}" | jq -r '.id // empty')

if [ -z "${MONACO_TOKEN}" ]; then
    echo -e "${RED}Error: Failed to generate Monaco API token.${NC}"
    echo -e "${YELLOW}Response: ${token_response}${NC}"
    exit 1
fi

echo -e "${GREEN}Monaco token generated successfully.${NC}"

# Create the manifest.yaml file
cat > manifest.yaml <<EOF
manifestVersion: 1.0

projects:
- name: saas
  path: saas/${tenantId}

environmentGroups:
- name: saas
  environments:
  - name: ${tenantId}
    url:
      value: ${tenantUrl}
    auth:
      token:
        name: MONACO_TOKEN
EOF

# Run Monaco binary to download configurations
echo -e "${GREEN}Running Monaco to download configurations...${NC}"
./monaco download --environment "${tenantId}" --output-folder "${tenantId}"

datetime=$(date +"%Y-%m-%d_%H-%M-%S")
directory_name="configurationExport-${datetime}"
mkdir -p "${directory_name}"

# Create SaaS Upgrade Assistant metadata file
current_timestamp=$(( $(date +%s) * 1000 ))

cat > exportMetadata.json <<EOF
{
  "clusterUuid": "${tenantId}",
  "productVersion": "1.288.0.20240229-161733",
  "monacoVersion": "${MONACO_VERSION}",
  "exportTimestamp": "${current_timestamp}",
  "environments": [
    {
      "name": "${tenantId}",
      "uuid": "${tenantId}"
    }
  ]
}
EOF

mv exportMetadata.json "${directory_name}/exportMetadata.json"
mkdir -p "${directory_name}/export"
mv "${tenantId}"/* "${directory_name}/export/"

# Archive the output in saas directory into tar.gz
echo -e "${GREEN}Archiving saas directory...${NC}"
# Get the base name of the source directory
base_name="$(basename "${directory_name}")"

tar -czf "${directory_name}.tar.gz" -C "$(dirname "${directory_name}")" "${base_name}"
echo -e "${GREEN}Archive created: ${directory_name}.tar.gz${NC}"

# Revoke the generated Monaco API token
if [ -n "${MONACO_TOKEN_ID:-}" ]; then
    echo -e "${GREEN}Revoking generated Monaco API token...${NC}"
    curl -s -X DELETE "${tenantUrl}/api/v2/apiTokens/${MONACO_TOKEN_ID}" \
        -H "Authorization: Api-Token ${ENV_TOKEN}" > /dev/null 2>&1 \
        && echo -e "${GREEN}Token revoked successfully.${NC}" \
        || echo -e "${YELLOW}Warning: Failed to revoke token. Delete manually in Dynatrace UI.${NC}"
fi

# Clean up temporary files
echo -e "${GREEN}Cleaning up temporary files...${NC}"
rm -f monaco monaco_checksum manifest.yaml
rm -rf "${tenantId}"

echo -e "${GREEN}Export completed successfully!${NC}"
