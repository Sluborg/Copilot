$port = 3001

$forbiddenFiles = @(
  # "C:\Dev\Magentic2\env\.env.dev.user",
  "C:\Dev\Magentic2\env\.env.local"
)
$existingForbidden = $forbiddenFiles | Where-Object { Test-Path $_ }
if ($existingForbidden) {
  Write-Error ("Forbidden env files detected. Use env/.env.dev only. Delete: " + ($existingForbidden -join ", "))
  exit 2
}

$envFiles = @("C:\Dev\Magentic2\env\.env.dev")

foreach ($file in $envFiles) {
  if (Test-Path $file) {
    Get-Content $file | ForEach-Object {
      if ($_ -and $_ -notmatch '^\s*#' -and $_ -match '=') {
        $k, $v = $_ -split '=', 2
        $k = $k.Trim()
        $v = $v.Trim().Trim('"')
        if ($k) {
          Set-Item -Path "Env:$k" -Value $v
        }
      }
    }
  }
}



$env:TRANSPORT = 'http'
$env:PORT = "$port"
$env:NODE_TLS_REJECT_UNAUTHORIZED = '0'

$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listener) {
  $pids = $listener | Select-Object -ExpandProperty OwningProcess -Unique
  Write-Host "Relay appears to already be running on port $port (PID(s): $($pids -join ', '))." -ForegroundColor Yellow
  Write-Host "Use stop-relay.ps1 (or npm run relay:stop) before starting a new instance." -ForegroundColor Yellow
  exit 0
}

$relayDir = "C:\Dev\Magentic2\flow-relay-mcp-server"
Push-Location $relayDir
try {
  node "dist\index.js"
}
finally {
  Pop-Location
}
