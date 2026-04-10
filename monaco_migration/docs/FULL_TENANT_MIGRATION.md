# Full Tenant Migration Guide

## Overview

This guide describes how to perform a complete full tenant migration using Dynatrace Monaco CLI. A full tenant migration copies **all** configurations from a source Dynatrace tenant to a target tenant, including dashboards, monitoring settings, alerts, SLOs, and more.

## When to Use Full Tenant Migration

Full tenant migration is ideal for:
- **Tenant Consolidation** - Migrating users from one tenant to another
- **Environment Promotion** - Moving configurations from dev/staging to production
- **Tenant Upgrade** - Migrating to a new Dynatrace environment
- **Disaster Recovery** - Recreating configurations after data loss
- **Multi-region Setup** - Duplicating configuration across regions
- **Compliance/Architecture Change** - Reorganizing tenant structure

## What Gets Migrated

A full tenant migration includes ALL configuration types:

### Monitoring & Alerting
- **Dashboards & Visualizations** - Gen3 dashboards with all customizations
- **Service Level Objectives (SLOs)** - All SLO definitions and targets
- **Alerting Profiles** - Alert routing and notification rules
- **Notification Channels** - Email, Slack, PagerDuty, webhooks, etc.
- **Event Processing** - Problem event rules and conditions

### Application Monitoring
- **Application Detection Rules** - Rules identifying applications
- **Service Detection Rules** - Custom service definitions
- **Request Naming Rules** - Transaction naming patterns
- **Request and Service Attributes** - Custom dimensions
- **Calculated Metrics** - Service, log, and event metrics

### Infrastructure & Cloud
- **Host Monitoring Configuration** - Advanced host settings
- **Cloud Foundry Configuration** - CF-specific settings
- **Kubernetes App Monitoring** - K8s cluster configurations
- **Network Zones** - Geographic network definitions
- **Management Zones** - Environment segmentation and scoping

### Configuration Management
- **Settings** - Global and entity-specific settings
- **Auto-Tags** - Automatic tagging rules
- **Credentials** - Stored authentication secrets
- **Extensions** - Custom extensions and plugins

### Synthetic Monitoring
- **Synthetic Locations** - Test execution locations
- **Synthetic Monitors** - Browser and HTTP monitors
- **Synthetic Steps** - Monitor step configurations

### Advanced Features
- **Log Monitoring Configuration** - Log ingestion rules
- **Log Processing Rules** - Log parsing and enrichment
- **Log Custom Sources** - Custom log definitions
- **Events to Metrics** - Log event to metric conversions
- **Custom Apps** - Custom application configurations

## Prerequisites Checklist

Before starting, verify:

- [ ] **Monaco CLI installed** - Version 2.12.0 or later
- [ ] **Python 3.8+** or **Bash 4.0+** available
- [ ] **Source tenant access** - Valid URL and API token
- [ ] **Target tenant access** - Valid URL and API token  
- [ ] **API tokens created** with required scopes (see below)
- [ ] **Network connectivity** - Can reach both tenants
- [ ] **Firewall/proxy configured** - API calls not blocked
- [ ] **Target tenant prepared** - Ready to receive configurations
- [ ] **No conflicts** - Target configurations won't conflict with source
- [ ] **Maintenance window** - Scheduled if needed

### Required API Token Scopes

**Source Tenant Token** - Must have permissions to read:
```
config.read                      # Read all configurations
entities.read                    # Read entities
settings.read                    # Read settings
apiTokens.read                   # Read token info
```

**Target Tenant Token** - Must have permissions to write:
```
config.write                     # Deploy configurations
entities.read                    # Read entities
settings.write                   # Modify settings
apiTokens.read                   # Read token info
```

## Step-by-Step Migration Process

### Step 1: Prepare Environment

```bash
# Clone or download the migration package
cd monaco_migration/

# Create .env file with your credentials
cp config/.env.example .env
nano .env
```

**Edit .env with:**
```bash
SOURCE_TENANT_URL="https://source-tenant-id.live.dynatrace.com"
SOURCE_TENANT_TOKEN="dt0c01.XXXXXXXXXXXX..."

TARGET_TENANT_URL="https://target-tenant-id.live.dynatrace.com"
TARGET_TENANT_TOKEN="dt0c01.XXXXXXXXXXXX..."
```

### Step 2: Verify Prerequisites

