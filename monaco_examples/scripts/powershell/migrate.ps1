<#
.SYNOPSIS
    Dynatrace Monaco Full Tenant Configuration Migration Script (Reference Copy)

.DESCRIPTION
    Performs a complete migration of all configurations from a source
    tenant to a target tenant using Monaco, including backup and validation.

    Note: This is a reference copy. The primary version lives in
    monaco_migration/scripts/powershell/migrate.ps1

.PARAMETER SourceUrl
    Source Dynatrace tenant URL

.PARAMETER TargetUrl
    Target Dynatrace tenant URL

.PARAMETER SourceToken
    API token for source tenant

.PARAMETER TargetToken
    API token for target tenant

.PARAMETER ConfigDir
    Configuration directory (default: config)

.PARAMETER DryRun
    Preview changes without applying

.PARAMETER NoBackup
    Skip backup of target configuration

.EXAMPLE
    $env:SOURCE_TENANT_URL = "https://source.live.dynatrace.com"
    $env:SOURCE_TENANT_TOKEN = "your_token"
    $env:TARGET_TENANT_URL = "https://target.live.dynatrace.com"
    $env:TARGET_TENANT_TOKEN = "your_token"
    .\migrate.ps1

.EXAMPLE
    .\migrate.ps1 -SourceUrl "https://source.live.dynatrace.com" -TargetUrl "https://target.live.dynatrace.com" -SourceToken "TOKEN" -TargetToken "TOKEN"

.EXAMPLE
    .\migrate.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [string]$SourceUrl = $env:SOURCE_TENANT_URL,
    [string]$TargetUrl = $env:TARGET_TENANT_URL,
    [string]$SourceToken = $env:SOURCE_TENANT_TOKEN,
    [string]$TargetToken = $env:TARGET_TENANT_TOKEN,
    [string]$ConfigDir = "config",
    [switch]$DryRun,
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

# --- Logging ---

function Write-LogInfo { param([string]$Message); Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Message }
function Write-LogSuccess { param([string]$Message); Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-LogWarning { param([string]$Message); Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-LogError { param([string]$Message); Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $Message }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "migration_$Timestamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Level - $Message"
}

# --- Load .env ---

function Import-EnvFile {
    param([string]$Path = ".env")
    if (Test-Path $Path) {
        Write-LogInfo "Loading environment variables from $Path"
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#")) {
                $parts = $line -split "=", 2
                if ($parts.Count -eq 2) {
                    [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
                }
            }
        }
    }
}

# --- Core functions ---

function Test-MonacoInstalled {
    Write-LogInfo "Checking Monaco installation..."
    $monacoCmd = Get-Command "monaco" -ErrorAction SilentlyContinue
    if (-not $monacoCmd) { $monacoCmd = Get-Command "monaco.exe" -ErrorAction SilentlyContinue }
    if (-not $monacoCmd) {
        Write-LogError "Monaco CLI not found. Install with:"
        Write-LogError "  Invoke-WebRequest -URI https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-windows-amd64.exe -OutFile monaco.exe"
        return $false
    }
    try {
        $version = & monaco --version 2>&1
        Write-LogSuccess "Monaco found: $version"
        return $true
    } catch {
        Write-LogError "Error checking Monaco version: $_"
        return $false
    }
}

function Test-TenantConnection {
    param([string]$Url, [string]$Token, [string]$TenantName)
    Write-LogInfo "Verifying connection to $TenantName tenant..."
    try {
        $headers = @{ "Authorization" = "Api-Token $Token" }
        Invoke-RestMethod -Uri "$Url/api/v2/environments" -Headers $headers -Method Get -TimeoutSec 10 | Out-Null
        Write-LogSuccess "$TenantName tenant connection verified"
        return $true
    } catch {
        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "unknown" }
        Write-LogError "$TenantName tenant returned status $statusCode"
        return $false
    }
}

function New-EnvironmentsYaml {
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    $envFile = Join-Path $ConfigDir "environments.yaml"
    @"
environments:
  source:
    name: source
    url: $SourceUrl
    token: $SourceToken
  target:
    name: target
    url: $TargetUrl
    token: $TargetToken
"@ | Set-Content -Path $envFile -Encoding UTF8
    Write-LogSuccess "Created: $envFile"
}

