param(
  [switch]$ForceDeploy
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$envFile = Join-Path $repoRoot "env/.env.dev"
$generatedPaSpec = Join-Path $repoRoot "appPackage/.generated/paflowapi-openapi.yml"

Set-Location $repoRoot

function Get-EnvValue {
  param(
    [string]$FilePath,
    [string]$Key
  )

  if (-not (Test-Path $FilePath)) {
    return $null
  }

  $line = Get-Content $FilePath | Where-Object { $_ -match ("^" + [regex]::Escape($Key) + "=") } | Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($line)) {
    return $null
  }

  return ($line -split "=", 2)[1].Trim().TrimEnd('/')
}

function Get-GeneratedPaServerUrl {
  param([string]$SpecPath)

  if (-not (Test-Path $SpecPath)) {
    return $null
  }

  $lines = Get-Content $SpecPath
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*servers:\s*$') {
      for ($j = $i + 1; $j -lt [Math]::Min($i + 8, $lines.Count); $j++) {
        if ($lines[$j] -match '^\s*-\s*url:\s*(\S+)\s*$') {
          return $Matches[1].Trim().TrimEnd('/')
        }
      }
      break
    }
  }

  return $null
}

Write-Host "Starting Magentic2 smart startup..." -ForegroundColor Cyan

Write-Host "`n==> Ensure relay and tunnel are healthy" -ForegroundColor Cyan
npm run deploy:smart:health
if ($LASTEXITCODE -ne 0) {
  throw "Health startup failed."
}

$envUrl = Get-EnvValue -FilePath $envFile -Key "PA_APP_SERVER_URL"
$generatedUrl = Get-GeneratedPaServerUrl -SpecPath $generatedPaSpec

Write-Host "`nCurrent runtime URL: $envUrl" -ForegroundColor Gray
Write-Host "Current generated spec URL: $generatedUrl" -ForegroundColor Gray

$needsDeploy = $ForceDeploy -or [string]::IsNullOrWhiteSpace($generatedUrl) -or ($envUrl -ne $generatedUrl)

if ($needsDeploy) {
  Write-Host "`n==> URL changed (or force deploy requested)." -ForegroundColor Yellow
  Write-Host "A republish will create a new release version in the Agent catalog." -ForegroundColor Yellow
  Write-Host "Uninstall Magentic2 first if you want a clean re-add path." -ForegroundColor Yellow

  $confirm = Read-Host "Type RELEASE to continue publish (anything else cancels)"
  if ($confirm -ne "RELEASE") {
    Write-Host "Publish cancelled by user. Startup finished without a new release." -ForegroundColor Green
    exit 0
  }

  Write-Host "`nRepublishing agent..." -ForegroundColor Yellow
  npm run deploy:smart
  if ($LASTEXITCODE -ne 0) {
    throw "Deploy failed."
  }
  Write-Host "`nStartup + republish complete." -ForegroundColor Green
} else {
  Write-Host "`nURL unchanged. Skipping republish." -ForegroundColor Green
  Write-Host "Startup complete. Services are ready." -ForegroundColor Green
}
