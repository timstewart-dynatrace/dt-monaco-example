# Dynatrace Monaco Tools

Complete standalone tools for Dynatrace configuration management and migration using [Monaco CLI](https://github.com/Dynatrace/dynatrace-configuration-as-code).

## What's Included

### 📦 **monaco_migration/**
**Full Tenant Configuration Migration**

Complete migration of all configurations from one Dynatrace tenant to another. Ideal for:
- Consolidating multiple tenants
- Environment promotion (dev → staging → production)
- Tenant upgrades or migrations
- Disaster recovery

**Includes:** Python & shell scripts, migration guide, troubleshooting, automatic backup

👉 **[See monaco_migration/README.md](monaco_migration/README.md)**

---

### 📦 **monaco_s2s_sua_migration/**
**SaaS-to-SaaS Configuration Migration**

Export and migrate configurations between Dynatrace SaaS tenants. Ideal for:
- Cross-tenant SaaS configuration migration
- Configuration backup and replication
- Configuration evaluation before migration
- Batch migration of multiple SaaS environments

**Includes:** Shell script for export, complete usage guide, troubleshooting

👉 **[See monaco_s2s_sua_migration/README.md](monaco_s2s_sua_migration/README.md)**

---

### 📦 **monaco_examples/**
**Reference Configurations & Examples**

Sample configurations and project structures for learning and testing. Contains:
- Example configuration sets
- Project templates
- Integration examples

👉 **[See monaco_examples/README.md](monaco_examples/README.md)** (if available)

---

## Quick Start

Each package is **completely standalone**. Pick the one you need:

### Full Tenant Migration
```bash
cd monaco_migration/
cp config/.env.example .env
nano .env  # Add your tenant URLs and tokens
source .env
python3 scripts/migrate.py
```

### SaaS-to-SaaS Export
```bash
cd monaco_s2s_sua_migration/
export ENV_TOKEN="dt0c01.source_tenant.xxxxxxxxxxxx..."
./scripts/s2s-export.sh abc12345
```

### View Examples
```bash
cd monaco_examples/
# Browse example configurations
```

---

## Prerequisites

All tools require:

- **Monaco CLI** - Download from https://github.com/Dynatrace/dynatrace-configuration-as-code/releases
  ```bash
  # Installation example (macOS)
  brew install dynatrace-oss/dynatrace/monaco
  ```

- **Dynatrace Tenant(s)** - With API access
- **Valid API Tokens** - With appropriate scopes (detailed in each tool's README)
- **Bash 4.0+** or **Python 3.8+** - Depending on which script you use

### System Requirements

| Tool | Requires |
|------|----------|
| **monaco_migration** | Python 3.8+ or Bash 4.0+ |
| **monaco_s2s_sua_migration** | Bash 4.0+ |
| **monaco_examples** | None (reference only) |

---

## Documentation

Each package contains complete standalone documentation:

- **monaco_migration/**
  - `README.md` - Quick start
  - `docs/FULL_TENANT_MIGRATION.md` - Complete guide
  - `docs/TROUBLESHOOTING.md` - Q&A and issues

- **monaco_s2s_sua_migration/**
  - `README.md` - Quick start
  - `docs/S2S_EXPORT.md` - Complete guide with troubleshooting

---

## Selecting the Right Tool

| Need | Tool | Time | Scope |
|------|------|------|-------|
| SaaS → SaaS configuration migration | `monaco_s2s_sua_migration` + Monaco CLI | 5-30 min | Export + Deploy with Monaco |
| Migrate to new tenant | `monaco_migration` | 15-120 min | Full tenant copy |
| Learn / Reference | `monaco_examples` | — | Examples & templates |

---

## Key Features

### ✅ Safety First
- **Automatic backups** - Full versioning of target before changes
- **Dry-run mode** - Preview changes before applying
- **Validation** - YAML & configuration validation
- **Error handling** - Comprehensive error messages and recovery

### ✅ Flexible
- **Multiple options** - Python or Shell scripts
- **Configurable** - Environment variables or command-line args
- **Selective** - Choose specific config types or migrate all
- **Idempotent** - Safe to run multiple times

### ✅ Complete
- **Self-contained** - Each directory is standalone
- **Well-documented** - Guides and troubleshooting included
- **Production-ready** - Used in enterprise migrations
- **Accessible** - No steep learning curve

---

## Getting Help

1. **Start with the package README** - Quick start and basic usage
2. **Check package docs/** - Detailed guides and examples
3. **Review troubleshooting** - Common issues and solutions
4. **Check prerequisites** - Verify Monaco, tokens, access

### Support Resources

- [Monaco CLI GitHub](https://github.com/Dynatrace/dynatrace-configuration-as-code)
- [Dynatrace Configuration API](https://www.dynatrace.com/support/help/dynatrace-api)
- [API Token Management](https://www.dynatrace.com/support/help/how-to-use-dynatrace/user-management-and-security/access-management/api-tokens)

---

## License

These tools use Dynatrace Monaco CLI for configuration management.
See Monaco repository for licensing information.

---

## Next Steps

- 👉 Choose a tool above based on your use case
- 📖 Read the tool's README.md
- 🔑 Set up API tokens
- ⚙️ Configure your environment
- 🚀 Run the migration or export


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
