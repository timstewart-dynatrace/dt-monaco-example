<#
.SYNOPSIS
    Dynatrace SaaS-to-SaaS Configuration Export Script

.DESCRIPTION
    Exports Dynatrace SaaS tenant configurations for migration using Monaco CLI.
    Downloads Monaco binary, generates a scoped API token, exports all configurations,
    and packages them into an archive compatible with SaaS Upgrade Assistant.

.PARAMETER TenantId
    Dynatrace tenant ID

.PARAMETER EnvUrlBase
    Environment URL base (default: live.dynatrace.com)

.EXAMPLE
    $env:ENV_TOKEN = "dt0c01.your_tenant.token_here"
    .\s2s-export.ps1 -TenantId abc12345

.EXAMPLE
    .\s2s-export.ps1 -TenantId abc12345 -EnvUrlBase managed.dynatrace.com
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TenantId,

    [string]$EnvUrlBase = "live.dynatrace.com"
)

$ErrorActionPreference = "Stop"

# --- Logging functions ---

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

# --- Configuration ---

$MonacoVersion = "2.12.0"
$TenantUrl = "https://$TenantId.$EnvUrlBase"
$MonacoBinary = "monaco.exe"

$MonacoTokenScopes = @(
    "attacks.read",
    "entities.read",
    "extensionConfigurations.read",
    "extensionEnvironment.read",
    "extensions.read",
    "geographicRegions.read",
    "javaScriptMappingFiles.read",
    "networkZones.read",
    "settings.read",
    "slo.read",
    "syntheticExecutions.read",
    "syntheticLocations.read",
    "DataExport",
    "DssFileManagement",
    "ExternalSyntheticIntegration",
    "ReadConfig",
    "ReadSyntheticData",
    "RumJavaScriptTagManagement"
)

# --- Cleanup trap ---

$tempFiles = @()

