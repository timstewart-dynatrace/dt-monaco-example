<#
.SYNOPSIS
    Dynatrace Monaco Full Tenant Configuration Migration Script

.DESCRIPTION
    Performs a complete migration of all configurations from a source
    tenant to a target tenant using Monaco, including backup and validation.

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
    # Using environment variables
    $env:SOURCE_TENANT_URL = "https://source.live.dynatrace.com"
    $env:SOURCE_TENANT_TOKEN = "your_token"
    $env:TARGET_TENANT_URL = "https://target.live.dynatrace.com"
    $env:TARGET_TENANT_TOKEN = "your_token"
    .\migrate.ps1

.EXAMPLE
    # Using parameters
    .\migrate.ps1 `
        -SourceUrl "https://source.live.dynatrace.com" `
        -TargetUrl "https://target.live.dynatrace.com" `
        -SourceToken "YOUR_TOKEN" `
        -TargetToken "YOUR_TOKEN"

.EXAMPLE
    # Dry run
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

# --- Logging functions ---

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# --- Log file setup ---

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "migration_$Timestamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Level - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
}

# --- Load .env file if present ---

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
    Write-Log "Checking Monaco installation..."

    $monacoCmd = Get-Command "monaco" -ErrorAction SilentlyContinue
    if (-not $monacoCmd) {
        $monacoCmd = Get-Command "monaco.exe" -ErrorAction SilentlyContinue
    }

    if (-not $monacoCmd) {
        Write-LogError "Monaco CLI not found"
        Write-LogError "Please install Monaco first:"
        Write-LogError "  Invoke-WebRequest -URI https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-windows-amd64.exe -OutFile monaco.exe"
        Write-Log "Monaco CLI not found" "ERROR"
        return $false
    }

    try {
        $version = & monaco --version 2>&1
        Write-LogSuccess "Monaco found: $version"
        Write-Log "Monaco found: $version"
        return $true
    }
    catch {
        Write-LogError "Error checking Monaco version: $_"
        Write-Log "Error checking Monaco version: $_" "ERROR"
        return $false
    }
}

function Test-TenantConnection {
    param(
        [string]$Url,
        [string]$Token,
        [string]$TenantName
    )

    Write-LogInfo "Verifying connection to $TenantName tenant..."
    Write-Log "Verifying connection to $TenantName tenant at $Url"

    try {
        $headers = @{ "Authorization" = "Api-Token $Token" }
        $response = Invoke-RestMethod -Uri "$Url/api/v2/environments" -Headers $headers -Method Get -TimeoutSec 10
        Write-LogSuccess "$TenantName tenant connection verified"
        Write-Log "$TenantName tenant connection verified"
        return $true
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        Write-LogError "$TenantName tenant returned status $statusCode"
        Write-Log "$TenantName tenant connection failed: $_" "ERROR"
        return $false
    }
}

function New-EnvironmentsYaml {
    Write-LogInfo "Creating environments.yaml..."
    Write-Log "Creating environments.yaml"

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    $envFile = Join-Path $ConfigDir "environments.yaml"
    $content = @"
environments:
  source:
    name: source
    url: $SourceUrl
    token: $SourceToken

  target:
    name: target
    url: $TargetUrl
    token: $TargetToken
"@

    Set-Content -Path $envFile -Value $content -Encoding UTF8
    Write-LogSuccess "Created: $envFile"
    Write-Log "Created: $envFile"
}

function Invoke-DownloadConfiguration {
    param(
        [string]$Environment,
        [string]$TargetDir
    )

    Write-LogInfo "Downloading configuration from $Environment environment..."
    Write-Log "Downloading configuration from $Environment"

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $envFile = Join-Path $ConfigDir "environments.yaml"
    $monacoArgs = @("download", "--environment", $Environment, "--config-file", $envFile, "--output-folder", $TargetDir)

    Write-LogInfo "Running: monaco $($monacoArgs -join ' ')"

    try {
        $output = & monaco @monacoArgs 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-LogSuccess "Configuration downloaded from $Environment"
            Write-Log "Configuration downloaded from $Environment"
            return $true
        }
        else {
            Write-LogError "Error downloading configuration: $output"
            Write-Log "Error downloading configuration: $output" "ERROR"
            return $false
        }
    }
    catch {
        Write-LogError "Exception during download: $_"
        Write-Log "Exception during download: $_" "ERROR"
        return $false
    }
}

function Test-Configuration {
    param([string]$Path)

    Write-LogInfo "Validating configuration files..."
    Write-Log "Validating configuration in $Path"

    $yamlFiles = Get-ChildItem -Path $Path -Recurse -Include "*.yaml", "*.yml" -ErrorAction SilentlyContinue
    if (-not $yamlFiles -or $yamlFiles.Count -eq 0) {
        Write-LogWarning "No configuration files found in $Path"
        Write-Log "No configuration files found in $Path" "WARN"
        return $true
    }

    foreach ($file in $yamlFiles) {
        try {
            # Basic YAML validation: check for common syntax issues
            $content = Get-Content $file.FullName -Raw
            if ([string]::IsNullOrWhiteSpace($content)) {
                Write-LogWarning "Empty file: $($file.Name)"
                continue
            }
            # Check for tab characters (invalid in YAML)
            if ($content -match "`t") {
                Write-LogError "Invalid YAML (contains tabs): $($file.FullName)"
                Write-Log "Invalid YAML (tabs) in $($file.FullName)" "ERROR"
                return $false
            }
            # Check for basic key-value structure (at least one "key: value" line)
            $nonCommentLines = ($content -split "`n") | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") }
            if ($nonCommentLines.Count -gt 0) {
                $hasKeyValue = $nonCommentLines | Where-Object { $_ -match "^\s*[\w.-]+\s*:" }
                if (-not $hasKeyValue) {
                    Write-LogError "Invalid YAML (no key-value pairs found): $($file.FullName)"
                    Write-Log "Invalid YAML (structure) in $($file.FullName)" "ERROR"
                    return $false
                }
            }
            Write-LogInfo "  Valid: $($file.Name)"
        }
        catch {
            Write-LogError "Error reading $($file.FullName): $_"
            Write-Log "Error reading $($file.FullName): $_" "ERROR"
            return $false
        }
    }

    Write-LogSuccess "Configuration validation passed"
    Write-Log "Configuration validation passed"
    return $true
}