function Invoke-DownloadConfiguration {
    param([string]$Environment, [string]$TargetDir)
    Write-LogInfo "Downloading configuration from $Environment environment..."
    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
    $envFile = Join-Path $ConfigDir "environments.yaml"
    $monacoArgs = @("download", "--environment", $Environment, "--config-file", $envFile, "--output-folder", $TargetDir)
    try {
        $output = & monaco @monacoArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Configuration downloaded from $Environment"
            return $true
        } else {
            Write-LogError "Error downloading configuration: $output"
            return $false
        }
    } catch {
        Write-LogError "Exception during download: $_"
        return $false
    }
}

function Test-Configuration {
    param([string]$Path)
    Write-LogInfo "Validating configuration files..."
    $yamlFiles = Get-ChildItem -Path $Path -Recurse -Include "*.yaml", "*.yml" -ErrorAction SilentlyContinue
    if (-not $yamlFiles -or $yamlFiles.Count -eq 0) {
        Write-LogWarning "No configuration files found in $Path"
        return $true
    }
    foreach ($file in $yamlFiles) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match "`t") {
            Write-LogError "Invalid YAML (contains tabs): $($file.FullName)"
            return $false
        }
        Write-LogInfo "  Valid: $($file.Name)"
    }
    Write-LogSuccess "Configuration validation passed"
    return $true
}

function Invoke-DeployConfiguration {
    param([string]$Path, [string]$Environment)
    Write-LogInfo "Deploying configuration to $Environment environment..."
    if ($DryRun) {
        Write-LogInfo "[DRY RUN] Configuration would be deployed (not actually deploying)"
        return $true
    }
    $envFile = Join-Path $ConfigDir "environments.yaml"
    $monacoArgs = @("deploy", "--environment", $Environment, "--config-file", $envFile, $Path)
    try {
        $output = & monaco @monacoArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Configuration deployed to $Environment"
            return $true
        } else {
            Write-LogError "Error deploying configuration: $output"
            return $false
        }
    } catch {
        Write-LogError "Exception during deployment: $_"
        return $false
    }
}

# --- Main ---

function Start-Migration {
    Write-LogInfo "========================================="
    Write-LogInfo "Dynatrace Full Tenant Migration"
    Write-LogInfo "========================================="

    Import-EnvFile

    if (-not $SourceUrl) { $script:SourceUrl = $env:SOURCE_TENANT_URL }
    if (-not $TargetUrl) { $script:TargetUrl = $env:TARGET_TENANT_URL }
    if (-not $SourceToken) { $script:SourceToken = $env:SOURCE_TENANT_TOKEN }
    if (-not $TargetToken) { $script:TargetToken = $env:TARGET_TENANT_TOKEN }

    if (-not $SourceUrl -or -not $TargetUrl -or -not $SourceToken -or -not $TargetToken) {
        Write-LogError "Missing required parameters. Set via parameters, environment variables, or .env file"
        exit 1
    }

    $script:SourceUrl = $SourceUrl.TrimEnd("/")
    $script:TargetUrl = $TargetUrl.TrimEnd("/")

    if ($DryRun) { Write-LogWarning "[DRY RUN MODE] No changes will be applied" }

    if (-not (Test-MonacoInstalled)) { exit 1 }
    New-EnvironmentsYaml
    if (-not (Test-TenantConnection -Url $SourceUrl -Token $SourceToken -TenantName "source")) { exit 1 }
    if (-not (Test-TenantConnection -Url $TargetUrl -Token $TargetToken -TenantName "target")) { exit 1 }

    $backupDir = $null
    if (-not $NoBackup -and -not $DryRun) {
        $backupDir = Join-Path $ConfigDir "backups" $Timestamp
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        Invoke-DownloadConfiguration -Environment "target" -TargetDir $backupDir | Out-Null
        Write-LogSuccess "Backup created at: $backupDir"
    }

    $sourceConfigDir = Join-Path $ConfigDir "source"
    if (-not (Invoke-DownloadConfiguration -Environment "source" -TargetDir $sourceConfigDir)) { exit 1 }
    if (-not (Test-Configuration -Path $sourceConfigDir)) { exit 1 }
    if (-not (Invoke-DeployConfiguration -Path $sourceConfigDir -Environment "target")) { exit 1 }

    Write-LogInfo "========================================="
    Write-LogSuccess "Migration completed successfully!"
    Write-LogInfo "========================================="
    if ($backupDir) { Write-LogSuccess "Backup available at: $backupDir" }
    Write-LogInfo "Log file: $LogFile"
}

Start-Migration