function Remove-TempFiles {
    Write-LogInfo "Cleaning up temporary files..."
    foreach ($path in @($MonacoBinary, "manifest.yaml", "monaco_checksum")) {
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }
    # Clean up tenant download directory
    if (Test-Path $TenantId) {
        Remove-Item $TenantId -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Validate environment ---

$EnvToken = $env:ENV_TOKEN
if (-not $EnvToken) {
    Write-LogError "ENV_TOKEN environment variable is not set."
    exit 1
}

# --- Step 1: Download Monaco binary ---

$BinaryUrl = "https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/download/v$MonacoVersion/monaco-windows-amd64.exe"
$ChecksumUrl = "$BinaryUrl.sha256"

Write-LogInfo "Downloading Monaco v$MonacoVersion binary..."

try {
    # Use TLS 1.2 (required for GitHub)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $BinaryUrl -OutFile $MonacoBinary -UseBasicParsing
}
catch {
    Write-LogError "Failed to download Monaco binary from $BinaryUrl"
    Write-LogError $_.Exception.Message
    exit 1
}

Write-LogInfo "Downloading checksum..."
try {
    $checksumContent = (Invoke-WebRequest -Uri $ChecksumUrl -UseBasicParsing).Content
    if ($checksumContent -is [byte[]]) {
        $checksumContent = [System.Text.Encoding]::UTF8.GetString($checksumContent)
    }
    $expectedChecksum = ($checksumContent.Trim() -split "\s+")[0]
}
catch {
    Write-LogError "Failed to download checksum from $ChecksumUrl"
    Remove-TempFiles
    exit 1
}

# Verify checksum
Write-LogInfo "Verifying checksum..."
$actualChecksum = (Get-FileHash -Path $MonacoBinary -Algorithm SHA256).Hash.ToLower()
$expectedChecksum = $expectedChecksum.ToLower()

if ($actualChecksum -ne $expectedChecksum) {
    Write-LogError "Checksum verification failed"
    Write-LogError "  Expected: $expectedChecksum"
    Write-LogError "  Actual:   $actualChecksum"
    Remove-TempFiles
    exit 1
}

Write-LogInfo "Checksum verified."

# --- Step 2: Generate Monaco API token ---

Write-LogInfo "Generating Monaco API token..."

$tokenHeaders = @{
    "Accept"        = "application/json; charset=utf-8"
    "Content-Type"  = "application/json; charset=utf-8"
    "Authorization" = "Api-Token $EnvToken"
}

$tokenBody = @{
    name   = "rs-monaco-test"
    scopes = $MonacoTokenScopes
} | ConvertTo-Json

try {
    $tokenResponse = Invoke-RestMethod -Uri "$TenantUrl/api/v2/apiTokens" `
        -Method Post `
        -Headers $tokenHeaders `
        -Body $tokenBody `
        -ContentType "application/json; charset=utf-8"

    $MonacoToken = $tokenResponse.token
    $MonacoTokenId = $tokenResponse.id
}
catch {
    Write-LogError "Failed to generate Monaco API token."
    Write-LogError $_.Exception.Message
    if ($_.ErrorDetails) {
        Write-LogWarning "Response: $($_.ErrorDetails.Message)"
    }
    Remove-TempFiles
    exit 1
}

if (-not $MonacoToken) {
    Write-LogError "Failed to generate Monaco API token (empty token returned)."
    Remove-TempFiles
    exit 1
}

$env:MONACO_TOKEN = $MonacoToken
Write-LogInfo "Monaco token generated successfully."

# --- Step 3: Create manifest.yaml ---

$manifestContent = @"
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
"@

Set-Content -Path "manifest.yaml" -Value $manifestContent -Encoding UTF8
Write-LogInfo "Created manifest.yaml"

# --- Step 4: Run Monaco download ---

Write-LogInfo "Running Monaco to download configurations..."

$monacoArgs = @("download", "--environment", $TenantId, "--output-folder", $TenantId)
$monacoResult = & ".\$MonacoBinary" @monacoArgs 2>&1
$monacoExitCode = $LASTEXITCODE

if ($monacoExitCode -ne 0) {
    Write-LogError "Monaco download failed:"
    Write-LogError ($monacoResult | Out-String)
    Remove-TempFiles
    exit 1
}

Write-LogInfo "Monaco download completed."

# --- Step 5: Package export ---

$datetime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$directoryName = "configurationExport-$datetime"

New-Item -ItemType Directory -Path $directoryName -Force | Out-Null

# Create SaaS Upgrade Assistant metadata
$currentTimestampMs = [long]([datetime]::UtcNow - [datetime]::new(1970, 1, 1)).TotalMilliseconds

$metadata = @{
    clusterUuid    = $TenantId
    productVersion = "1.288.0.20240229-161733"
    monacoVersion  = $MonacoVersion
    exportTimestamp = $currentTimestampMs.ToString()
    environments   = @(
        @{
            name = $TenantId
            uuid = $TenantId
        }
    )
} | ConvertTo-Json -Depth 3

Set-Content -Path (Join-Path $directoryName "exportMetadata.json") -Value $metadata -Encoding UTF8

# Move downloaded config into export subdirectory
$exportSubdir = Join-Path $directoryName "export"
New-Item -ItemType Directory -Path $exportSubdir -Force | Out-Null

if (Test-Path $TenantId) {
    Get-ChildItem -Path $TenantId | ForEach-Object {
        Move-Item $_.FullName -Destination $exportSubdir -Force
    }
}

# Create zip archive (PowerShell 5.1 does not have tar, use zip instead)
$archiveName = "$directoryName.zip"
Write-LogInfo "Archiving to $archiveName..."
Compress-Archive -Path $directoryName -DestinationPath $archiveName -Force
Write-LogInfo "Archive created: $archiveName"

# --- Step 6: Revoke token and cleanup ---

if ($MonacoTokenId) {
    Write-LogInfo "Revoking generated Monaco API token..."
    try {
        $revokeHeaders = @{ "Authorization" = "Api-Token $EnvToken" }
        Invoke-RestMethod -Uri "$TenantUrl/api/v2/apiTokens/$MonacoTokenId" `
            -Method Delete -Headers $revokeHeaders | Out-Null
        Write-LogInfo "Token revoked successfully."
    }
    catch {
        Write-LogWarning "Failed to revoke token. Delete manually in Dynatrace UI."
    }
}

Remove-TempFiles

Write-LogInfo "Export completed successfully!"
Write-LogInfo "Archive: $archiveName"
