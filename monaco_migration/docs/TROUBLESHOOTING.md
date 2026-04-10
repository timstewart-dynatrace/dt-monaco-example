# Full Tenant Migration Troubleshooting

## Pre-Migration Issues

### Monaco CLI Not Found

```
Error: Monaco CLI not found
bash: monaco: command not found
```

**Root Cause:**
- Monaco not installed
- Monaco not in system PATH
- Wrong shell environment

**Solutions:**

1. **Install Monaco:**
   ```bash
   # macOS with Homebrew
   brew install dynatrace-oss/dynatrace/monaco
   
   # Manual installation
   mkdir -p ~/tools/monaco
   cd ~/tools/monaco
   curl -L https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/download/v2.12.0/monaco-darwin-arm64 -o monaco
   chmod +x monaco
   ```

2. **Add to PATH:**
   ```bash
   # Temporarily
   export PATH="$PATH:$HOME/tools/monaco"
   
   # Permanently (add to ~/.zshrc or ~/.bash_profile)
   echo 'export PATH="$PATH:$HOME/tools/monaco"' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **Verify installation:**
   ```bash
   monaco --version  # Should show version number
   ```

### Python Dependencies Not Installed

```
Error: ModuleNotFoundError: No module named 'yaml'
```

**Solution:**
```bash
# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Or install globally
pip3 install pyyaml python-dotenv requests
```

### .env File Not Found

```
Error: SOURCE_TENANT_URL: unbound variable
```

**Solution:**
```bash
# Create .env from example
cp config/.env.example .env

# Edit with your values
nano .env

# Source it before running scripts
source .env

# Or add to .zshrc for automatic loading
echo 'source /path/to/migration/.env' >> ~/.zshrc
```

## Authentication Issues

### API Token Invalid (401 Unauthorized)

```
Error: Tenant returned HTTP 401
API error: 401 Unauthorized
```

**Diagnosis:**
```bash
# Check token format
echo $SOURCE_TENANT_TOKEN
# Should start with: dt0c01.

# Check token is set
test -z "$SOURCE_TENANT_TOKEN" && echo "NOT SET" || echo "SET"

# Verify token scopes
curl -H "Authorization: Api-Token $SOURCE_TENANT_TOKEN" \
  "${SOURCE_TENANT_URL}/api/v2/tokens/info" | jq '.scopes'
```

**Solutions:**

1. **Regenerate token:**
   - Log into Dynatrace (source tenant)
   - Settings > Integration > API Tokens
   - Create new token with scopes:
     - `config.read`
     - `entities.read`
     - `settings.read`

2. **Verify token format:**
   ```bash
   # Token should be exactly 70+ characters
   echo "$SOURCE_TENANT_TOKEN" | wc -c
   
   # Should not have quotes around it
   # Should not have whitespace
   ```

3. **Test token directly:**
   ```bash
   curl -H "Authorization: Api-Token $SOURCE_TENANT_TOKEN" \
     "${SOURCE_TENANT_URL}/api/v2/environments"
   # Should return 200 OK with JSON response
   ```

### Token Insufficient Scopes

```
Error: Missing required scopes
403 Forbidden - Insufficient permissions
```

**Solution:**

Create new token with ALL required scopes:

**Source Token Scopes:**
```
config.read
entities.read
settings.read
apiTokens.read
```

**Target Token Scopes:**
```
config.write
entities.read
settings.write
apiTokens.read
```

```bash
# Regenerate with correct scopes in Dynatrace UI
# Settings > Integration > API Tokens
```

### Token Expired

```
Error: Token has expired
403 Forbidden - Token is no longer valid
```

**Solution:**
```bash
# Generate new token
# Settings > Integration > API Tokens > Generate New Token

# Update .env file
nano .env

# Re-source environment
source .env

# Retry migration
python3 scripts/python/migrate.py
```

## Network & Connectivity Issues

### Connection Refused

```
Error: Connection refused
curl: (7) Failed to connect
```

**Diagnosis:**
```bash
# Check if URL is accessible
curl -I "${SOURCE_TENANT_URL}/api/v2/environments"

# Ping attempt
ping source-tenant-id.live.dynatrace.com

