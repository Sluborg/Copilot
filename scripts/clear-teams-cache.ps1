$teamsPathLocalClassic = "$env:LOCALAPPDATA\Microsoft\Teams"
$teamsPathRoamingClassic = "$env:APPDATA\Microsoft\Teams"
$msixPackageRoots = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match "^(MSTeams|MicrosoftTeams)_" }

$cachePaths = @(
  (Join-Path $teamsPathLocalClassic "Cache"),
  (Join-Path $teamsPathRoamingClassic "Cache"),
  (Join-Path $teamsPathLocalClassic "application cache")
)

foreach ($pkg in $msixPackageRoots) {
  $msixBase = Join-Path $pkg.FullName "LocalCache\Microsoft\MSTeams"
  $cachePaths += @(
    (Join-Path $msixBase "EBWebView\Default\Cache"),
    (Join-Path $msixBase "EBWebView\Default\Code Cache"),
    (Join-Path $msixBase "EBWebView\Default\GPUCache"),
    (Join-Path $msixBase "EBWebView\WV2Profile_tfw\Cache"),
    (Join-Path $msixBase "EBWebView\WV2Profile_tfw\Code Cache"),
    (Join-Path $msixBase "EBWebView\WV2Profile_tfw\GPUCache"),
    (Join-Path $msixBase "EBWebView\WV2Profile_tfw\Service Worker"),
    (Join-Path $msixBase "tmp")
  )
}

$cachePaths = $cachePaths | Select-Object -Unique

Write-Host "Clearing Teams cache..." -ForegroundColor Cyan

# Kill Teams process (classic and new Teams)
$teamsProcesses = Get-Process -ErrorAction SilentlyContinue |
  Where-Object { $_.ProcessName -in @("Teams", "ms-teams", "MSTeams") }

if ($teamsProcesses) {
  Write-Host "Closing Teams processes..." -ForegroundColor Yellow
  $teamsProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
} else {
  Write-Host "No running Teams process found." -ForegroundColor Gray
}

# Clear cache from all possible locations
$foundAny = $false
foreach ($cachePath in $cachePaths) {
  if (Test-Path $cachePath) {
    Write-Host "Removing cache at $cachePath" -ForegroundColor Yellow
    Remove-Item $cachePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cache cleared." -ForegroundColor Green
    $foundAny = $true
  }
}

if (-not $foundAny) {
  Write-Host "No cache folders found at:" -ForegroundColor Yellow
  foreach ($cachePath in $cachePaths) {
    Write-Host "  - $cachePath" -ForegroundColor Gray
  }
}

# Always restart Teams after cache clear
Write-Host "Starting Teams..." -ForegroundColor Cyan

# Try multiple ways to start Teams
$teamsPaths = @(
  "${env:ProgramFiles}\Microsoft\Teams\current\Teams.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Teams\current\Teams.exe",
  "${env:LOCALAPPDATA}\Microsoft\Teams\Update.exe"
)

$started = $false
foreach ($path in $teamsPaths) {
  if (Test-Path $path) {
    Start-Process $path
    $started = $true
    break
  }
}

if (-not $started) {
  # Fallback for MSIX/Store Teams installs.
  Write-Host "Teams executable not found at expected paths, attempting MSIX app launch..." -ForegroundColor Yellow
  $teamsAppIds = @(
    "MSTeams_8wekyb3d8bbwe!MSTeams",
    "MicrosoftTeams_8wekyb3d8bbwe!MSTeams"
  )

  foreach ($appId in $teamsAppIds) {
    try {
      Start-Process "shell:AppsFolder\$appId" -ErrorAction Stop
      $started = $true
      break
    } catch {
    }
  }
}

if (-not $started) {
  # Final fallback: protocol handler.
  try {
    Start-Process "teams:" -ErrorAction Stop
    $started = $true
  } catch {
  }
}

if ($started) {
  Write-Host "Teams started. Cache is fresh." -ForegroundColor Green
} else {
  Write-Host "Unable to auto-start Teams. Start it manually from Start menu." -ForegroundColor Yellow
}
