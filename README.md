# Dynatrace Monaco Configuration Migration

This project provides Python and Shell Script tools for cloning and migrating Dynatrace configuration between tenants using Monaco.

## Overview

Monaco is a configuration-as-code tool for Dynatrace that allows you to manage your configuration in version control and migrate it between environments.

## Prerequisites

- **Java 11+** (required for Monaco)
- **Git**
- **Python 3.8+** (for Python scripts)
- Dynatrace tenant(s) with API access
- API tokens for both source and target tenants

## Installation

### 1. Install Java

Monaco requires Java 11 or higher. Check your current version:

```bash
java -version
```

If you need to install Java on macOS:

```bash
brew install java
```

### 2. Install Monaco

Download the latest Monaco release:

```bash
# Create a directory for Monaco
mkdir -p ~/tools/monaco
cd ~/tools/monaco

# Download the latest release (check https://github.com/dynatrace-oss/dynatrace-monitoring-as-code/releases)
curl -L https://github.com/dynatrace-oss/dynatrace-monitoring-as-code/releases/download/v1.9.0/monaco-v1.9.0-macos-arm64 -o monaco
chmod +x monaco

# Add to PATH
export PATH="$PATH:$HOME/tools/monaco"
```

### 3. Set Up Environment Variables

Create a `.env` file in the project root:

```bash
# Source tenant
SOURCE_TENANT_URL=https://your-source-tenant.live.dynatrace.com
SOURCE_TENANT_TOKEN=your-source-api-token

# Target tenant
TARGET_TENANT_URL=https://your-target-tenant.live.dynatrace.com
TARGET_TENANT_TOKEN=your-target-api-token
```

## Project Structure

```
.
├── README.md                      # This file
├── .env                           # Environment variables (create this)
├── config/                        # Monaco configuration files
│   ├── environments.yaml          # Environment definitions
│   └── tenants/                   # Tenant-specific configs
├── scripts/
│   ├── migrate.py                 # Python migration script
│   ├── migrate.sh                 # Shell script migration
│   └── clone-config.sh            # Clone configuration helper
└── docs/                          # Additional documentation
```

## Usage

### Using the Python Script

```bash
python scripts/migrate.py \
  --source https://source-tenant.live.dynatrace.com \
  --target https://target-tenant.live.dynatrace.com \
  --source-token YOUR_SOURCE_TOKEN \
  --target-token YOUR_TARGET_TOKEN
```

### Using the Shell Script

```bash
./scripts/migrate.sh \
  --source-url https://source-tenant.live.dynatrace.com \
  --target-url https://target-tenant.live.dynatrace.com \
  --source-token YOUR_SOURCE_TOKEN \
  --target-token YOUR_TARGET_TOKEN
```

### Using Environment Variables

```bash
source .env
python scripts/migrate.py
```

## Configuration Files

Edit `config/environments.yaml` to define your tenants:

```yaml
environments:
  source:
    name: source-tenant
    url: https://source-tenant.live.dynatrace.com
    token: ${SOURCE_TENANT_TOKEN}
  
  target:
    name: target-tenant
    url: https://target-tenant.live.dynatrace.com
    token: ${TARGET_TENANT_TOKEN}
```

## Features

- ✅ Clone configuration from source to target tenant
- ✅ Support for all Dynatrace configuration types
- ✅ Dry-run mode to preview changes
- ✅ Validation before deployment
- ✅ Rollback capabilities
- ✅ Detailed logging

## Getting API Tokens

1. Go to your Dynatrace tenant
2. Navigate to **Settings** → **Integration** → **Dynatrace API**
3. Create a new token with the following scopes:
   - Read configuration (`config.read`)
   - Write configuration (`config.write`)
   - Read Dashboards (`dashboards.read`)
   - Write Dashboards (`dashboards.write`)
   - And other necessary scopes based on your use case

## Troubleshooting

### "Monaco command not found"

Ensure Monaco is in your PATH:
```bash
export PATH="$PATH:$HOME/tools/monaco"
```

### "Invalid API token"

- Verify your tokens are correct
- Check that tokens have the necessary scopes
- Ensure tokens haven't expired

### "Configuration validation failed"

- Check the error messages in the logs
- Verify your configuration YAML is properly formatted
- Ensure all required fields are present

## References

- [Dynatrace Monaco Documentation](https://github.com/dynatrace-oss/dynatrace-monitoring-as-code)
- [Dynatrace API Documentation](https://www.dynatrace.com/support/help/dynatrace-api)
- [Configuration as Code Best Practices](https://www.dynatrace.com/support/help/how-to-use-dynatrace/configuration-management/configuration-as-code)

## License

MIT
