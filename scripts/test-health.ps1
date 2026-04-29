param(
  [string]$TunnelUrl,
  [switch]$SkipTunnel
)

$ErrorActionPreference = "Stop"
$localHealthUrl = "http://localhost:3001/health"
$namedTunnel = "magentic2-relay"
$allChecksPassed = $true
$script:EnvValueSource = $null

function Get-EnvValue {
  param(
    [string]$Key,
    [string[]]$Paths
  )

  foreach ($path in $Paths) {
    if (-not (Test-Path $path)) {
      continue
    }

    try {
      $line = Get-Content $path | Where-Object { $_ -match ("^" + [regex]::Escape($Key) + "=") } | Select-Object -First 1
      if (-not [string]::IsNullOrWhiteSpace($line)) {
        $script:EnvValueSource = $path
        return ($line -split "=", 2)[1].Trim()
      }
    } catch {
    }
  }

  return $null
}

function Get-TunnelUrlFromDevTunnel {
  try {
    $showJson = devtunnel show $namedTunnel --json 2>&1 | Out-String
    $showObj = $showJson | ConvertFrom-Json
    $portEntry = $showObj.tunnel.ports | Where-Object { $_.portNumber -eq 3001 } | Select-Object -First 1
    if (-not $portEntry -or [string]::IsNullOrWhiteSpace($portEntry.portUri)) {
      return $null
    }

    return $portEntry.portUri.TrimEnd('/')
  } catch {
    return $null
  }
}

function Normalize-TunnelHealthUrl {
  param([string]$RawUrl)

  if ([string]::IsNullOrWhiteSpace($RawUrl)) {
    return $null
  }

  $url = $RawUrl.Trim()

  if ($url -notmatch "^https?://") {
    $url = "https://$url"
  }

  if ($url -match "/health/?$") {
    return $url.TrimEnd('/')
  }

  return ($url.TrimEnd('/') + "/health")
}

Write-Host "Testing relay health..." -ForegroundColor Cyan

try {
  $localResponse = Invoke-RestMethod -Uri $localHealthUrl
  Write-Host "Local health OK: $($localResponse.status), version=$($localResponse.version), cinode=$($localResponse.cinode)" -ForegroundColor Green
} catch {
  Write-Host "Local health FAILED at $localHealthUrl" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  $allChecksPassed = $false
}

if (-not $SkipTunnel) {
  if ([string]::IsNullOrWhiteSpace($TunnelUrl)) {
    $TunnelUrl = Get-EnvValue -Key "PA_APP_SERVER_URL" -Paths @(
      ".\\env\\.env.dev"
    )

    if (-not [string]::IsNullOrWhiteSpace($TunnelUrl) -and -not [string]::IsNullOrWhiteSpace($script:EnvValueSource)) {
      Write-Host "Using PA_APP_SERVER_URL from $script:EnvValueSource" -ForegroundColor Gray
    }
  }

  if ([string]::IsNullOrWhiteSpace($TunnelUrl)) {
    $TunnelUrl = Get-TunnelUrlFromDevTunnel
    if (-not [string]::IsNullOrWhiteSpace($TunnelUrl)) {
      Write-Host "Using tunnel URL from named dev tunnel $namedTunnel." -ForegroundColor Gray
    }
  }

  $tunnelHealthUrl = Normalize-TunnelHealthUrl -RawUrl $TunnelUrl

  if ([string]::IsNullOrWhiteSpace($tunnelHealthUrl)) {
    Write-Host "Tunnel URL not provided and could not be auto-detected from devtunnel." -ForegroundColor Yellow
    Write-Host "Tip: run ./scripts/test-health.ps1 -TunnelUrl https://<your-tunnel>.devtunnels.ms" -ForegroundColor Yellow
    $allChecksPassed = $false
  } else {
    try {
      $tunnelResponse = Invoke-RestMethod -Uri $tunnelHealthUrl
      Write-Host "Tunnel health OK: $($tunnelResponse.status), version=$($tunnelResponse.version), cinode=$($tunnelResponse.cinode)" -ForegroundColor Green
      Write-Host "Checked URL: $tunnelHealthUrl" -ForegroundColor Gray
    } catch {
      Write-Host "Tunnel health FAILED at $tunnelHealthUrl" -ForegroundColor Red
      Write-Host $_.Exception.Message -ForegroundColor Red
      $allChecksPassed = $false
    }
  }
} else {
  Write-Host "Tunnel check skipped." -ForegroundColor Yellow
}

if (-not $allChecksPassed) {
  exit 1
}

Write-Host "All health checks passed." -ForegroundColor Green