```bash
# Load environment
source .env

# Verify Monaco is available
monaco --version

# Verify Python/Bash
python3 --version  # or bash --version

# Test connectivity (optional)
curl -H "Authorization: Api-Token $SOURCE_TENANT_TOKEN" \
  "${SOURCE_TENANT_URL}/api/v2/environments"
```

### Step 3: Dry Run (Recommended)

**Always test before running live migration:**

```bash
# Python
python3 scripts/python/migrate.py --dry-run

# Or Shell
./scripts/bash/migrate.sh --dry-run
```

Dry run performs all steps except actual deployment:
- ✓ Verifies Monaco installation
- ✓ Creates environments.yaml
- ✓ Verifies API connections
- ✓ Downloads source configurations
- ✓ Validates all configuration files
- ✗ Does NOT deploy to target

**Review output for:**
- Number of configurations downloaded
- Any validation errors or warnings
- Configuration types included

### Step 4: Full Tenant Migration

Once dry run completes successfully, run the actual migration:

```bash
# Python script
python3 scripts/python/migrate.py

# Or Shell script
./scripts/bash/migrate.sh
```

**Migration process runs in sequence:**

1. **Pre-flight checks** (30 seconds)
   - Verify Monaco CLI available
   - Create environments.yaml

2. **Connection verification** (1 minute)
   - Test API connectivity
   - Verify token scopes
   - Check tenant accessibility

3. **Target backup** (5-30 minutes depending on tenant size)
   - Downloads complete target configuration
   - Saves to `config/backups/{timestamp}/`
   - Allows rollback if needed

4. **Source download** (5-30 minutes depending on tenant size)
   - Downloads ALL configurations from source
   - Saves to `config/source/`
   - Complete state snapshot

5. **Validation** (1 minute)
   - Validates all YAML files
   - Checks syntax and structure
   - Ensures file integrity

6. **Deployment** (10-60 minutes depending on volume)
   - Deploys configurations to target
   - Monaco applies in dependency order
   - Handles conflicts and updates

7. **Completion** (automatic)
   - Migration report generated
   - Backup location confirmed
   - Success/failure status reported

### Step 5: Verify Migration Success

After migration completes, verify:

```bash
# 1. Check logs
tail -20 migration_*.log

# 2. Log into target tenant
# - Open https://target-tenant-id.live.dynatrace.com
# - Navigate to Settings > Integration > Configuration Management
# - Verify configurations appear

# 3. Spot-check key items
# - Dashboards > Verify key dashboards exist
# - SLOs > Check SLO targets match source
# - Alerts > Verify alerting profiles migrated
# - Settings > Check custom settings applied

# 4. Manual validation (optional)
# - Test a dashboard works correctly
# - Verify alert routing configured
# - Check SLO calculations running
```

## Configuration Comparison Matrix

| Component | Count | Verify In Target UI |
|-----------|-------|---------------------|
| Dashboards | ? | Settings > Configuration Management > Dashboards |
| SLOs | ? | Quality Gates > SLOs |
| Alerting Profiles | ? | Alerting > Alerting Profiles |
| Notifications | ? | Settings > Integration > Notifications |
| Management Zones | ? | Settings > Management Zones |
| Hosts Tagged | ? | Infrastructure > Hosts (check tags) |

## Common Issues & Solutions

### Issue: "Monaco CLI not found"

**Solution:**
```bash
# Install Monaco
brew install dynatrace-oss/dynatrace/monaco

# Or manually
mkdir -p ~/tools/monaco
cd ~/tools/monaco
curl -L https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/download/v2.12.0/monaco-darwin-arm64 -o monaco
chmod +x monaco

# Add to PATH permanently
echo 'export PATH="$PATH:$HOME/tools/monaco"' >> ~/.zshrc
```

### Issue: "API Token Invalid - 401 Unauthorized"

**Solution:**
```bash
# Verify token format
echo $SOURCE_TENANT_TOKEN  # Should start with dt0c01.

# Check token scopes
curl -H "Authorization: Api-Token $SOURCE_TENANT_TOKEN" \
  "${SOURCE_TENANT_URL}/api/v2/tokens/info" | jq '.scopes'

# Regenerate token if needed
# Log into source tenant > Settings > Integration > API Tokens
```

### Issue: "Connection Refused - Cannot reach tenant"

