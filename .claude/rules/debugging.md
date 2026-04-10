# Debugging & Troubleshooting

## Debug Strategies

### 1. Reproduce the Issue
- Get clear reproduction steps
- Test with `--dry-run` first to isolate config vs deployment issues
- Check if issue is environment-specific (macOS vs Linux, Bash version)

### 2. Gather Evidence
```bash
# Check Monaco version
monaco version

# Run with verbose output
python3 scripts/python/migrate.py --dry-run --verbose

# Check API connectivity
curl -s -o /dev/null -w "%{http_code}" "${SOURCE_TENANT_URL}/api/v1/config/clusterversion" -H "Authorization: Api-Token ${SOURCE_TENANT_TOKEN}"

# Validate YAML config
python3 -c "import yaml; yaml.safe_load(open('config/environments.yaml'))"
```

### 3. Narrow Down Scope
- Binary search: Is it a download issue or a deploy issue?
- Recent commits: Did this work before? (`git bisect`)
- Dependencies: Try updating Monaco CLI or Python packages

### 4. Check Documentation
- Package-specific `docs/TROUBLESHOOTING.md`
- Monaco CLI documentation and known issues
- Dynatrace API changelog for breaking changes

## Common Issues & Solutions

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| Monaco not found | `which monaco` returns nothing | Install and add to PATH |
| Token rejected | 401/403 from API | Check scopes match docs |
| Empty config download | No configs of that type | Verify source tenant has configs |
| YAML parse error | Malformed environments.yaml | Validate YAML syntax |
| Permission denied | Script not executable | `chmod +x scripts/*.sh` |
| Bash version too old | macOS default is 3.x | `brew install bash` |

## Debugging Tools

### Logging
- Python scripts log to `migration_*.log` with timestamps
- Set `LOG_LEVEL=DEBUG` for detailed output
- Never log API tokens or credentials

### Monaco CLI Debug
```bash
# Monaco verbose output
MONACO_LOG_LEVEL=debug monaco download ...

# Check Monaco config
monaco --help
```

## Reporting Issues

When filing a bug report, include:
1. Exact reproduction steps
2. Monaco CLI version (`monaco version`)
3. Python version (`python3 --version`)
4. OS and Bash version
5. Relevant log output (redact tokens)
6. Whether `--dry-run` succeeds or fails
