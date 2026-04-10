# SaaS Configuration Export Guide

This guide explains how to use the `s2s-export.sh` script to export Dynatrace configurations from SaaS or Managed environments.

**Primary Use Case:** SaaS-to-SaaS tenant configuration migration
**Secondary Use Case:** Exporting Managed configurations for migration to SaaS using the SaaS Upgrade Assistant

## Purpose

The `s2s-export.sh` script enables:
- Exporting complete configuration from one Dynatrace SaaS tenant to another
- Migrating configurations between SaaS environments
- Exporting Dynatrace Managed configurations (secondary use case)

**For Managed-to-SaaS users:** Exported Managed configurations can be imported into the **SaaS Upgrade Assistant** app for guided migration to SaaS. See [SaaS Upgrade Assistant documentation](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant) for detailed steps.

## Overview

The `s2s-export.sh` script automates the process of:
1. Downloading the Monaco CLI tool
2. Verifying its integrity via checksum
3. Generating a temporary API token with read access scopes
4. Downloading all configurations from your Dynatrace source environment (SaaS or Managed)
5. Creating a timestamped export package with metadata
6. Archiving the export into a compressed tar.gz file (ready for deployment to target SaaS environment or SaaS Upgrade Assistant)

## Prerequisites

Before running the script, ensure you have:

- **Dynatrace Managed Environment** (source environment)
  - Access to Dynatrace Managed cluster administration console
  - Environment to export from
- **Environment Token** with API token management permissions
  - Can be created at Cluster Management Console > Settings > API tokens
  - Required scopes: `apiTokens.create`, `apiTokens.read`