function Invoke-DeployConfiguration {
    param(
        [string]$Path,
        [string]$Environment
    )

    Write-LogInfo "Deploying configuration to $Environment environment..."
    Write-Log "Deploying configuration to $Environment"

    if ($DryRun) {
        Write-LogInfo "[DRY RUN] Configuration would be deployed (not actually deploying)"
        Write-Log "[DRY RUN] Skipping deployment"
        return $true
    }

    $envFile = Join-Path $ConfigDir "environments.yaml"
    $monacoArgs = @("deploy", "--environment", $Environment, "--config-file", $envFile, $Path)

    Write-LogInfo "Running: monaco $($monacoArgs -join ' ')"

    try {
        $output = & monaco @monacoArgs 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-LogSuccess "Configuration deployed to $Environment"
            Write-Log "Configuration deployed to $Environment"
            return $true
        }
        else {
            Write-LogError "Error deploying configuration: $output"
            Write-Log "Error deploying configuration: $output" "ERROR"
            return $false
        }
    }
    catch {
        Write-LogError "Exception during deployment: $_"
        Write-Log "Exception during deployment: $_" "ERROR"
        return $false
    }
}

function Backup-TargetConfiguration {
    $backupDir = Join-Path $ConfigDir "backups" $Timestamp

    Write-LogInfo "Creating backup of target configuration..."
    Write-Log "Creating backup at $backupDir"

    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $result = Invoke-DownloadConfiguration -Environment "target" -TargetDir $backupDir
    if ($result) {
        Write-LogSuccess "Backup created at: $backupDir"
        Write-Log "Backup created at: $backupDir"
    }
    else {
        Write-LogWarning "Failed to create backup (continuing with migration)"
        Write-Log "Backup failed, continuing" "WARN"
    }
    return $backupDir
}

# --- Main execution ---

function Start-Migration {
    Write-LogInfo "========================================="
    Write-LogInfo "Dynatrace Full Tenant Migration"
    Write-LogInfo "========================================="
    Write-Log "Starting migration"

    # Load .env if present
    Import-EnvFile

    # Re-read env vars after loading .env (in case they were set there)
    if (-not $SourceUrl) { $script:SourceUrl = $env:SOURCE_TENANT_URL }
    if (-not $TargetUrl) { $script:TargetUrl = $env:TARGET_TENANT_URL }
    if (-not $SourceToken) { $script:SourceToken = $env:SOURCE_TENANT_TOKEN }
    if (-not $TargetToken) { $script:TargetToken = $env:TARGET_TENANT_TOKEN }

    # Validate required parameters
    if (-not $SourceUrl -or -not $TargetUrl -or -not $SourceToken -or -not $TargetToken) {
        Write-LogError "Missing required parameters"
        Write-LogError "Required: SourceUrl, TargetUrl, SourceToken, TargetToken"
        Write-LogError "Set via parameters, environment variables, or .env file"
        Write-Log "Missing required parameters" "ERROR"
        exit 1
    }

    # Trim trailing slashes
    $script:SourceUrl = $SourceUrl.TrimEnd("/")
    $script:TargetUrl = $TargetUrl.TrimEnd("/")

    if ($DryRun) {
        Write-LogWarning "[DRY RUN MODE] No changes will be applied"
        Write-Log "[DRY RUN MODE]"
    }

    # Step 1: Verify Monaco installation
    if (-not (Test-MonacoInstalled)) {
        exit 1
    }

    # Step 2: Create environments configuration
    New-EnvironmentsYaml

    # Step 3: Verify API connections
    if (-not (Test-TenantConnection -Url $SourceUrl -Token $SourceToken -TenantName "source")) {
        exit 1
    }
    if (-not (Test-TenantConnection -Url $TargetUrl -Token $TargetToken -TenantName "target")) {
        exit 1
    }
    Write-LogSuccess "API connections verified"

    # Step 4: Backup target configuration
    $backupDir = $null
    if (-not $NoBackup -and -not $DryRun) {
        $backupDir = Backup-TargetConfiguration
    }

    # Step 5: Download source configuration
    $sourceConfigDir = Join-Path $ConfigDir "source"
    if (-not (Invoke-DownloadConfiguration -Environment "source" -TargetDir $sourceConfigDir)) {
        exit 1
    }

    # Step 6: Validate configuration
    if (-not (Test-Configuration -Path $sourceConfigDir)) {
        Write-LogError "Configuration validation failed"
        Write-Log "Validation failed" "ERROR"
        exit 1
    }

    # Step 7: Deploy to target
    if (-not (Invoke-DeployConfiguration -Path $sourceConfigDir -Environment "target")) {
        exit 1
    }

    Write-LogInfo "========================================="
    Write-LogSuccess "Migration completed successfully!"
    Write-LogInfo "========================================="
    Write-Log "Migration completed successfully"

    if ($backupDir) {
        Write-LogSuccess "Backup available at: $backupDir"
    }

    Write-LogInfo "Log file: $LogFile"
}

Start-Migration
