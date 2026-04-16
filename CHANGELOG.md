# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-16

### Fixed
- fix(security): revoke generated Monaco API tokens after s2s-export completes (all languages)
- fix(bash): typo `mongo_checksum` preventing cleanup of checksum file in s2s-export
- fix(python): `Path` object passed to `subprocess.run` breaking on Python 3.8
- fix(bash): replace `eval` with array execution in all migration scripts (injection hardening)
- fix(bash): quote `$(uname)` command substitutions in s2s-export scripts
- fix(bash): argument count check now allows optional second argument in s2s-export
- fix(bash): add `--config-types` and `--list-types` to production migrate.sh (feature parity with Python)
- fix(python): return type hint `-> None` corrected to `-> int` in verify_migration.py
- fix(bash): update stale Monaco v1 repo URLs to current Dynatrace/dynatrace-configuration-as-code
- fix(python): remove unused imports (`json`, `Dict`, `datetime`, `os`) across scripts
- fix(python): narrow `except Exception` to `except requests.exceptions.RequestException`
- fix(powershell): rename `$args` to `$monacoArgs` to avoid automatic variable shadowing
- fix(powershell): enhance YAML validation to check for key-value structure
- fix(bash): remove incorrect `java` dependency check from setup wizard
- fix(docs): remove ~75 lines of duplicate/orphaned content from root README
- fix(docs): add missing `pip install` step to root README Python quick-start
- fix(docs): update s2s package description to list all three languages
- fix(docs): normalize .env.example quoting format across packages
- fix(docs): update DECISIONS.md to reflect three-language (Python/Bash/PowerShell) approach
- fix(docs): add missing `requirements.txt` to architecture.md for monaco_examples
- fix(docs): update .claude/CLAUDE.md "Last Updated" date

## [0.2.0] - 2026-04-16

### Added
- PowerShell scripts for all tools (Windows PowerShell 5.1+ compatible)
- Python ports for all Bash-only scripts (s2s-export, clone-config, setup)
- Language-specific directory structure: `scripts/bash/`, `scripts/python/`, `scripts/powershell/`
- `requirements.txt` for `monaco_s2s_sua_migration` Python dependencies
- `.claude/` directory with AI assistant instructions following best practices
- `DECISIONS.md` for architectural decision tracking
- `CHANGELOG.md` following Keep a Changelog format
- Reference to `dynatrace-monaco` skill from SKILLS library

### Changed
- Reorganized all scripts from flat `scripts/` into `scripts/{bash,python,powershell}/` subdirectories
- Updated all README files with multi-platform usage examples
- Updated root README with Python, Bash, and PowerShell quick-start examples

## [0.1.0] - 2026-04-10

### Added
- Full tenant migration package (`monaco_migration/`) with Python and Shell implementations
- SaaS-to-SaaS configuration export package (`monaco_s2s_sua_migration/`)
- Reference configurations and examples (`monaco_examples/`)
- Automatic backup before migration
- Dry-run mode for previewing changes
- Configuration validation before deployment
- Comprehensive documentation for each package (README, guides, troubleshooting)
