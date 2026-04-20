param(
  [string]$EnvFile = ".\\env\\.env.dev",
  [int]$Port = 3001,
  [int]$MaxAttempts = 30
)

$ErrorActionPreference = "Stop"

function Get-TunnelUrlFromId {
  param(
    [string]$TunnelId,
    [int]$Port
  )

  if ([string]::IsNullOrWhiteSpace($TunnelId)) {
    return $null
  }

  try {
    $showJson = devtunnel show $TunnelId --json 2>&1 | Out-String
    $showObj = $showJson | ConvertFrom-Json
    $portEntry = $showObj.tunnel.ports | Where-Object { $_.portNumber -eq $Port } | Select-Object -First 1
    if ($portEntry -and -not [string]::IsNullOrWhiteSpace($portEntry.portUri)) {
      return $portEntry.portUri.TrimEnd('/')
    }
  } catch {
  }

  return $null
}

function Get-ActiveTunnelUrl {
  param([int]$Port)

  try {
    $listJson = devtunnel list --json 2>&1 | Out-String
    $listObj = $listJson | ConvertFrom-Json
    $tunnels = @($listObj.tunnels)

    foreach ($tunnel in ($tunnels | Where-Object { $_.hostConnections -gt 0 })) {
      $url = Get-TunnelUrlFromId -TunnelId $tunnel.tunnelId -Port $Port
      if (-not [string]::IsNullOrWhiteSpace($url)) {
        try {
          $healthUrl = $url.TrimEnd('/') + '/health'
          $resp = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5
          if ($resp -and $resp.status -eq 'ok') {
            return $url
          }
        } catch {
        }
      }
    }

    foreach ($tunnel in $tunnels) {
      $url = Get-TunnelUrlFromId -TunnelId $tunnel.tunnelId -Port $Port
      if (-not [string]::IsNullOrWhiteSpace($url)) {
        return $url
      }
    }
  } catch {
  }

  return $null
}

if (-not (Test-Path $EnvFile)) {
  Write-Error "Env file not found: $EnvFile"
  exit 1
}

$tunnelUrl = $null
for ($i = 0; $i -lt $MaxAttempts -and -not $tunnelUrl; $i++) {
  $tunnelUrl = Get-ActiveTunnelUrl -Port $Port
  if (-not $tunnelUrl) {
    Start-Sleep -Seconds 1
  }
}

if (-not $tunnelUrl) {
  Write-Error "Timed out waiting for an active dev tunnel URL on port $Port."
  exit 1
}

$content = Get-Content $EnvFile -Raw
$newLine = "PA_APP_SERVER_URL=$tunnelUrl"

if ($content -match "(?m)^PA_APP_SERVER_URL=.*$") {
  $content = $content -replace "(?m)^PA_APP_SERVER_URL=.*$", $newLine
} else {
  $content = $content.TrimEnd("`r", "`n") + "`r`n$newLine`r`n"
}

Set-Content $EnvFile $content -NoNewline
Write-Host "Updated PA_APP_SERVER_URL in $EnvFile to $tunnelUrl" -ForegroundColor Green
