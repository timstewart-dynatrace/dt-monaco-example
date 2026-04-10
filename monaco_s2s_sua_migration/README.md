# SaaS-to-SaaS Configuration Export

Standalone directory for exporting and migrating Dynatrace SaaS tenant configurations to other SaaS environments.

## Purpose

Export complete configuration from one Dynatrace SaaS tenant to another for configuration migration or replication.

**Use Cases:**
- Cross-tenant SaaS configuration migration
- Configuration backup and replication
- Configuration evaluation before deployment
- Batch migration of multiple SaaS environments

## Quick Start

1. **Set your API token** (from source SaaS tenant):

   **Bash/macOS/Linux:**
   ```bash
   export ENV_TOKEN="dt0c01.xxxxxxxxxxxx.xxxxx"
   ```

   **PowerShell/Windows:**
   ```powershell
   $env:ENV_TOKEN = "dt0c01.xxxxxxxxxxxx.xxxxx"
   ```

2. **Run the export:**

   **Bash:**
   ```bash
   ./scripts/bash/s2s-export.sh <tenant-id> [environment-url-base]
   ```

   **Python:**
   ```bash
   pip install -r requirements.txt
   python3 scripts/python/s2s-export.py <tenant-id> [--env-url-base live.dynatrace.com]
   ```

   **PowerShell (Windows):**
   ```powershell
   .\scripts\powershell\s2s-export.ps1 -TenantId <tenant-id> [-EnvUrlBase live.dynatrace.com]
   ```

   Examples:
   ```bash
   # Bash - Export from SaaS (default)
   ./scripts/bash/s2s-export.sh abc12345

   # Python - Export from SaaS
   python3 scripts/python/s2s-export.py abc12345

   # PowerShell - Export from SaaS
   .\scripts\powershell\s2s-export.ps1 -TenantId abc12345
   ```

## Files

```
scripts/
├── bash/
│   └── s2s-export.sh          # Bash export script (macOS/Linux)
├── python/
│   └── s2s-export.py          # Python export script (cross-platform)
└── powershell/
    └── s2s-export.ps1         # PowerShell export script (Windows)
```

- **docs/S2S_EXPORT.md** - Complete usage guide, troubleshooting, and SaaS Upgrade Assistant integration
- **requirements.txt** - Python dependencies (for Python script)

## Requirements

Choose the script for your platform:

| Script | Requirements |
|--------|-------------|
| **Bash** | Bash 4.0+, curl, jq, grep, awk, tar |
| **Python** | Python 3.8+, requests library |
| **PowerShell** | Windows PowerShell 5.1+ (ships with Windows 10/11) |

All scripts require:
- Valid Dynatrace API token with proper scopes
- Network access to source Dynatrace environment

## Support

See [docs/S2S_EXPORT.md](docs/S2S_EXPORT.md) for:
- Detailed setup instructions
- Configuration options
- Export structure and metadata
- Security considerations
- Comprehensive troubleshooting guide
- Advanced usage examples
- Integration with SaaS Upgrade Assistant

## Workflow

1. **Export** - Run script to export from source SaaS tenant
2. **Extract** - Unpack the configuration archive
3. **Deploy** - Use Monaco CLI to deploy to target SaaS tenant

## Examples

### Export from SaaS tenant

**Bash:**
```bash
export ENV_TOKEN="dt0c01.source_tenant_token.xxxxx"
./scripts/bash/s2s-export.sh abc12345
# Output: configurationExport-2024-02-15_14-30-45.tar.gz
```

**Python:**
```bash
export ENV_TOKEN="dt0c01.source_tenant_token.xxxxx"
python3 scripts/python/s2s-export.py abc12345
# Output: configurationExport-2024-02-15_14-30-45.tar.gz
```

**PowerShell:**
```powershell
$env:ENV_TOKEN = "dt0c01.source_tenant_token.xxxxx"
.\scripts\powershell\s2s-export.ps1 -TenantId abc12345
# Output: configurationExport-2024-02-15_14-30-45.zip
```

### Deploy to target SaaS tenant
```bash
tar -xzf configurationExport-*.tar.gz
monaco deploy -e target-env -d export/
```

## Output

Creates a timestamped `.tar.gz` archive containing:
- `exportMetadata.json` - Export metadata (versions, timestamps, tenant info)
- `export/` - All configuration files organized by type
- Ready for deployment to target SaaS tenant or SaaS Upgrade Assistant

## Resources

- [Monaco CLI Documentation](https://github.com/Dynatrace/dynatrace-configuration-as-code)
- [Dynatrace Configuration API](https://www.dynatrace.com/support/help/dynatrace-api)
- [API Token Management](https://www.dynatrace.com/support/help/how-to-use-dynatrace/user-management-and-security/access-management/api-tokens)
