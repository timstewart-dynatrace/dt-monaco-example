# Development Setup & Tech Stack

## Prerequisites

- Python 3.8+ (verify with `python3 --version`)
- Bash 4.0+ (verify with `bash --version`)
- Monaco CLI v2.12+ (verify with `monaco version`)
- curl and jq (for shell scripts)
- pip (included with Python)

## Initial Setup

### Full Tenant Migration
```bash
cd monaco_migration/
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp config/.env.example .env
nano .env  # Add your tenant URLs and tokens
```

### SaaS-to-SaaS Export
```bash
cd monaco_s2s_sua_migration/
# No Python dependencies -- shell script only
# Set environment variables directly
export ENV_TOKEN="dt0c01.your_tenant.token_here"
```

## Development Workflow

### Common Tasks

| Task | Command | Purpose |
|------|---------|---------|
| Run migration (Python) | `python3 scripts/python/migrate.py` | Full tenant migration |
| Run migration (Bash) | `bash scripts/bash/migrate.sh` | Full tenant migration |
| Run migration (PowerShell) | `.\scripts\powershell\migrate.ps1` | Full tenant migration |
| Dry run | `python3 scripts/python/migrate.py --dry-run` | Preview without changes |
| SaaS export (Bash) | `./scripts/bash/s2s-export.sh <tenant-id>` | Export SaaS config |
| SaaS export (Python) | `python3 scripts/python/s2s-export.py <tenant-id>` | Export SaaS config |
| SaaS export (PowerShell) | `.\scripts\powershell\s2s-export.ps1 -TenantId <id>` | Export SaaS config |
| Verify migration | `python3 scripts/python/verify_migration.py` | Post-migration validation |
| Run linter | `ruff check .` | Check Python code quality |
| Format code | `ruff format .` | Auto-format Python code |
| Type check | `mypy scripts/` | Static type analysis |
| Run tests | `pytest tests/ -v` | Run test suite |

## Tech Stack Overview

### Dependencies
- **requests** - HTTP client for Dynatrace API calls
- **PyYAML** - Parse Monaco environment configuration files
- **python-dotenv** - Load credentials from .env files securely

### Tools & Infrastructure
- **Monaco CLI** - Dynatrace configuration-as-code tool (download, deploy, validate)
- **curl/jq** - Shell-based API interaction and JSON processing
- **Linting** - ruff (Python)
- **Type Checking** - mypy (Python)
- **Testing** - pytest

## Project Structure Reference

```
dt-monaco-example/
├── monaco_migration/        # Full tenant migration (Python + Shell)
├── monaco_s2s_sua_migration/  # SaaS-to-SaaS export (Shell)
├── monaco_examples/         # Reference configurations
├── .claude/                 # AI assistant instructions
├── README.md                # User-facing overview
├── CHANGELOG.md             # Version history
└── .gitignore               # Git ignore rules
```

## Troubleshooting Setup

| Issue | Solution |
|-------|----------|
| `monaco: command not found` | Install Monaco CLI and add to PATH |
| `ModuleNotFoundError` | Activate venv; reinstall: `pip install -r requirements.txt` |
| `Invalid API token` | Check token scopes match requirements in docs |
| `Permission denied` on script | `chmod +x scripts/*.sh` |
| Shell script fails on macOS | Ensure Bash 4.0+ (`brew install bash`) |

## Environment Variables

Create `.env` from template or export directly:

| Variable | Purpose | Example |
|----------|---------|---------|
| `SOURCE_TENANT_URL` | Source Dynatrace tenant URL | `https://abc12345.live.dynatrace.com` |
| `SOURCE_TENANT_TOKEN` | Source tenant API token | `dt0c01.xxxx.yyyy` |
| `TARGET_TENANT_URL` | Target Dynatrace tenant URL | `https://def67890.live.dynatrace.com` |
| `TARGET_TENANT_TOKEN` | Target tenant API token | `dt0c01.xxxx.yyyy` |
| `ENV_TOKEN` | SaaS export token | `dt0c01.xxxx.yyyy` |
| `CONFIG_DIR` | Custom config directory (optional) | `./config` |