# Check DNS resolution
nslookup source-tenant-id.live.dynatrace.com
```

**Solutions:**

1. **Verify tenant URL format:**
   ```bash
   # Correct format
   SOURCE_TENANT_URL="https://abc12345.live.dynatrace.com"
   
   # NOT just the ID
   SOURCE_TENANT_URL="abc12345"  # WRONG
   
   # NOT with /api at end
   SOURCE_TENANT_URL="https://abc12345.live.dynatrace.com/api"  # TOO MUCH
   ```

2. **Check firewall:**
   ```bash
   # Test connectivity
   (echo > /dev/null) < /dev/tcp/source-tenant-id.live.dynatrace.com/443 && echo "Can reach" || echo "Blocked"
   
   # May need firewall rule for Dynatrace domains
   ```

3. **Configure proxy if behind corporate firewall:**
   ```bash
   # Option 1: Set environment variables
   export HTTP_PROXY="http://proxy.company.com:8080"
   export HTTPS_PROXY="http://proxy.company.com:8080"
   
   # Option 2: Add to Monaco config (if available)
   monaco config set proxy http://proxy.company.com:8080
   ```

### Timeout During Download

```
Error: Timeout waiting for response
Connection timed out
```

**Causes:**
- Large tenant with many configurations (can take 30+ minutes)
- Network latency or instability
- Monaco rate limiting

**Solutions:**

1. **Wait longer:**
   ```bash
   # Large tenants need more time
   # Monitor progress in logs
   tail -f migration_*.log
   ```

2. **Run in background:**
   ```bash
   nohup python3 scripts/python/migrate.py &
   # or
   nohup ./scripts/bash/migrate.sh &
   
   # Check progress
   tail -f migration_*.log
   ```

3. **Check Monaco process:**
   ```bash
   ps aux | grep monaco
   # Should show active process
   ```

4. **Retry (migrations are idempotent):**
   ```bash
   # Safe to re-run - will resume or restart
   python3 scripts/python/migrate.py
   ```

## Configuration Issues

### Configuration Validation Failed

```
Error: Invalid YAML in config/source/dashboards/dash.yaml
mapping values are not allowed here
```

**Diagnosis:**
```bash
# Validate specific file
python3 -c "import yaml; yaml.safe_load(open('config/source/dashboards/dash.yaml'))"

# Check syntax manually
cat config/source/dashboards/dash.yaml
```

**Common YAML Errors:**

1. **Incorrect indentation:**
   ```yaml
   # WRONG - indent is 3 spaces
   parent:
      child: value
      
   # CORRECT - indent is 2 spaces
   parent:
     child: value
   ```

2. **Colon without space:**
   ```yaml
   # WRONG
   key:value
   
   # CORRECT
   key: value
   ```

3. **Unquoted special characters:**
   ```yaml
   # WRONG
   value: some:text
   
   # CORRECT
   value: "some:text"
   ```

**Solutions:**
```bash
# Enable debug logging
python3 -c "import yaml; yaml.safe_load(open('file'))" 2>&1

# Fix syntax based on error message
# Usually matches Monaco YAML requirements

# Retry migration
python3 scripts/python/migrate.py
```

### No Configuration Found

```
Downloaded 0 items
Configuration directory is empty
```

**Causes:**
- Source tenant has no configurations
- Token missing read scopes
- Monaco download command failed silently

**Diagnosis:**
```bash
# Check source tenant manually
# Log into Dynatrace UI
# Settings > Integration > Configuration Management
# Check if any configurations exist

# Verify token scopes
curl -H "Authorization: Api-Token $SOURCE_TENANT_TOKEN" \
  "${SOURCE_TENANT_URL}/api/v2/tokens/info" | jq '.scopes'
```

**Solutions:**

1. **Verify source has configurations:**
   - Log into source tenant Dynatrace UI
   - Navigate to specific configuration types
   - Verify dashboards, SLOs, alerts exist

2. **Check token scopes include `config.read`**

3. **Enable debug logging:**
   ```bash
   python3 scripts/python/migrate.py --dry-run
   # or
   bash -x ./scripts/bash/migrate.sh --dry-run
   ```

4. **Manually test Monaco download:**
   ```bash
   # Test Monaco directly
   monaco download \
     --environment source \
     --config-file config/environments.yaml \
     --output-folder test_output/
   ```

## Deployment Issues

### Deployment Failed

```
Error: Failed to deploy configuration to target
Configuration rejected by API
```

**Diagnosis:**
```bash
# Check deployment logs
tail -50 migration_*.log | grep -i error

# Review returned error details
# Look for specific configuration causing issue
```

**Common Causes:**

1. **Target already has conflicting configuration:**
   ```bash
   # Could be compatibility issue
   # Review dry-run output for conflicts
   python3 scripts/python/migrate.py --dry-run
   ```

2. **Target dependencies not met:**
   - Management zone referenced doesn't exist
   - Dashboard references deleted entity
   - Alert profile references missing channel

   **Solution:** Ensure target has all prerequisites, or migrate in dependency order

3. **API rate limiting:**
   - Initial deployment is slow
   - Large migrations may hit rate limits
   - Retry after waiting

   **Solution:**
   ```bash
   # Wait 5 minutes then retry
   sleep 300
   python3 scripts/python/migrate.py
   ```

### Backup Failed

```
Error: Failed to create backup of target configuration
```

**Solutions:**

1. **Verify target tenant access:**
   ```bash
   curl -H "Authorization: Api-Token $TARGET_TENANT_TOKEN" \
     "${TARGET_TENANT_URL}/api/v2/environments"
   ```

2. **Check target has configurations:**
   - Target may be empty (not an error)
   - Backup still fails if no config.read scope

3. **Skip backup with flag:**
   ```bash
   # If backup fails but you don't need it
   ./scripts/bash/migrate.sh --no-backup
   python3 scripts/python/migrate.py
   ```

## Performance Issues

### Migration Takes Too Long

```
Migration running for > 1 hour
Seems stuck
```

**Diagnosis:**
```bash
# Check if files are being downloaded
watch -n 5 'du -sh config/'

