<#
.SYNOPSIS
    Clone and prepare Monaco configuration from a source tenant.

.DESCRIPTION
    Downloads configuration using Monaco CLI and prepares it for deployment
    to a target tenant.

.PARAMETER SourceUrl
    Source Dynatrace tenant URL

.PARAMETER SourceToken
    Source tenant API token

.PARAMETER ConfigTypes
    Comma-separated list of config types (optional)

.EXAMPLE
    .\clone-config.ps1 -SourceUrl "https://tenant.live.dynatrace.com" -SourceToken "token_xyz"

.EXAMPLE
    .\clone-config.ps1 -SourceUrl "https://tenant.live.dynatrace.com" -SourceToken "token_xyz" -ConfigTypes "dashboard,alerting-profiles"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceUrl,

    [Parameter(Mandatory = $true)]
    [string]$SourceToken,

    [string]$ConfigTypes = ""
)

$ErrorActionPreference = "Stop"

function Write-LogInfo { param([string]$Message); Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Message }
function Write-LogSuccess { param([string]$Message); Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-LogError { param([string]$Message); Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $Message }

# Remove trailing slash
$SourceUrl = $SourceUrl.TrimEnd("/")

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDir = Join-Path "config" "cloned-$timestamp"

Write-LogInfo "Cloning configuration from $SourceUrl"
Write-LogInfo "Output directory: $outputDir"

# Verify Monaco is installed
$monacoCmd = Get-Command "monaco" -ErrorAction SilentlyContinue
if (-not $monacoCmd) { $monacoCmd = Get-Command "monaco.exe" -ErrorAction SilentlyContinue }
if (-not $monacoCmd) {
    Write-LogError "Monaco CLI not found. Install with:"
    Write-LogError "  Invoke-WebRequest -URI https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-windows-amd64.exe -OutFile monaco.exe"
    exit 1
}

# Create environments config
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$envFile = Join-Path $outputDir "environments.yaml"

@"
environments:
  source:
    name: source
    url: $SourceUrl
    token: $SourceToken
"@ | Set-Content -Path $envFile -Encoding UTF8

# Build monaco command arguments
$monacoArgs = @(
    "download",
    "--environment", "source",
    "--config-file", $envFile,
    "--output-folder", $outputDir
)

if ($ConfigTypes) {
    foreach ($type in ($ConfigTypes -split ",")) {
        $type = $type.Trim()
        if ($type) {
            $monacoArgs += "--config-type"
            $monacoArgs += $type
        }
    }
}

Write-LogInfo "Running: monaco $($monacoArgs -join ' ')"

$output = & monaco @monacoArgs 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-LogSuccess "Configuration cloned successfully"
    Write-LogInfo "Location: $(Resolve-Path $outputDir)"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Review the configuration: Get-ChildItem $outputDir"
    Write-Host "2. Customize as needed"
    Write-Host "3. Deploy with: monaco deploy --environment target --config-file $envFile $outputDir"
}
else {
    Write-LogError "Failed to clone configuration"
    Write-LogError ($output | Out-String)
    exit 1
}
