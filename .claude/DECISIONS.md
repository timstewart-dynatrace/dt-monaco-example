# Decisions

This file tracks all non-trivial technical decisions made during this project.

Use the format below. Log decisions **at the time** they're made, not retroactively.

---

## 2026-04-10 — Python/Shell/PowerShell Script Approach

**Chosen:** Provide Python, Bash, and PowerShell implementations for migration scripts
**Alternatives:** Python-only, Shell-only, Go CLI
**Why:** Maximizes accessibility across environments and platforms. Some production servers only have Bash; some teams prefer Python for its readability and error handling; Windows users need PowerShell without additional setup. All scripts share the same workflow and produce identical results.
**Trade-offs:** Three codepaths to maintain. Changes must be reflected in all implementations.
**Revisit if:** One implementation becomes significantly more popular, or maintenance burden grows.

---

## 2026-04-10 — Standalone Package Structure (No Monolithic CLI)

**Chosen:** Each tool (monaco_migration, monaco_s2s_sua_migration, monaco_examples) is a self-contained directory with its own docs, config, and scripts
**Alternatives:** Single unified CLI tool, shared library with sub-commands
**Why:** Users can copy just the directory they need without pulling the entire repository. Each package has different prerequisites and workflows. Reduces coupling and simplifies onboarding.
**Trade-offs:** Some code duplication between packages (e.g., s2s-export.sh exists in both monaco_s2s_sua_migration/ and monaco_examples/). No shared utility layer.
**Revisit if:** Significant shared logic emerges that would benefit from a common library, or if more than 5 packages exist.

---

## 2026-04-10 — Language-Specific Script Directories

**Chosen:** Organize scripts into `scripts/bash/`, `scripts/python/`, `scripts/powershell/` subdirectories within each package
**Alternatives:** Flat `scripts/` directory with all languages mixed together, language prefix in filenames (migrate-bash.sh, migrate-python.py)
**Why:** Clear separation makes it immediately obvious which scripts are available for each platform. Users on Windows navigate to `powershell/` without wading through Bash scripts. Each language directory can have its own README or dependencies if needed.
**Trade-offs:** Deeper directory nesting. Script paths in commands are longer (e.g., `scripts/python/migrate.py` vs `scripts/migrate.py`).
**Revisit if:** A language is dropped entirely, or if the nesting proves confusing to users.

---

## 2026-04-10 — Windows PowerShell 5.1 as Target (Not PowerShell 7)

**Chosen:** Target Windows PowerShell 5.1 which ships with Windows 10/11
**Alternatives:** PowerShell 7+ (cross-platform), PowerShell 7+ with Windows PowerShell fallback
**Why:** PowerShell 5.1 is pre-installed on all modern Windows systems -- zero setup required. PowerShell 7 would require users to install it separately, adding friction. Python already covers cross-platform needs.
**Trade-offs:** Cannot use PS 7+ features (`??` operator, `ForEach-Object -Parallel`, `Invoke-WebRequest -SkipHttpErrorCheck`). Must use `[Net.ServicePointManager]::SecurityProtocol` for TLS 1.2. `Compress-Archive` produces .zip instead of .tar.gz.
**Revisit if:** PowerShell 7 becomes pre-installed on Windows, or if PS 5.1 limitations block critical functionality.

---

## 2026-04-10 — Monaco CLI as External Dependency (Not Bundled)

**Chosen:** Require users to install Monaco CLI separately
**Alternatives:** Bundle Monaco binary, wrap Monaco in a Docker container
**Why:** Monaco is actively developed by Dynatrace. Bundling would create version drift and licensing concerns. Users likely already have Monaco installed or need the latest version.
**Trade-offs:** Additional setup step for users. Version compatibility must be documented.
**Revisit if:** Monaco introduces breaking CLI changes frequently, or if Docker-based deployment becomes the primary use case.