- **Target SaaS Environment** (where you'll import)
  - SaaS Upgrade Assistant app installed in target environment
  - See [SaaS Upgrade Assistant documentation](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant)
- **Shell environment**: bash 4.0+
- **Required commands**: `curl`, `jq`, `grep`, `awk`, `tar`, `date`
- **Internet access** to download Monaco binary and communicate with Dynatrace API
- **Disk space** for configurations (varies by tenant size, typically 10-100MB)

### macOS Prerequisites
```bash
# Install dependencies via Homebrew if needed
brew install curl jq
```

### Linux Prerequisites
```bash
# Ubuntu/Debian
sudo apt-get install curl jq

# RHEL/CentOS
sudo yum install curl jq
```

## Setup

1. **Set the API Token environment variable:**
   ```bash
   export ENV_TOKEN="dt0c01.xxxxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   ```

2. **Make the script executable:**
   ```bash
   chmod +x scripts/bash/s2s-export.sh
   ```

3. **Navigate to the script directory:**
   ```bash
   cd monaco_s2s_sua_migration/
   ```

## Usage

### Basic Syntax
```bash
./scripts/bash/s2s-export.sh <environment-id> <environment-url-base>
```

### Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|----------|
| `environment-id` | Yes | Your Dynatrace environment ID (from Managed console) | `abc12345` |
| `environment-url-base` | No | Base URL (default: `live.dynatrace.com`) | `managed.example.com` or `dynatrace.mycompany.com` |

### Examples

#### 1. Export from SaaS tenant
```bash
export ENV_TOKEN="dt0c01.source_tenant.xxxxx"
./scripts/bash/s2s-export.sh abc12345
```

#### 2. With custom Python venv
```bash
source .venv/bin/activate
export ENV_TOKEN="dt0c01.source_tenant.xxxxx"
./scripts/bash/s2s-export.sh abc12345
```

#### 3. Managed environment (secondary use case)
For exporting from Dynatrace Managed, specify the domain:
```bash
export ENV_TOKEN="dt0c01.managed_env.xxxxx"
./scripts/bash/s2s-export.sh abc12345 managed.example.com
```

## Output Structure

After successful execution, the script creates:

```
configurationExport-2024-02-15_14-30-45.tar.gz
├── configurationExport-2024-02-15_14-30-45/
│   ├── exportMetadata.json          # Export metadata (timestamp, version info)
│   └── export/                      # All configuration files
│       ├── dashboards/
│       ├── service-level-objectives/
│       ├── alerting-profiles/
│       ├── notification-channels/
│       ├── application-detection/
│       └── ... (other config types)
```

### Metadata File (exportMetadata.json)
```json
{
  "clusterUuid": "abc12345",
  "productVersion": "1.288.0.20240229-161733",
  "monacoVersion": "2.12.0",
  "exportTimestamp": 1676553045000,
  "environments": [
    {
      "name": "abc12345",
      "uuid": "abc12345"
    }
  ]
}
```

## What Gets Exported

The script exports these configuration types (compatible with SaaS Upgrade Assistant):
- Dashboards
- Service Level Objectives (SLOs)
- Alerting profiles and rules
- Notification channels
- Application detection rules
- Extension configurations
- Network zones
- Geographic regions
- Synthetic locations and monitors
- Settings and policies
- And more...

**Note:** Some Managed-specific configurations may require adjustment in SaaS. The SaaS Upgrade Assistant will highlight any required changes during import.

## Security Notes

⚠️ **Important Security Considerations:**

1. **API Token Handling**
   - The script generates a temporary token named `rs-monaco-test`
   - This token is stored only in the `MONACO_TOKEN` environment variable during execution
   - It is NOT saved to disk or included in the archive
   - The token expires based on token settings in your environment

2. **Sensitive Data**
   - Exported configuration may include sensitive settings
   - The archive contains unencrypted configuration data
   - Store archives securely (encryption, access controls)
   - Do not commit archives to version control
   - The SaaS Upgrade Assistant will ask you to verify sensitive configurations during import

3. **Credentials in Archives**
   - Any credentials stored in configuration will be included
   - Remove/mask sensitive values before sharing exports
   - Consider using Monaco's secret management for sensitive values

## Troubleshooting

## Next Steps: Loading into SaaS Upgrade Assistant

After successfully exporting:

1. **Extract the archive**
   ```bash
   tar -xzf configurationExport-*.tar.gz
   ```

2. **Upload to SaaS Upgrade Assistant**
   - In your target SaaS environment, open the SaaS Upgrade Assistant app
   - Go to **Update configuration** > **Upload configuration**
   - Select the exported archive or extracted folder
   - The Migration Assistant will validate and show any issues

3. **Review and Fix Issues**
   - The Migration Assistant displays failed configurations in red (compatibility issues)
   - Failed configs indicate SaaS-incompatible settings or entity ID changes
   - Use the built-in **Edit mode** to modify configurations
   - Use **bulk edit** mode to update multiple configurations at once

4. **Review Dependencies**
   - The Migration Assistant shows configuration dependencies
   - Some configurations may depend on others (e.g., dashboards depend on applications)
   - Review dependency chains to understand deployment order
   - You can break dependencies if needed to simplify migration

5. **Update Dashboard Owners and Dependencies**
   - Some dashboard owners may need to be updated
   - Entity IDs between Managed and SaaS may differ
   - The Migration Assistant highlights these changes

6. **Deploy to SaaS**
   - Choose which configurations to deploy
   - Use **Validate and preview changes** before deploying
   - Deploy to your SaaS environment
   - Track deployment progress in the Migration Assistant UI

### Team Collaboration

If working with a team:
- **Share Progress** - Each team member can work on different configurations
- **Share Upgrade ID** - Export your Upgrade ID from SaaS Upgrade Assistant's Advanced panel
- **Sync Changes** - Team members can import your Upgrade ID to see your fixes and changes

### Configuration Update Resources

For detailed Migration Assistant instructions, see:

**Core Workflow:**
- **Main Guide:** [Dynatrace SaaS Upgrade Assistant](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant)
- **Update Configurations:** [How to Update Configuration in SaaS Upgrade Assistant](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-update-config)
  - Edit mode for fixing individual configurations
  - Handling entity ID changes
  - Reverting changes if needed

**Editing Configurations:**
- **Single & Bulk Edit:** [Update Configuration via Editable Properties](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-update-editable-properties)
  - Single configuration edit mode
  - Bulk edit multiple configurations at once
  - Example: Updating Synthetic location references
- **Dashboard Owners:** [Automatically Update Dashboard Owners](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-update-dashboard-owners)

**Advanced Topics:**
- **Dependencies:** [Manage Dependencies Between Configurations](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-dependencies)
  - Understanding direct and indirect dependencies
  - Breaking dependencies to simplify migration
  - Handling cyclic dependencies
- **Collaboration:** [Collaborate on Upgrades with Other Users](https://docs.dynatrace.com/managed/upgrade/saas-upgrade-assistant/sua-collaborate)
  - Share Upgrade ID with team members
  - Collaborate on configuration fixes
  - Track migration progress together

### Installation & Dependencies

#### "Error: Required command 'jq' not found"
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

#### "Error: Required command 'curl' not found"
```bash
# macOS
brew install curl

# Ubuntu/Debian
sudo apt-get install curl

# RHEL/CentOS
sudo yum install curl
```

#### "Error: java: command not found" (if using Monaco directly)
```bash
# Install Java
brew install java

# Verify installation
java -version

# Add to PATH if needed
export PATH="$(/usr/libexec/java_home -v 11)/bin:$PATH"
```

### Environment & Configuration

#### "Error: ENV_TOKEN environment variable is not set"
```bash
# Solution: Export the token before running
export ENV_TOKEN="dt0c01.xxxxxxxxxxxx.xxxxx"

# Verify it's set
echo $ENV_TOKEN

# Make it persistent (optional)
echo 'export ENV_TOKEN="dt0c01.xxxxxxxxxxxx.xxxxx"' >> ~/.zshrc
source ~/.zshrc
```

#### Invalid API Token
```
Error: API returned 401 Unauthorized
```

**Troubleshooting:**
1. **Token format**
   - Should start with `dt0c01.`
   - Should be ~70 characters total
   
2. **Token expiration**
   - Generate new token in Dynatrace UI
   - Navigate to Settings > Integration > API tokens
   
3. **Token scopes**
   - Verify token has at least these scopes:
     - `apiTokens.create`
     - `apiTokens.read`
     - `config.read`
   ```bash
   # Check token scopes
   curl -H "Authorization: Api-Token $ENV_TOKEN" \
     "https://your-tenant.live.dynatrace.com/api/v2/tokens/info" | jq '.scopes'
   ```

4. **Token for wrong environment**
   - Ensure token is from the source tenant you're exporting from
   - Token cannot be reused across different tenant environments

#### "Error: Unsupported environment URL"
- Verify you're using the correct environment URL format
- For SaaS: Use tenant ID only (e.g., `abc12345`)
- For Managed: Specify full URL base (e.g., `managed.example.com`)
- Ensure URL doesn't have protocol prefix (`https://`)

### Network & Connectivity

#### "Error: Failed to download Monaco binary"
```
Connection refused or timeout when downloading Monaco
```

**Solutions:**
1. **Check internet connectivity**
   ```bash
   ping github.com
   curl -I https://github.com
   ```

2. **Check firewall/proxy**
   ```bash
   # If behind corporate proxy
   export HTTP_PROXY="http://proxy.company.com:8080"
   export HTTPS_PROXY="http://proxy.company.com:8080"
   ```

3. **Verify disk space**
   ```bash
   df -h
   # Monaco binary needs ~50MB
   # Configuration export needs space for your tenant config
   ```

4. **Try manual download**
   ```bash
   # Download manually from GitHub
   curl -L https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/download/v2.12.0/monaco-darwin-arm64 -o monaco
   chmod +x monaco
   ```

#### "Connection refused" or "Could not connect to tenant"
```bash
# Test connectivity to tenant
curl -I "https://abc12345.live.dynatrace.com"

# If using managed environment
curl -I "https://managed.example.com"

# Should return HTTP 200-302 response
```

**Solutions:**
- Verify tenant URL spelling and format
- Check if tenant is accessible from your network
- Verify no corporate firewall blocking Dynatrace domains
- Test with: `ping abc12345.live.dynatrace.com`

### File & Archive Issues

#### "Error: Checksum verification failed"
```
Monaco binary checksum verification failed
```

**Causes & Solutions:**
- Binary download was corrupted (network issue)
- Check internet connection stability
- Verify sufficient disk space for download
- Try running the script again

```bash
# If persistent, manually verify:
shasum -a 256 monaco-darwin-arm64
# Compare with checksum file online
```

#### "Archive created but empty or incomplete"
```bash
# Verify tenant has configuration
# Check the downloaded directory before cleanup
ls -la {tenantId}/

# Monaco scopes are insufficient
# Ensure token has full config.read scope
```

**Solutions:**
1. **Check Monaco token scopes**
   ```bash
   # Verify token has config.read permission
   curl -H "Authorization: Api-Token $ENV_TOKEN" \
     "https://abc12345.live.dynatrace.com/api/v2/tokens/info" | jq '.scopes'
   ```

2. **Verify tenant has configuration**
   - Log into Dynatrace UI
   - Check if dashboards, SLOs, alerts exist
   - Empty tenants will produce minimal exports

3. **Review Monaco output**
   - Check for errors in console output
   - Enable debug: `bash -x ./scripts/bash/s2s-export.sh abc12345`

#### "Error: YAML parsing error" (if manually editing files)
```
mapping values are not allowed here
```

**Solutions:**
- Use correct indentation (2 spaces, no tabs)
- Ensure colons have spaces after them: `key: value`
- Verify quotes are balanced
- Validate with: `python3 -c "import yaml; yaml.safe_load(open('file.yaml'))"`

### Performance & Timeouts

#### "Slow download performance" or "Timeout during export"
- Large configurations may take several minutes (10-30min for large tenants)
- Monitor disk usage: `du -sh {tenantId}/`
- Run during off-peak hours for better performance
- Increase curl timeout by editing script:
  ```bash
  # Add timeout parameters to curl commands
  curl --max-time 300 ...
  ```

#### "Script interrupted or stopped unexpectedly"
```bash
# Clean up temporary files manually
rm -f monaco monaco_checksum manifest.yaml
rm -rf {tenantId}/

# Re-run the script
./scripts/bash/s2s-export.sh abc12345
```

### API & Authorization

#### "Error: Insufficient permissions"
```
403 Forbidden - You do not have permission to perform this action
```

**Solution:**
- Log into Dynatrace as environment admin
- Verify your API token has these scopes:
  - `config.read` - read configurations
  - `apiTokens.create` - create temporary token
  - `settings.read` - read settings
  - `slo.read` - read SLOs
  - `entities.read` - read entity data

```bash
# Regenerate token with correct scopes in Dynatrace UI
# Settings > Integration > API Tokens
# Create new token with all required scopes
```

#### "Error: Failed to generate Monaco API token"
```
API token generation failed or token is empty
```

**Debugging:**
```bash
# Test token generation manually
curl -X POST "https://abc12345.live.dynatrace.com/api/v2/apiTokens" \
  -H "Authorization: Api-Token $ENV_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-token","scopes":["config.read"]}'

# Should return JSON with "token" field
# If error, check response for details
```

### Debug Mode

#### Enable verbose logging
```bash
# Run with bash debug output
bash -x ./scripts/bash/s2s-export.sh abc12345

# Keep temporary files for inspection
# Comment out cleanup section in script before running
```

#### Inspect intermediate files
```bash
# Before cleanup runs, check:
ls -la monaco                    # Binary file
ls -la manifest.yaml            # Configuration file
ls -la {tenantId}/              # Downloaded configurations
ls -la exportMetadata.json      # Export metadata
```

### When All Else Fails

1. **Verify prerequisites are met**
   ```bash
   command -v curl && echo "curl: OK"
   command -v jq && echo "jq: OK"
   command -v grep && echo "grep: OK"
   command -v awk && echo "awk: OK"
   ```

2. **Test each component**
   ```bash
   # Test API connectivity
   curl -H "Authorization: Api-Token $ENV_TOKEN" \
     "https://abc12345.live.dynatrace.com/api/v2/tokens/info"
   
   # Test jq
   echo '{"test": "value"}' | jq '.test'
   ```

3. **Check Monaco documentation**
   - Visit: https://github.com/Dynatrace/dynatrace-configuration-as-code
   - Review Monaco CLI reference

4. **Collect diagnostic information**
   ```bash
   # Useful for support:
   uname -a                       # OS info
   bash --version                 # Bash version
   curl --version                 # Curl version
   jq --version                   # jq version
   echo $ENV_TOKEN | head -c 20   # Token prefix (safe to share)
   ```

## Advanced Usage

### Debugging
```bash
# Run with verbose output
bash -x ./scripts/bash/s2s-export.sh abc12345

# Keep temporary files for inspection
# Comment out cleanup lines before running
```

### Custom Token Scopes
The script uses these API token scopes:
```
attacks.read
entities.read
extensionConfigurations.read
extensionEnvironment.read
extensions.read
geographicRegions.read
javaScriptMappingFiles.read
networkZones.read
settings.read
slo.read
syntheticExecutions.read
syntheticLocations.read
DataExport
ReadConfig
RumJavaScriptTagManagement
```

Modify the scope list in the script if you need different access levels.

## Next Steps

After export:

1. **Extract the archive:**
   ```bash
   tar -xzf configurationExport-2024-02-15_14-30-45.tar.gz
   ```

2. **Use with Monaco for migration:**
   ```bash
   monaco deploy -e target-env -d export/
   ```

3. **Back up securely:**
   ```bash
   # Encrypt before storing
   gpg --symmetric configurationExport-2024-02-15_14-30-45.tar.gz
   ```

4. **Verify export completeness:**
   - Check `exportMetadata.json` timestamp and version info
   - Count configuration files match expectations
   - Test restore on non-production tenant first

## Related Documentation

- [Monaco CLI Documentation](https://github.com/Dynatrace/dynatrace-configuration-as-code)
- [Dynatrace Configuration API](https://www.dynatrace.com/support/help/dynatrace-api)
- [API Token Management](https://www.dynatrace.com/support/help/how-to-use-dynatrace/user-management-and-security/access-management/api-tokens)

## Support

For issues or questions:
1. Review the troubleshooting section above
2. Review script comments in `scripts/bash/s2s-export.sh`
3. Check Monaco CLI logs in the generated directory
4. Verify API token permissions in Dynatrace UI
