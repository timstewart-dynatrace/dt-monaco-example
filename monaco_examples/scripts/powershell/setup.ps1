<#
.SYNOPSIS
    Quick Setup Script for Dynatrace Monaco Configuration Migration

.DESCRIPTION
    Checks dependencies, collects configuration from user, creates .env file,
    and verifies tenant connections.

.EXAMPLE
    .\setup.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

# --- Helpers ---

function Test-CommandExists {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "  [OK] " -ForegroundColor Green -NoNewline
        Write-Host $Name
        return $true
    }
    else {
        Write-Host "  [!!] " -ForegroundColor Red -NoNewline
        Write-Host "$Name (not found)"
        return $false
    }
}

function Test-TenantConnection {
    param([string]$Url, [string]$Token, [string]$Name)
    try {
        $headers = @{ "Authorization" = "Api-Token $Token" }
        Invoke-RestMethod -Uri "$Url/api/v2/environments" -Headers $headers -Method Get -TimeoutSec 10 | Out-Null
        Write-Host "  [OK] " -ForegroundColor Green -NoNewline
        Write-Host "$Name tenant"
        return $true
    }
    catch {
        Write-Host "  [!!] " -ForegroundColor Red -NoNewline
        Write-Host "$Name tenant"
        return $false
    }
}

# --- Banner ---

Write-Host ""
Write-Host ("=" * 62) -ForegroundColor Blue
Write-Host "  Dynatrace Monaco Configuration Migration - Setup Wizard" -ForegroundColor Blue
Write-Host ("=" * 62) -ForegroundColor Blue
Write-Host ""

# --- Step 1: Check dependencies ---

Write-Host "[1/4] Checking dependencies..." -ForegroundColor Blue

$allDepsOk = $true
if (-not (Test-CommandExists "python3")) {
    if (-not (Test-CommandExists "python")) {
        $allDepsOk = $false
    }
}
Test-CommandExists "curl" | ForEach-Object { if (-not $_) { $allDepsOk = $false } }

$monacoOk = Test-CommandExists "monaco"
if (-not $monacoOk) {
    $monacoOk = Test-CommandExists "monaco.exe"
}
if (-not $monacoOk) {
    Write-Host "  [!!] Monaco not in PATH (you'll need to install it)" -ForegroundColor Yellow
    $allDepsOk = $false
}

if (-not $allDepsOk) {
    Write-Host ""
    Write-Host "[!] Some dependencies are missing. See README.md for installation steps." -ForegroundColor Yellow
}

# --- Step 2: Collect configuration ---

Write-Host ""
Write-Host "[2/4] Collecting configuration details..." -ForegroundColor Blue
Write-Host ""

$skipConfig = $false

if (Test-Path ".env") {
    Write-Host "[!] .env file already exists. Using existing configuration." -ForegroundColor Yellow

    # Load existing .env
    Get-Content ".env" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line -split "=", 2
            if ($parts.Count -eq 2) {
                [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
            }
        }
    }

    $SourceUrl = $env:SOURCE_TENANT_URL
    $SourceToken = $env:SOURCE_TENANT_TOKEN
    $TargetUrl = $env:TARGET_TENANT_URL
    $TargetToken = $env:TARGET_TENANT_TOKEN
    $skipConfig = $true
}
else {
    $SourceUrl = Read-Host "Source Dynatrace Tenant URL (https://...)"
    $SourceToken = Read-Host "Source API Token"
    Write-Host ""
    $TargetUrl = Read-Host "Target Dynatrace Tenant URL (https://...)"
    $TargetToken = Read-Host "Target API Token"
}

# --- Step 3: Verify connections ---

Write-Host ""
Write-Host "[3/4] Verifying connections..." -ForegroundColor Blue

Test-TenantConnection -Url $SourceUrl -Token $SourceToken -Name "Source"
Test-TenantConnection -Url $TargetUrl -Token $TargetToken -Name "Target"

# --- Step 4: Create .env file ---

if (-not $skipConfig) {
    Write-Host ""
    Write-Host "[4/4] Creating configuration file..." -ForegroundColor Blue

    $envContent = @"
# Dynatrace Monaco Configuration
# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Source Tenant
SOURCE_TENANT_URL=$SourceUrl
SOURCE_TENANT_TOKEN=$SourceToken

# Target Tenant
TARGET_TENANT_URL=$TargetUrl
TARGET_TENANT_TOKEN=$TargetToken
"@

    Set-Content -Path ".env" -Value $envContent -Encoding UTF8
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "Created .env file (" -NoNewline
    Write-Host "keep this secure!" -ForegroundColor Red -NoNewline
    Write-Host ")"
}

# --- Monaco installation hint ---

if (-not $monacoOk) {
    Write-Host ""
    Write-Host "[!] Monaco CLI not found. Install it:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  Invoke-WebRequest -URI https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-windows-amd64.exe -OutFile monaco.exe'
    Write-Host ""
}

# --- Summary ---

Write-Host ""
Write-Host ("=" * 62) -ForegroundColor Blue
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host ("=" * 62) -ForegroundColor Blue
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Blue
Write-Host ""
Write-Host "1. Verify your configuration:"
Write-Host "   Get-Content .env"
Write-Host ""
Write-Host "2. Test connectivity (optional):"
Write-Host "   .\scripts\powershell\verify_migration.ps1"
Write-Host ""
Write-Host "3. Run a dry-run to preview changes:"
Write-Host "   .\scripts\powershell\migrate.ps1 -DryRun"
Write-Host ""
Write-Host "4. Start migration:"
Write-Host "   .\scripts\powershell\migrate.ps1"
Write-Host ""
