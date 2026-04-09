# Managed-to-SaaS Export (SaaS Upgrade Assistant)

Standalone directory for exporting Dynatrace Managed environment configurations for migration to SaaS using the **SaaS Upgrade Assistant**.

## Purpose

Export complete configuration from your Dynatrace Managed cluster to prepare for migration to Dynatrace SaaS. The exported archive is compatible with the SaaS Upgrade Assistant app for guided configuration migration and validation.

**Learn more:** [Dynatrace SaaS Upgrade Assistant](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant)

## Quick Start

1. **Set your API token** (from Dynatrace Managed environment):
   ```bash
   export ENV_TOKEN="dt0c01.xxxxxxxxxxxx.xxxxx"
   ```

2. **Run the export:**
   ```bash
   ./scripts/s2s-export.sh <environment-id> <managed-domain>
   ```
   Example:
   ```bash
   ./scripts/s2s-export.sh abc12345 managed.example.com
   ```

## Files

- **scripts/s2s-export.sh** - Main export script
- **docs/S2S_EXPORT.md** - Complete usage guide, troubleshooting, and SaaS Upgrade Assistant integration

## Requirements

- bash 4.0+
- curl
- jq
- grep, awk
- tar, date
- Valid Dynatrace API token (from Managed environment) with proper scopes
- Access to Dynatrace Managed environment

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

1. **Export** - Run this script to export from Managed
2. **Upload** - Import the archive into SaaS Upgrade Assistant
3. **Fix** - Use Migration Assistant to resolve any configuration issues
4. **Deploy** - Deploy configurations to your SaaS environment

## Examples

### Export from Dynatrace Managed
```bash
export ENV_TOKEN="dt0c01.xxxxxxxxxxxx.xxxxx"
./scripts/s2s-export.sh abc12345 managed.company.com
```

### Export with custom domain
```bash
export ENV_TOKEN="dt0c01.xxxxxxxxxxxx.xxxxx"
./scripts/s2s-export.sh abc12345 dynatrace.internal.company.com
```

## Output

Creates a timestamped `.tar.gz` archive containing:
- `exportMetadata.json` - Export metadata (versions, timestamps, tenant info)
- `export/` - All configuration files organized by type
- Ready for import into SaaS Upgrade Assistant

## Resources

**Export & Setup:**
- [SaaS Upgrade Assistant Guide](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant)

**Configuration Updates:**
- [Update Configuration in SaaS Upgrade Assistant](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-update-config) - Edit mode and configuration fixes
- [Update via Editable Properties](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-update-editable-properties) - Single and bulk edit modes
- [Update Dashboard Owners](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-update-dashboard-owners) - Automatic dashboard owner updates

**Advanced:**
- [Manage Dependencies](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-dependencies) - Understanding and breaking configuration dependencies
- [Collaborate on Upgrades](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-collaborate) - Team collaboration using Upgrade IDs
