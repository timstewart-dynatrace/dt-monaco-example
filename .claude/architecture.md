# Architecture

## Project Structure

```
dt-monaco-example/
├── monaco_migration/              # Full tenant configuration migration
│   ├── config/
│   │   ├── .env.example           # Environment variable template
│   │   └── environments.yaml      # Monaco environment configuration
│   ├── docs/
│   │   ├── FULL_TENANT_MIGRATION.md
│   │   └── TROUBLESHOOTING.md
│   └── scripts/
│       ├── bash/
│       │   └── migrate.sh         # Bash migration implementation
│       ├── python/
│       │   └── migrate.py         # Python migration implementation
│       └── powershell/
│           └── migrate.ps1        # PowerShell migration implementation
│
├── monaco_s2s_sua_migration/      # SaaS-to-SaaS configuration export
│   ├── docs/
│   │   └── S2S_EXPORT.md
│   ├── requirements.txt           # Python dependencies
│   └── scripts/
│       ├── bash/
│       │   └── s2s-export.sh      # Bash export script
│       ├── python/
│       │   └── s2s-export.py      # Python export script
│       └── powershell/
│           └── s2s-export.ps1     # PowerShell export script
│
├── monaco_examples/               # Reference configurations & examples
│   ├── config/
│   │   ├── .env.example
│   │   └── environments.yaml
│   └── scripts/
│       ├── bash/
│       │   ├── clone-config.sh
│       │   ├── migrate.sh
│       │   ├── s2s-export.sh
│       │   └── setup.sh
│       ├── python/
│       │   ├── clone-config.py
│       │   ├── migrate.py
│       │   ├── s2s-export.py
│       │   ├── setup.py
│       │   └── verify_migration.py
│       └── powershell/
│           ├── clone-config.ps1
│           ├── migrate.ps1
│           ├── s2s-export.ps1
│           ├── setup.ps1
│           └── verify_migration.ps1
│
├── .claude/                       # AI assistant instructions
│   ├── CLAUDE.md
│   ├── DECISIONS.md
│   ├── architecture.md
│   ├── settings.json
│   ├── phases/
│   └── rules/
│
├── README.md
├── CHANGELOG.md
└── .gitignore
```

## Key Components

```
Monaco Migration Tools (each with bash/, python/, powershell/ implementations)
  │
  ├── monaco_migration/
  │     ├── scripts/python/migrate.py    ← Python: argparse CLI, .env loading, logging
  │     ├── scripts/bash/migrate.sh      ← Bash: colored output, error handling
  │     └── scripts/powershell/migrate.ps1 ← PowerShell: Windows-native, .env support
  │           │
  │           ├── 1. Verify Prerequisites (Monaco CLI, tokens, connectivity)
  │           ├── 2. Backup Target Tenant (download current config)
  │           ├── 3. Download Source Config (monaco download)
  │           ├── 4. Validate Configuration (YAML checks, schema validation)
  │           └── 5. Deploy to Target (monaco deploy, with dry-run option)
  │
  ├── monaco_s2s_sua_migration/
  │     ├── scripts/bash/s2s-export.sh         ← Bash export
  │     ├── scripts/python/s2s-export.py       ← Python export
  │     └── scripts/powershell/s2s-export.ps1  ← PowerShell export
  │           │
  │           ├── 1. Validate inputs (tenant ID, token)
  │           ├── 2. Download Monaco binary (if needed)
  │           ├── 3. Export configuration (monaco download)
  │           └── 4. Package output for SaaS Upgrade Assistant
  │
  └── monaco_examples/
        └── scripts/bash|python|powershell/  ← Reference copies in all 3 languages
              └── verify_migration.*         ← Post-migration validation
```

## Data Flow

### Full Tenant Migration
```
Source Tenant → Monaco Download → Local YAML Config → Validation → Monaco Deploy → Target Tenant
                                                                        ↑
                                                              Backup of target
                                                              saved first
```

### SaaS-to-SaaS Export
```
Source SaaS Tenant → Monaco Download → Local Config Package → (Manual) Load into SaaS Upgrade Assistant
```

## Technology Decisions

See `DECISIONS.md` for why we chose:
- Dual Python/Shell implementations
- Standalone package structure
- Monaco CLI as external dependency
