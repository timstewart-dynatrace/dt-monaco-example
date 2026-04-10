<#
.SYNOPSIS
    Verify that configuration was successfully migrated between tenants.

.DESCRIPTION
    Compares configuration counts and types between source and target tenants
    to verify a successful migration.

.PARAMETER SourceUrl
    Source tenant URL

.PARAMETER TargetUrl
    Target tenant URL

.PARAMETER SourceToken
    Source API token

.PARAMETER TargetToken
    Target API token

.EXAMPLE
    $env:SOURCE_TENANT_URL = "https://source.live.dynatrace.com"
    $env:SOURCE_TENANT_TOKEN = "your_token"
    $env:TARGET_TENANT_URL = "https://target.live.dynatrace.com"
    $env:TARGET_TENANT_TOKEN = "your_token"
    .\verify_migration.ps1

.EXAMPLE
    .\verify_migration.ps1 -SourceUrl "https://source.live.dynatrace.com" -SourceToken "TOKEN" -TargetUrl "https://target.live.dynatrace.com" -TargetToken "TOKEN"
#>

[CmdletBinding()]
param(
    [string]$SourceUrl = $env:SOURCE_TENANT_URL,
    [string]$TargetUrl = $env:TARGET_TENANT_URL,
    [string]$SourceToken = $env:SOURCE_TENANT_TOKEN,
    [string]$TargetToken = $env:TARGET_TENANT_TOKEN
)

$ErrorActionPreference = "Stop"

# --- Load .env ---

function Import-EnvFile {
    param([string]$Path = ".env")
    if (Test-Path $Path) {
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

Import-EnvFile

# Re-read after .env load
if (-not $SourceUrl) { $SourceUrl = $env:SOURCE_TENANT_URL }
if (-not $TargetUrl) { $TargetUrl = $env:TARGET_TENANT_URL }
if (-not $SourceToken) { $SourceToken = $env:SOURCE_TENANT_TOKEN }
if (-not $TargetToken) { $TargetToken = $env:TARGET_TENANT_TOKEN }

if (-not $SourceUrl -or -not $TargetUrl -or -not $SourceToken -or -not $TargetToken) {
    Write-Host "[ERROR] Missing required parameters or environment variables" -ForegroundColor Red
    Write-Host "Required: SourceUrl, TargetUrl, SourceToken, TargetToken"
    exit 1
}

$SourceUrl = $SourceUrl.TrimEnd("/")
$TargetUrl = $TargetUrl.TrimEnd("/")

# --- API helper ---

function Get-ConfigCount {
    param(
        [string]$Url,
        [string]$Token,
        [string]$Endpoint,
        [string]$ArrayKey
    )

    try {
        $headers = @{ "Authorization" = "Api-Token $Token" }
        $response = Invoke-RestMethod -Uri "$Url/$Endpoint" -Headers $headers -Method Get -TimeoutSec 15
        $items = $response.$ArrayKey
        if ($items) {
            return @{ Count = $items.Count; Success = $true }
        }
        return @{ Count = 0; Success = $true }
    }
    catch {
        return @{ Count = -1; Success = $false }
    }
}

# --- Main ---

Write-Host ""
Write-Host "Starting migration verification..." -ForegroundColor Blue
Write-Host ("=" * 60)
Write-Host ""

$configChecks = @(
    @{ Name = "Dashboards";         Endpoint = "api/v2/dashboards";       ArrayKey = "dashboards" },
    @{ Name = "Alerting Profiles";  Endpoint = "api/v2/alertingProfiles"; ArrayKey = "alertingProfiles" },
    @{ Name = "Management Zones";   Endpoint = "api/v2/managementZones";  ArrayKey = "managementZones" },
    @{ Name = "Notifications";      Endpoint = "api/v3/notifications";    ArrayKey = "items" },
    @{ Name = "Auto-Tags";          Endpoint = "api/v2/autoTags";         ArrayKey = "autoTags" }
)

# Print header
$fmt = "{0,-25} {1,-10} {2,-10} {3,-10}"
Write-Host ($fmt -f "Configuration", "Source", "Target", "Status")
Write-Host ("-" * 55)

$allPassed = $true
$totalSource = 0
$totalTarget = 0

foreach ($check in $configChecks) {
    $sourceResult = Get-ConfigCount -Url $SourceUrl -Token $SourceToken -Endpoint $check.Endpoint -ArrayKey $check.ArrayKey
    $targetResult = Get-ConfigCount -Url $TargetUrl -Token $TargetToken -Endpoint $check.Endpoint -ArrayKey $check.ArrayKey

    $sourceDisplay = if ($sourceResult.Success) { $sourceResult.Count } else { "ERROR" }
    $targetDisplay = if ($targetResult.Success) { $targetResult.Count } else { "ERROR" }

    if (-not $sourceResult.Success -or -not $targetResult.Success) {
        $status = "!! ERROR"
        $allPassed = $false
    }
    elseif ($sourceResult.Count -eq $targetResult.Count) {
        $status = "PASS"
        $totalSource += $sourceResult.Count
        $totalTarget += $targetResult.Count
    }
    elseif ($sourceResult.Count -gt 0 -and $targetResult.Count -eq 0) {
        $status = "FAIL"
        $allPassed = $false
        $totalSource += $sourceResult.Count
    }
    else {
        $status = "!! WARN"
        $totalSource += $sourceResult.Count
        $totalTarget += $targetResult.Count
    }

    $color = switch -Wildcard ($status) {
        "PASS"  { "Green" }
        "FAIL"  { "Red" }
        default { "Yellow" }
    }

    Write-Host ($fmt -f $check.Name, $sourceDisplay, $targetDisplay, "") -NoNewline
    Write-Host $status -ForegroundColor $color
}

Write-Host ("-" * 55)
Write-Host ($fmt -f "TOTAL", $totalSource, $totalTarget, "")
Write-Host ""

if ($allPassed) {
    Write-Host "Verification passed: Migration appears successful" -ForegroundColor Green
}
else {
    Write-Host "Verification detected issues: Review counts above" -ForegroundColor Yellow
}

Write-Host ""
