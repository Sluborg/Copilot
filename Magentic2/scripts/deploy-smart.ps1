param(
  [switch]$HealthOnly
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

$tunnelName = "magentic2-relay"
$port = 3001
$envFile = Join-Path $repoRoot "env/.env.dev"
$tunnelLog = Join-Path $env:TEMP ("magentic2-devtunnel-output-" + $PID + ".txt")
$forbiddenEnvFiles = @(
  # (Join-Path $repoRoot "env/.env.dev.user"),
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
  Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $startRelayScript | Out-Null
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
    $showJson = devtunnel show $tunnelName --json 2>&1 | Out-String
    $showObj = $showJson | ConvertFrom-Json
    $portEntry = $showObj.tunnel.ports | Where-Object { $_.portNumber -eq $port } | Select-Object -First 1

    if ($portEntry -and -not [string]::IsNullOrWhiteSpace($portEntry.portUri)) {
      $candidate = $portEntry.portUri.TrimEnd('/')
      try {
        $health = Invoke-RestMethod -Uri ($candidate + "/health") -TimeoutSec 5
        if ($health -and $health.status -eq "ok") {
          return $candidate
        }
      } catch {
      }

      return $candidate
    }
  } catch {
  }

  return $null
}

function Ensure-NamedDevTunnelExists {
  try {
    devtunnel show $tunnelName --json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Tunnel missing"
    }
  } catch {
    Write-Host "Creating named dev tunnel: $tunnelName" -ForegroundColor Yellow
    devtunnel create $tunnelName --allow-anonymous | Out-Null
  }

  $showJson = devtunnel show $tunnelName --json 2>&1 | Out-String
  $showObj = $showJson | ConvertFrom-Json
  $portEntry = $showObj.tunnel.ports | Where-Object { $_.portNumber -eq $port } | Select-Object -First 1
  if (-not $portEntry) {
    Write-Host "Adding port $port to named tunnel: $tunnelName" -ForegroundColor Yellow
    devtunnel port create $tunnelName -p $port | Out-Null
  }
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
  Ensure-NamedDevTunnelExists

  $tunnelUrl = Get-TunnelUrlFromDevTunnel
  if (-not [string]::IsNullOrWhiteSpace($tunnelUrl)) {
    Write-Host "Using named dev tunnel ${tunnelName}: $tunnelUrl" -ForegroundColor Green
    Set-EnvValue -Key "PA_APP_SERVER_URL" -Value $tunnelUrl
    return
  }

  Write-Host "Named dev tunnel not active. Starting host for $tunnelName..." -ForegroundColor Yellow
  if (Test-Path $tunnelLog) {
    Remove-Item $tunnelLog -Force
  }

  Start-Process powershell -WindowStyle Hidden -ArgumentList "-Command", "devtunnel host $tunnelName 2>&1 | Tee-Object -FilePath '$tunnelLog'" | Out-Null

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

Invoke-Cmd -Name "Patch PA remove card" -Command "npm run patch:pa-remove-card"
Invoke-Cmd -Name "Patch agent version" -Command "npm run patch:agent-version"
Invoke-Cmd -Name "Provision dev" -Command "atk provision --env dev"

Write-Host "`nDeploy completed successfully." -ForegroundColor Green