**Solution:**
```bash
# Verify URL format
echo $SOURCE_TENANT_URL  # Should NOT start with https://

# Test connectivity
curl -I "https://source-tenant-id.live.dynatrace.com/api/v2/environments"

# Check firewall
ping source-tenant-id.live.dynatrace.com

# If behind proxy
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"
```

### Issue: "Configuration validation failed"

**Solution:**
```bash
# Review downloaded YAML files for syntax errors
find config/source -name "*.yaml" | head -5

# Validate YAML manually
python3 -c "import yaml; print(yaml.safe_load(open('file.yaml')))"

# Check for special characters or formatting issues
# Monaco may require specific YAML formatting
```

### Issue: "Migration hangs or times out"

**Solution:**
```bash
# Check for large configurations
du -sh config/source/

# Large tenants need more time (up to 1 hour)
# Run migration in background with nohup
nohup ./scripts/bash/migrate.sh &

# Monitor progress
tail -f migration_*.log

# Kill and restart if needed
# Rerun migration (safe - idempotent)
./scripts/bash/migrate.sh
```

### Issue: "Target already has conflicting configurations"

**Backup and restore scenario:**
```bash
# Option 1: Merge configurations (Monaco default)
# - Existing target configs preserved if no conflict
# - Source configs added/updated
# - Run migration normally

# Option 2: Replace completely
# 1. Restore from backup first (see Rollback section)
# 2. Clean target manually
# 3. Run migration again

# Option 3: Partial migration
# Re-run with specific configuration types only
# (Requires editing migrate scripts)
```

## Rollback Procedure

If migration causes issues, restore from backup:

```bash
# Backup is at config/backups/{timestamp}/
BACKUP_DIR="config/backups/20240309_143025"

# Redeploy target from backup
monaco deploy \
  --environment target \
  --config-file config/environments.yaml \
  $BACKUP_DIR

# Verify rollback
# Log in and confirm previous configurations restored
```

## Performance Optimization

**Large Tenant Migrations (1000+ items):**

```bash
# 1. Increase timeouts in scripts
# Edit migrate.py or migrate.sh
# Look for timeout parameters

# 2. Run during off-peak hours
# Reduces API throttling
# Minimizes impact on other users

# 3. Monitor resource usage
# Check Monaco process
# Verify disk space for configurations

# 4. Use background execution
nohup ./scripts/bash/migrate.sh > migration.out 2>&1 &
# Monitor: tail -f migration.out
```

## Security Best Practices

1. **Protect API Tokens**
   - Never commit .env to version control
   - Rotate tokens after migration
   - Use different tokens for source/target if possible

2. **Encrypt Backups**
   ```bash
   # Backup created automatically, optionally encrypt
   gpg --symmetric config/backups/20240309_143025.tar.gz
   ```

3. **Audit Trail**
   - Review migration logs for errors
   - Keep logs for compliance
   - Document migration date/time

4. **Test Before Production**
   - Always dry-run first
   - Test on non-production tenant if possible
   - Verify backup creation

## Post-Migration Checklist

After successful migration:

- [ ] Verify all dashboards appear in target
- [ ] Check SLO counts match source
- [ ] Test alert routing and notifications
- [ ] Verify management zones applied
- [ ] Confirm custom settings migrated
- [ ] Test key workflows still work
- [ ] Update documentation with new URLs
- [ ] Communicate to team about cutover
- [ ] Archive backup securely
- [ ] Monitor target for issues 24+ hours

## Migration Time Estimates

| Tenant Size | Config Count | Migration Time |
|------------|--------------|----------------|
| Small | < 100 | 5-10 minutes |
| Medium | 100-500 | 15-30 minutes |
| Large | 500-1000 | 30-60 minutes |
| Very Large | > 1000 | 60+ minutes |

Times vary based on:
- Network bandwidth
- API quota limits
- Configuration complexity
- Target tenant load

## Support Resources

- **Monaco Documentation:** https://github.com/Dynatrace/dynatrace-configuration-as-code
- **Configuration API:** https://www.dynatrace.com/support/help/dynatrace-api
- **API Token Setup:** https://www.dynatrace.com/support/help/how-to-use-dynatrace/user-management-and-security/access-management/api-tokens
- **Migration Logs:** `migration_*.log` files in migration directory

## Next Steps

1. **Immediate**: Verify configurations in target
2. **Day 1**: Run validation checks
3. **Week 1**: Monitor target performance
4. **Month 1**: Review and optimize configurations post-migration
