# Reference Configurations & Examples

Sample configurations, project templates, and reference scripts for learning and testing Dynatrace Monaco tools.

## Scripts

All scripts are available in three languages:

```
scripts/
├── bash/                      # Bash scripts (macOS/Linux)
│   ├── clone-config.sh        # Clone config from a source tenant
│   ├── migrate.sh             # Full tenant migration
│   ├── s2s-export.sh          # SaaS-to-SaaS export
│   └── setup.sh               # Interactive setup wizard
├── python/                    # Python scripts (cross-platform)
│   ├── clone-config.py        # Clone config from a source tenant
│   ├── migrate.py             # Full tenant migration
│   ├── s2s-export.py          # SaaS-to-SaaS export
│   ├── setup.py               # Interactive setup wizard
│   └── verify_migration.py    # Post-migration verification
└── powershell/                # PowerShell scripts (Windows)
    ├── clone-config.ps1       # Clone config from a source tenant
    ├── migrate.ps1            # Full tenant migration
    ├── s2s-export.ps1         # SaaS-to-SaaS export
    ├── setup.ps1              # Interactive setup wizard
    └── verify_migration.ps1   # Post-migration verification
```

## Quick Start

### Setup Wizard

The setup wizard checks dependencies, collects configuration, and verifies connectivity:

**Bash:**
```bash
./scripts/bash/setup.sh
```

**Python:**
```bash
pip install -r requirements.txt
python3 scripts/python/setup.py
```

**PowerShell:**
```powershell
.\scripts\powershell\setup.ps1
```

### Clone Configuration

Download configuration from a source tenant for review or modification:

**Bash:**
```bash
./scripts/bash/clone-config.sh https://tenant.live.dynatrace.com your_token
```

**Python:**
```bash
python3 scripts/python/clone-config.py https://tenant.live.dynatrace.com your_token
```

**PowerShell:**
```powershell
.\scripts\powershell\clone-config.ps1 -SourceUrl "https://tenant.live.dynatrace.com" -SourceToken "your_token"
```

### Verify Migration

Compare configuration counts between source and target tenants:

**Python:**
```bash
source .env
python3 scripts/python/verify_migration.py
```

**PowerShell:**
```powershell
.\scripts\powershell\verify_migration.ps1
```

## Prerequisites

- **Monaco CLI** - [Installation guide](https://github.com/Dynatrace/dynatrace-configuration-as-code/releases)
- **Python 3.8+** (for Python scripts) with `pip install -r requirements.txt`
- **Bash 4.0+** (for Bash scripts)
- **Windows PowerShell 5.1+** (for PowerShell scripts, ships with Windows 10/11)
- Valid Dynatrace API tokens

## Related

- [monaco_migration/](../monaco_migration/) - Production-ready full tenant migration
- [monaco_s2s_sua_migration/](../monaco_s2s_sua_migration/) - Production-ready SaaS-to-SaaS export
