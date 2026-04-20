param(
  [switch]$HealthOnly
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

$port = 3001
$envFile = Join-Path $repoRoot "env/.env.dev"
$tunnelLog = Join-Path $env:TEMP "magentic2-devtunnel-output.txt"
$forbiddenEnvFiles = @(
  (Join-Path $repoRoot "env/.env.dev.user"),
  (Join-Path $repoRoot "env/.env.local")
)

function Invoke-Cmd {
  param(
    [string]$Name,
    [string]$Command
  )

  Write-Host "`n==> $Name" -ForegroundColor Cyan
  Write-Host "    $Command" -ForegroundColor DarkGray

  & cmd /c $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Name (exit code $LASTEXITCODE)"
  }
}

function Invoke-PowerShellFile {
  param(
    [string]$Name,
    [string]$Path,
    [string[]]$Arguments = @()
  )

  Write-Host "`n==> $Name" -ForegroundColor Cyan
  Write-Host "    powershell -ExecutionPolicy Bypass -File $Path $($Arguments -join ' ')" -ForegroundColor DarkGray

  & powershell -ExecutionPolicy Bypass -File $Path @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Name (exit code $LASTEXITCODE)"
  }
}

function Remove-ForbiddenEnvFiles {
  $existingForbidden = $forbiddenEnvFiles | Where-Object { Test-Path $_ }
  foreach ($file in $existingForbidden) {
    Remove-Item $file -Force
    Write-Host "Removed forbidden env file: $file" -ForegroundColor Yellow
  }
}

function Start-RelayBackground {
  $startRelayScript = Join-Path $scriptDir "start-relay.ps1"
  Write-Host "`n==> Start relay" -ForegroundColor Cyan
  Write-Host "    powershell -ExecutionPolicy Bypass -File $startRelayScript" -ForegroundColor DarkGray
  Start-Process powershell -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $startRelayScript | Out-Null
}

function Wait-ForLocalRelay {
  $testHealthScript = Join-Path $scriptDir "test-health.ps1"

  for ($attempt = 1; $attempt -le 10; $attempt++) {
    try {
      & powershell -ExecutionPolicy Bypass -File $testHealthScript -SkipTunnel | Out-Null
      if ($LASTEXITCODE -eq 0) {
        Write-Host "Local relay is healthy." -ForegroundColor Green
        return
      }
    } catch {
    }

    Start-Sleep -Seconds 2
  }

  throw "Relay did not become healthy after restart."
}

function Get-TunnelUrlFromDevTunnel {
  try {
    $listOutput = devtunnel list 2>&1 | Out-String
    $urlMatch = [regex]::Match($listOutput, "(https://[a-z0-9-]+-$port\.[a-z]+\.devtunnels\.ms)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($urlMatch.Success) {
      return $urlMatch.Groups[1].Value.TrimEnd('/')
    }

    $idMatch = [regex]::Match($listOutput, "([a-z0-9-]+\.[a-z]{3})\s+$port", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $idMatch.Success) {
      return $null
    }

    $tunnelId = $idMatch.Groups[1].Value
    $showOutput = devtunnel show $tunnelId 2>&1 | Out-String
    $showMatch = [regex]::Match($showOutput, "(https://\S+\.devtunnels\.ms)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($showMatch.Success) {
      return $showMatch.Groups[1].Value.TrimEnd('/')
    }
  } catch {
  }

  return $null
}

function Set-EnvValue {
  param(
    [string]$Key,
    [string]$Value
  )

  if (-not (Test-Path $envFile)) {
    throw "Environment file not found: $envFile"
  }

  $content = Get-Content $envFile -Raw
  if ($content -match "(?m)^$([regex]::Escape($Key))=") {
    $updated = [regex]::Replace($content, "(?m)^$([regex]::Escape($Key))=.*$", "$Key=$Value")
  } else {
    $updated = $content.TrimEnd("`r", "`n") + "`r`n$Key=$Value`r`n"
  }

  Set-Content -Path $envFile -Value $updated -NoNewline
}

function Ensure-DevTunnel {
  $tunnelUrl = Get-TunnelUrlFromDevTunnel
  if (-not [string]::IsNullOrWhiteSpace($tunnelUrl)) {
    Write-Host "Using existing dev tunnel: $tunnelUrl" -ForegroundColor Green
    Set-EnvValue -Key "PA_APP_SERVER_URL" -Value $tunnelUrl
    return
  }

  Write-Host "No dev tunnel detected. Starting a new tunnel..." -ForegroundColor Yellow
  if (Test-Path $tunnelLog) {
    Remove-Item $tunnelLog -Force
  }

  Start-Process powershell -ArgumentList "-NoExit", "-Command", "devtunnel host -p $port --allow-anonymous 2>&1 | Tee-Object -FilePath '$tunnelLog'" | Out-Null

  $attempt = 0
  $maxAttempts = 20
  while ($attempt -lt $maxAttempts) {
    $attempt++
    Start-Sleep -Seconds 2

    if (Test-Path $tunnelLog) {
      $content = Get-Content $tunnelLog -Raw -ErrorAction SilentlyContinue
      $urlMatch = [regex]::Match($content, "(https://[a-z0-9-]+-$port\.[a-z]+\.devtunnels\.ms)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
      if ($urlMatch.Success) {
        $tunnelUrl = $urlMatch.Groups[1].Value.TrimEnd('/')
        Write-Host "Dev tunnel started: $tunnelUrl" -ForegroundColor Green
        Set-EnvValue -Key "PA_APP_SERVER_URL" -Value $tunnelUrl
        return
      }
    }
  }

  throw "Failed to start dev tunnel or capture its URL."
}

function Test-And-FixLocalRelayHealth {
  $healthy = $true

  try {
    Invoke-PowerShellFile -Name "Local relay health check" -Path (Join-Path $scriptDir "test-health.ps1") -Arguments @("-SkipTunnel")
  } catch {
    $healthy = $false
    Write-Host "Local relay health failed. Attempting relay restart..." -ForegroundColor Yellow
  }

  if (-not $healthy) {
    try {
      Invoke-Cmd -Name "Stop relay" -Command "npm run relay:stop"
    } catch {
      Write-Host "Relay stop failed or relay was not running. Continuing..." -ForegroundColor Yellow
    }

    Start-RelayBackground
    Wait-ForLocalRelay
  }
}

function Test-And-FixRelayHealth {
  Test-And-FixLocalRelayHealth
  Ensure-DevTunnel
  Invoke-Cmd -Name "Full relay health check" -Command "npm run relay:test:health"
}

Write-Host "Smart deploy runner" -ForegroundColor Green
Write-Host "Repo root: $repoRoot" -ForegroundColor Gray

Remove-ForbiddenEnvFiles
Test-And-FixRelayHealth

if ($HealthOnly) {
  Write-Host "`nHealth-only mode complete. Relay and tunnel are healthy." -ForegroundColor Green
  exit 0
}

Invoke-Cmd -Name "Compile" -Command "npm run compile"
Invoke-Cmd -Name "Patch PA spec" -Command "npm run patch:pa-spec"
Invoke-Cmd -Name "Patch plugin auth" -Command "npm run patch:plugin-auth"
Invoke-Cmd -Name "Patch Cinode auth" -Command "npm run patch:cinode-auth"
Invoke-Cmd -Name "Patch PA remove card" -Command "npm run patch:pa-remove-card"
Invoke-Cmd -Name "Patch agent version" -Command "npm run patch:agent-version"
Invoke-Cmd -Name "Provision dev" -Command "atk provision --env dev"

Write-Host "`nDeploy completed successfully." -ForegroundColor Green
