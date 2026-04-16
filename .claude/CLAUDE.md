# Dynatrace Monaco Tools

**ALWAYS** ask clarifying questions and **ALWAYS** provide a plan **BEFORE** making changes to ensure the end result matches intent.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

Standalone tools for Dynatrace configuration management and migration using [Monaco CLI](https://github.com/Dynatrace/dynatrace-configuration-as-code). Provides production-ready scripts for full tenant migration, SaaS-to-SaaS configuration export, and reference examples. Built for Dynatrace administrators who need reliable, safe configuration migration between tenants.

**Last Updated:** 2026-04-16

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Runtime | Python 3.8+ / Bash 4.0+ / PowerShell 5.1+ | Cross-platform scripting, all major OS covered |
| CLI Tool | Monaco CLI v2.12+ | Official Dynatrace configuration-as-code tool |
| HTTP | requests 2.31+ | API calls to Dynatrace tenants |
| Config | PyYAML 6.0+ | Monaco environment configuration |
| Env Mgmt | python-dotenv 1.0+ | Secure credential management via .env files |
| Utilities | curl, jq | Shell-based API interaction and JSON processing |

## Architecture

See [architecture.md](architecture.md) for project structure, components, and data flow.

## Essential Commands

```bash
# Setup - Full Tenant Migration
cd monaco_migration/
cp config/.env.example .env
nano .env  # Add tenant URLs and tokens
source .env
pip install -r requirements.txt

# Run Migration (Python)
python3 scripts/python/migrate.py

# Run Migration (Bash)
bash scripts/bash/migrate.sh

# Run Migration (PowerShell - Windows)
.\scripts\powershell\migrate.ps1

# Run Migration - Dry Run
python3 scripts/python/migrate.py --dry-run

# SaaS-to-SaaS Export (Bash)
cd monaco_s2s_sua_migration/
export ENV_TOKEN="dt0c01.source_tenant.xxxxxxxxxxxx..."
./scripts/bash/s2s-export.sh abc12345

# SaaS-to-SaaS Export (Python)
python3 scripts/python/s2s-export.py abc12345

# SaaS-to-SaaS Export (PowerShell - Windows)
.\scripts\powershell\s2s-export.ps1 -TenantId abc12345
```

## Current Phase

Before starting work, check `.claude/phases/` for the active phase.
- Active Phase: See `PHASE-01-active.md` (or current phase)
- Track: Append decisions to `DECISIONS.md` as you go
- When Done: Rename to `PHASE-01-done.md`, create `PHASE-02-active.md`

Detailed phase management rules: @.claude/rules/core.md

## Rules

### Always active
@.claude/rules/core.md
@.claude/rules/development.md
@.claude/rules/testing.md
@.claude/rules/deployment.md
@.claude/rules/python.md

### Debugging & Troubleshooting
@.claude/rules/debugging.md
@.claude/rules/existing-code.md

## Skills

### Monaco CLI & Tenant Migration
@/Users/Shared/GitHub/PROJECTS/VisualCode-AI-Template/SKILLS/dynatrace-monaco/SKILL.md

## Decision Log

See `.claude/DECISIONS.md` to track architectural and technical decisions.
