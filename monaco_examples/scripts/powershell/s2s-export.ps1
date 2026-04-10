<#
.SYNOPSIS
    Dynatrace SaaS-to-SaaS Configuration Export Script (Reference Copy)

.DESCRIPTION
    Exports Dynatrace SaaS tenant configurations for migration using Monaco CLI.
    Downloads Monaco binary, generates a scoped API token, exports all configurations,
    and packages them into an archive compatible with SaaS Upgrade Assistant.

    Note: This is a reference copy. The primary version lives in
    monaco_s2s_sua_migration/scripts/powershell/s2s-export.ps1

.PARAMETER TenantId
    Dynatrace tenant ID

.PARAMETER EnvUrlBase
    Environment URL base (default: live.dynatrace.com)

.EXAMPLE
    $env:ENV_TOKEN = "dt0c01.your_tenant.token_here"
    .\s2s-export.ps1 -TenantId abc12345
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TenantId,

    [string]$EnvUrlBase = "live.dynatrace.com"
)

$ErrorActionPreference = "Stop"

function Write-LogInfo { param([string]$Message); Write-Host "[INFO] " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-LogError { param([string]$Message); Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-LogWarning { param([string]$Message); Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }

$MonacoVersion = "2.12.0"
$TenantUrl = "https://$TenantId.$EnvUrlBase"
$MonacoBinary = "monaco.exe"

$MonacoTokenScopes = @(
    "attacks.read", "entities.read", "extensionConfigurations.read",
    "extensionEnvironment.read", "extensions.read", "geographicRegions.read",
    "javaScriptMappingFiles.read", "networkZones.read", "settings.read",
    "slo.read", "syntheticExecutions.read", "syntheticLocations.read",
    "DataExport", "DssFileManagement", "ExternalSyntheticIntegration",
    "ReadConfig", "ReadSyntheticData", "RumJavaScriptTagManagement"
)

function Remove-TempFiles {
    Write-LogInfo "Cleaning up temporary files..."
    foreach ($path in @($MonacoBinary, "manifest.yaml", "monaco_checksum")) {
        if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
    }
    if (Test-Path $TenantId) { Remove-Item $TenantId -Recurse -Force -ErrorAction SilentlyContinue }
}

# Validate ENV_TOKEN
$EnvToken = $env:ENV_TOKEN
if (-not $EnvToken) {
    Write-LogError "ENV_TOKEN environment variable is not set."
    exit 1
}

# Step 1: Download Monaco binary
$BinaryUrl = "https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/download/v$MonacoVersion/monaco-windows-amd64.exe"
$ChecksumUrl = "$BinaryUrl.sha256"

Write-LogInfo "Downloading Monaco v$MonacoVersion binary..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $BinaryUrl -OutFile $MonacoBinary -UseBasicParsing
} catch {
    Write-LogError "Failed to download Monaco binary: $($_.Exception.Message)"
    exit 1
}

Write-LogInfo "Downloading checksum..."
try {
    $checksumContent = (Invoke-WebRequest -Uri $ChecksumUrl -UseBasicParsing).Content
    if ($checksumContent -is [byte[]]) { $checksumContent = [System.Text.Encoding]::UTF8.GetString($checksumContent) }
    $expectedChecksum = ($checksumContent.Trim() -split "\s+")[0].ToLower()
} catch {
    Write-LogError "Failed to download checksum"
    Remove-TempFiles; exit 1
}

Write-LogInfo "Verifying checksum..."
$actualChecksum = (Get-FileHash -Path $MonacoBinary -Algorithm SHA256).Hash.ToLower()
if ($actualChecksum -ne $expectedChecksum) {
    Write-LogError "Checksum verification failed"
    Remove-TempFiles; exit 1
}
Write-LogInfo "Checksum verified."

# Step 2: Generate Monaco API token
Write-LogInfo "Generating Monaco API token..."
$tokenBody = @{ name = "rs-monaco-test"; scopes = $MonacoTokenScopes } | ConvertTo-Json
try {
    $tokenResponse = Invoke-RestMethod -Uri "$TenantUrl/api/v2/apiTokens" -Method Post `
        -Headers @{ "Authorization" = "Api-Token $EnvToken"; "Accept" = "application/json; charset=utf-8" } `
        -Body $tokenBody -ContentType "application/json; charset=utf-8"
    $MonacoToken = $tokenResponse.token
} catch {
    Write-LogError "Failed to generate Monaco API token: $($_.Exception.Message)"
    Remove-TempFiles; exit 1
}
if (-not $MonacoToken) { Write-LogError "Empty token returned"; Remove-TempFiles; exit 1 }
$env:MONACO_TOKEN = $MonacoToken
Write-LogInfo "Monaco token generated successfully."

# Step 3: Create manifest.yaml
@"
manifestVersion: 1.0

projects:
- name: saas
  path: saas/$TenantId

environmentGroups:
- name: saas
  environments:
  - name: $TenantId
    url:
      value: $TenantUrl
    auth:
      token:
        name: MONACO_TOKEN
"@ | Set-Content -Path "manifest.yaml" -Encoding UTF8

# Step 4: Run Monaco download
Write-LogInfo "Running Monaco to download configurations..."
$output = & ".\$MonacoBinary" download --environment $TenantId --output-folder $TenantId 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-LogError "Monaco download failed: $($output | Out-String)"
    Remove-TempFiles; exit 1
}
Write-LogInfo "Monaco download completed."

# Step 5: Package export
$datetime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$directoryName = "configurationExport-$datetime"
New-Item -ItemType Directory -Path $directoryName -Force | Out-Null

$currentTimestampMs = [long]([datetime]::UtcNow - [datetime]::new(1970, 1, 1)).TotalMilliseconds
@{
    clusterUuid = $TenantId; productVersion = "1.288.0.20240229-161733"
    monacoVersion = $MonacoVersion; exportTimestamp = $currentTimestampMs.ToString()
    environments = @(@{ name = $TenantId; uuid = $TenantId })
} | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $directoryName "exportMetadata.json") -Encoding UTF8

$exportSubdir = Join-Path $directoryName "export"
New-Item -ItemType Directory -Path $exportSubdir -Force | Out-Null
if (Test-Path $TenantId) {
    Get-ChildItem -Path $TenantId | ForEach-Object { Move-Item $_.FullName -Destination $exportSubdir -Force }
}

$archiveName = "$directoryName.zip"
Write-LogInfo "Archiving to $archiveName..."
Compress-Archive -Path $directoryName -DestinationPath $archiveName -Force
Write-LogInfo "Archive created: $archiveName"

# Step 6: Cleanup
Remove-TempFiles
Write-LogInfo "Export completed successfully!"
Write-LogInfo "Archive: $archiveName"