# Monitor Monaco process
ps aux | grep monaco

# Check for network issues
ping source-tenant-id.live.dynatrace.com
```

**Typical Timing:**
- Small tenant (< 100 configs): 5-15 minutes
- Medium tenant (100-500): 15-45 minutes
- Large tenant (500-1000+): 45-120+ minutes

**Solutions:**

1. **Run during off-peak hours:**
   - Reduces API throttling
   - Faster deployments

2. **Monitor logs:**
   ```bash
   tail -f migration_*.log
   # Should show progress: "Downloaded 50 configurations..." etc.
   ```

3. **Let it complete:**
   - Don't interrupt (no resume available)
   - Use `nohup` to keep running if disconnected
   ```bash
   nohup ./scripts/bash/migrate.sh &
   ```

### High Memory Usage

```
Memory: 90% used
Process: migration.sh using 4GB RAM
```

**Causes:**
- Monaco caching large configuration sets in memory
- Normal for very large tenants

**Solutions:**
```bash
# Monitor available memory
free -h

# Stop other applications
# Ensure 4GB+ available RAM

# Run in separate session
# Doesn't affect other users
```

### Disk Space Full

```
Error: No space left on device
write error: config/source/...
```

**Diagnosis:**
```bash
# Check available disk space
df -h

# See what's using space
du -sh config/
```

**Solutions:**

1. **Clean up old backups:**
   ```bash
   # Remove old backup directories
   rm -rf config/backups/20240308_*
   ```

2. **Compress existing backups:**
   ```bash
   tar -czf config/backups/20240308.tar.gz config/backups/20240308_*/
   rm -rf config/backups/20240308_*/
   ```

3. **Move to external storage:**
   ```bash
   mv config/backups/ /external/backup/location/
   ln -s /external/backup/location/backups config/backups
   ```

4. **Clean logs:**
   ```bash
   rm migration_*.log  # Keep only recent ones
   ```

## Post-Migration Verification Issues

### Configurations Don't Appear in Target

```
Migrated but target is empty
Settings > Configuration Management shows 0 items
```

**Diagnosis:**

1. **Check API access:**
   ```bash
   curl -H "Authorization: Api-Token $TARGET_TENANT_TOKEN" \
     "${TARGET_TENANT_URL}/api/v2/environments"
   ```

2. **Verify deployment actually ran:**
   ```bash
   tail -20 migration_*.log
   # Should show "Configuration deployed to target"
   ```

3. **Allow time for processing:**
   - Target processes deployed config asynchronously
   - May take 1-2 minutes to appear

**Solutions:**

1. **Wait and refresh:**
   ```bash
   # Wait 2-3 minutes
   sleep 180
   # Log into target UI and refresh
   ```

2. **Check deployment logs:**
   ```bash
   # Review last 100 lines
   tail -100 migration_*.log | grep -i "deploy\|error"
   ```

3. **Verify no silent failures:**
   ```bash
   # Run again in debug mode
   bash -x ./scripts/bash/migrate.sh
   # or
   python3 scripts/python/migrate.py --dry-run
   ```

### Configuration Count Mismatch

```
Source has 500 dashboards
Target shows only 450 after migration
```

**Causes:**
- Some configurations failed silently
- Duplicate named items consolidated
- Monaco skipped unsupported types

**Diagnosis:**

1. **Compare configurations:**
   ```bash
   # Count in source
   find config/source -name "*.json" | wc -l
   find config/source -name "*.yaml" | wc -l
   ```

2. **Check logs for errors:**
   ```bash
   grep -i "error\|failed\|skipped" migration_*.log
   ```

3. **Verify in target UI:**
   - Check each configuration type
   - Manual spot-check of key items

**Solutions:**

1. **Re-run migration:**
   - Idempotent - safe to repeat
   - Will complete missing items

2. **Check specific config types:**
   - Some types may have different names in UI
   - Check Settings > Configuration Management for all types

3. **Review Monaco documentation:**
   - Some configurations may not support full migration
   - Check Monaco changelog for limitations

## Getting Help

**If you can't resolve the issue:**

1. **Collect diagnostic information:**
   ```bash
   # OS and shell version
   uname -a
   bash --version
   
   # Monaco version
   monaco --version
   
   # Python version (if using Python script)
   python3 --version
   
   # Recent logs (with tokens redacted)
   tail -100 migration_*.log | sed 's/dt0c01\..*/dt0c01.REDACTED/g'
   ```

2. **Enable debug mode:**
   ```bash
   # Shell script
   bash -x ./scripts/bash/migrate.sh 2>&1 | tee debug.log
   
   # Python script
   python3 -u scripts/python/migrate.py 2>&1 | tee debug.log
   ```

3. **Check resources:**
   - Monaco GitHub Issues: https://github.com/Dynatrace/dynatrace-configuration-as-code/issues
   - Dynatrace Documentation: https://www.dynatrace.com/support/help/dynatrace-api
   - Migration logs in `migration_*.log` files

4. **Contact Dynatrace Support:**
   - Provide logs (with tokens redacted)
   - Describe what step failed
   - Include error messages
