# Full Tenant Migration Package

Complete standalone package for migrating all Dynatrace configurations from a source tenant to a target tenant using Monaco CLI.

## Quick Start

1. **Copy and configure the environment file:**
   ```bash
   cp config/.env.example .env
   # Edit .env with your actual tenant URLs and API tokens
   nano .env
   ```

2. **Load environment variables:**
   ```bash
   source .env
   ```

3. **Run the migration:**

   **Python:**
   ```bash
   python3 scripts/python/migrate.py
   ```

   **Bash:**
   ```bash
   ./scripts/bash/migrate.sh
   ```

   **PowerShell (Windows):**
   ```powershell
   .\scripts\powershell\migrate.ps1
   ```

## What Gets Migrated

A complete full tenant migration includes:
- Dashboards (Gen3)
- Service Level Objectives (SLOs)
- Alerting profiles and rules
- Notification channels
- Application detection rules
- Service detection rules
- Request naming rules
- Auto-tags and tagging rules
- Synthetic monitors and locations
- Management zones
- Settings and policies
- Extensions and custom apps
- Kubernetes app monitoring
- And all other configuration types

All configurations are migrated exactly as they exist in the source tenant.

## Prerequisites

- **Monaco CLI** - Download from https://github.com/Dynatrace/dynatrace-configuration-as-code/releases
- **Python 3.8+** (for Python script) or **Bash 4.0+** (for Shell script) or **Windows PowerShell 5.1+** (for PowerShell script)
- **curl** - For API connectivity verification
- **jq** - For JSON processing (optional)
- **Valid Dynatrace API tokens** with proper scopes

### Required API Token Scopes

Your API tokens need these minimum scopes:

**Source Token:**
- `config.read` - Read all configurations
- `entities.read` - Read entity information
- `settings.read` - Read settings

**Target Token:**
- `config.write` - Write configurations
- `entities.read` - Read entity information  
- `settings.write` - Write settings

## Installation

### 1. Install Monaco CLI

**macOS:**
```bash
brew install dynatrace-oss/dynatrace/monaco

# Or manually download
mkdir -p ~/tools/monaco
cd ~/tools/monaco
curl -L https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/download/v2.12.0/monaco-darwin-arm64 -o monaco
chmod +x monaco
export PATH="$PATH:$HOME/tools/monaco"
```

**Linux:**
```bash
curl -L https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-linux-amd64 -o monaco
chmod +x monaco
sudo mv monaco /usr/local/bin/
```

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -URI https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-windows-amd64.exe -OutFile monaco.exe
```

### 2. Install Python Dependencies (if using Python script)

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Configure Environment

```bash
cp config/.env.example .env
# Edit .env with your tenant URLs and API tokens
nano .env
```

## Usage

### Python Script

**Basic migration:**
```bash
source .env
python3 scripts/python/migrate.py
```

**Dry run (preview changes):**
```bash
python3 scripts/python/migrate.py --dry-run
```

**With command-line arguments:**
```bash
python3 scripts/python/migrate.py \
  --source https://source.live.dynatrace.com \
  --target https://target.live.dynatrace.com \
  --source-token YOUR_TOKEN \
  --target-token YOUR_TOKEN
```

### Bash Script

**Basic migration:**
```bash
source .env
./scripts/bash/migrate.sh
```

**Dry run (preview changes):**
```bash
./scripts/bash/migrate.sh --dry-run
```

**With command-line arguments:**
```bash
./scripts/bash/migrate.sh \
  --source-url https://source.live.dynatrace.com \
  --target-url https://target.live.dynatrace.com \
  --source-token YOUR_TOKEN \
  --target-token YOUR_TOKEN
```

**Skip backup:**
```bash
./scripts/bash/migrate.sh --no-backup
```

### PowerShell Script (Windows)

**Basic migration:**
```powershell
# Load .env manually or set environment variables
$env:SOURCE_TENANT_URL = "https://source.live.dynatrace.com"
$env:SOURCE_TENANT_TOKEN = "your_token"
$env:TARGET_TENANT_URL = "https://target.live.dynatrace.com"
$env:TARGET_TENANT_TOKEN = "your_token"
.\scripts\powershell\migrate.ps1
```

**Dry run (preview changes):**
```powershell
.\scripts\powershell\migrate.ps1 -DryRun
```

**With parameters:**
```powershell
.\scripts\powershell\migrate.ps1 `
  -SourceUrl "https://source.live.dynatrace.com" `
  -TargetUrl "https://target.live.dynatrace.com" `
  -SourceToken "YOUR_TOKEN" `
  -TargetToken "YOUR_TOKEN"
