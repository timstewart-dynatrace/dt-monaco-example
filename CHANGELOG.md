# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- PowerShell scripts for all tools (Windows PowerShell 5.1+ compatible)
- Python ports for all Bash-only scripts (s2s-export, clone-config, setup)
- Language-specific directory structure: `scripts/bash/`, `scripts/python/`, `scripts/powershell/`
- `requirements.txt` for `monaco_s2s_sua_migration` Python dependencies
- `.claude/` directory with AI assistant instructions following best practices
- `DECISIONS.md` for architectural decision tracking
- `CHANGELOG.md` following Keep a Changelog format

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