```

**Skip backup:**
```powershell
.\scripts\powershell\migrate.ps1 -NoBackup
```

## Migration Process

The migration follows this workflow:

1. **Verification**
   - Verify Monaco CLI is installed
   - Verify API connectivity to both tenants
   - Validate token scopes and permissions

2. **Safety Backup**
   - Creates automatic backup of target tenant configuration
   - Backed up before any changes are made to target
   - Stored in `config/backups/{timestamp}/`

3. **Source Download**
   - Downloads ALL configurations from source tenant
   - Saves to `config/source/`
   - Complete snapshot of source state

4. **Validation**
   - Validates all downloaded YAML files
   - Checks for syntax errors
   - Ensures configuration integrity

5. **Deployment**
   - Deploys configurations to target tenant
   - Monaco applies changes incrementally
   - Handles dependencies and ordering

## Output Structure

```
config/
├── environments.yaml           # Monaco environment configuration
├── source/                     # Downloaded source configurations
│   ├── dashboards/
│   ├── alerting-profiles/
│   ├── management-zones/
│   ├── notification/
│   └── ... (all config types)
├── backups/
│   └── 20240309_143025/        # Target backup (timestamp)
│       └── (complete target configuration copy)
└── .env                        # Environment variables (gitignored)

migration_*.log                 # Migration logs (timestamped)
```

## Dry Run Mode

Always preview changes before running live migration:

```bash
# Python
python3 scripts/python/migrate.py --dry-run

# Bash
./scripts/bash/migrate.sh --dry-run

# PowerShell
.\scripts\powershell\migrate.ps1 -DryRun
```

This will:
- Verify all prerequisites
- Create environments.yaml
- Download source configuration
- Validate all configuration files
- **Skip** actual deployment to target

## Restoration

If migration needs to be rolled back:

```bash
# Backup is available at config/backups/{timestamp}/
# You can manually restore using Monaco:

monaco deploy \
  --environment target \
  --config-file config/environments.yaml \
  config/backups/20240309_143025/
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **API Token Handling**
   - Tokens are stored in `.env` (added to .gitignore)
   - Never commit `.env` to version control
   - Rotate tokens after migration if desired
   - Use environment-specific token scopes

2. **Sensitive Data**
   - All configurations are migrated including sensitive settings
   - Credentials stored in Dynatrace configurations are included
   - Store migration backups securely
   - Encrypt backups if storing long-term

3. **Target Tenant Safety**
   - Target backup created before any modifications
   - Allows rollback if needed
   - Use `--dry-run` to preview changes first
   - Ensure target tenant is prepared for changes

4. **Network Security**
   - Tokens transmitted over HTTPS only
   - Verify firewall allows Dynatrace API access
   - Use VPN if behind corporate proxy

## Troubleshooting

### Monaco Not Found

```bash
# Verify Monaco installation
monaco --version

# Add to PATH permanently
echo 'export PATH="$PATH:$HOME/tools/monaco"' >> ~/.zshrc
source ~/.zshrc
```

### API Token Errors

```bash
# Verify token format
echo $SOURCE_TENANT_TOKEN

# Check token scopes
curl -H "Authorization: Api-Token $SOURCE_TENANT_TOKEN" \
  "https://your-tenant.live.dynatrace.com/api/v2/tokens/info" | jq '.scopes'

# Regenerate token in Dynatrace UI if needed
# Settings > Integration > API Tokens
```

### Connection Failed

```bash
# Test connectivity
curl -I "https://your-tenant.live.dynatrace.com/api/v2/environments"

# Check for firewall/proxy blocking
ping your-tenant.live.dynatrace.com
```

### Configuration Validation Error

```bash
# Enable debug logging (Python)
python3 scripts/python/migrate.py --dry-run

# Or with Bash
bash -x ./scripts/bash/migrate.sh --dry-run

# Or with PowerShell
.\scripts\powershell\migrate.ps1 -DryRun -Verbose
```

### Empty Migration

If source has no configurations:

```bash
# Verify source tenant has configurations
# Log into Dynatrace UI and check:
# - Settings > Integration > Configuration Management
# - Check for dashboards, SLOs, alerts, etc.
```

## Performance Considerations

**Large Tenant Migration:**
- Large tenants (1000+ dashboards) may take 10-30 minutes
- Monitor progress in logs: `tail -f migration_*.log`
- Run during maintenance window to minimize impact
- Verify target tenant has sufficient API call quota

**Network Speed:**
- Migration speed depends on network bandwidth
- Large configuration archives require stable connection
- Resume is not automatic; restart from beginning if interrupted

## Logging

Migration logs are automatically created:

```bash
# Review migration logs
tail -f migration_*.log

# All logs preserved for troubleshooting
ls -la migration_*.log
```

## Next Steps

After successful migration:

1. **Verify in Target Tenant**
   - Log into target tenant
   - Spot-check dashboards, SLOs, alerts
   - Verify counts match source

2. **Run Validation**
   - Use included verification script (if available)
   - Check for missing or corrupted configurations

3. **Test Alerts**
   - Verify notification channels are working
   - Test alert firing and escalation

4. **Update Connections**
   - Update any external integrations pointing to old URLs
   - Notify users of new tenant URL

5. **Archive Backup**
   - Move backup to secure storage
   - Encrypt if required by policy
   - Document migration date/time

## Support & Documentation

- [Monaco CLI GitHub](https://github.com/Dynatrace/dynatrace-configuration-as-code)
- [Dynatrace Configuration API](https://www.dynatrace.com/support/help/dynatrace-api)
- [API Token Management](https://www.dynatrace.com/support/help/how-to-use-dynatrace/user-management-and-security/access-management/api-tokens)

## License & Attribution

Uses Dynatrace Monaco CLI for configuration management.
See Monaco repository for licensing information.
