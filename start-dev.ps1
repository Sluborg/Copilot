# start-dev.ps1
# Starts relay server + devtunnel, captures URL, patches .env.dev
# Usage: .\start-dev.ps1

param(
    [string]$RelayPath = "C:\Dev\Template\mcp\flow-relay-mcp-server",
    [string]$AgentPath = "C:\Dev\Magentic2",
    [string]$TunnelName = "magentic2-relay",
    [int]$Port = 3001
)

$ErrorActionPreference = "Stop"

$FlowWebhookUrl = 'https://f97ec0186468e5028db0622bbd110e.5a.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/5ac24948f429454fabd65f9060edc478/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=8_E3xI3I2iaIzhy122smoXJi9ksgAwyEYmrlTEN-hqE'

# --- Kill any existing processes on the port ---
Write-Host "Checking port $Port..." -ForegroundColor Cyan
$existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Killing existing process on port $Port" -ForegroundColor Yellow
    Stop-Process -Id (Get-Process -Id $existing.OwningProcess).Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# --- Start relay server ---
Write-Host "Starting relay server on port $Port..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
    cd '$RelayPath'
    `$env:NODE_TLS_REJECT_UNAUTHORIZED='0'
    `$env:FLOW_WEBHOOK_URL='$FlowWebhookUrl'
    `$env:TRANSPORT='http'
    `$env:PORT='$Port'
    node dist/index.js
"@

Start-Sleep -Seconds 3

# --- Verify relay is running ---
try {
    $health = Invoke-RestMethod -Uri "http://localhost:$Port/health" -TimeoutSec 5
    Write-Host "Relay running: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Relay not responding on port $Port. Check the relay window." -ForegroundColor Red
    exit 1
}

# --- Ensure named devtunnel exists ---
Write-Host "Ensuring named devtunnel $TunnelName on port $Port..." -ForegroundColor Cyan

try {
    devtunnel show $TunnelName --json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Tunnel missing"
    }
} catch {
    devtunnel create $TunnelName --allow-anonymous | Out-Null
}

$showJson = devtunnel show $TunnelName --json | ConvertFrom-Json
$portExists = @($showJson.tunnel.ports) | Where-Object { $_.portNumber -eq $Port } | Select-Object -First 1
if (-not $portExists) {
    devtunnel port create $TunnelName -p $Port | Out-Null
}

# --- Start devtunnel and capture URL ---
Write-Host "Starting named devtunnel $TunnelName..." -ForegroundColor Cyan

$tunnelLog = "$env:TEMP\devtunnel-output.txt"
if (Test-Path $tunnelLog) { Remove-Item $tunnelLog }

Start-Process powershell -ArgumentList "-NoExit", "-Command", @"
    devtunnel host $TunnelName 2>&1 | Tee-Object -FilePath '$tunnelLog'
"@

Write-Host "Waiting for tunnel URL..." -ForegroundColor Cyan
$tunnelUrl = $null
$attempts = 0
$maxAttempts = 30

while (-not $tunnelUrl -and $attempts -lt $maxAttempts) {
    Start-Sleep -Seconds 2
    $attempts++
    if (Test-Path $tunnelLog) {
        $content = Get-Content $tunnelLog -Raw -ErrorAction SilentlyContinue
        if ($content -match '(https://[a-z0-9]+-' + $Port + '\.[a-z]+\.devtunnels\.ms)') {
            $tunnelUrl = $Matches[1]
        }
    }
    Write-Host "  Attempt $attempts/$maxAttempts..." -ForegroundColor Gray
}

if (-not $tunnelUrl) {
    Write-Host "ERROR: Could not capture tunnel URL. Check devtunnel window." -ForegroundColor Red
    Write-Host "Update .env.dev manually with PA_APP_SERVER_URL=<tunnel url>" -ForegroundColor Yellow
    exit 1
}

Write-Host "Tunnel URL: $tunnelUrl" -ForegroundColor Green

# --- Test tunnel ---
Write-Host "Testing tunnel..." -ForegroundColor Cyan
try {
    $result = Invoke-RestMethod -Method Post -Uri "$tunnelUrl/send-to-flow" -ContentType "application/json" -Body '{"text":"startup test"}' -TimeoutSec 15
    if ($result.success) {
        Write-Host "Tunnel -> Relay -> Flow: OK" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Flow returned status $($result.status)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: Tunnel test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Patch .env.dev ---
$envFile = Join-Path $AgentPath "env\.env.dev"

if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    $envContent = $envContent -replace '(?m)^PA_APP_SERVER_URL=.*$', "PA_APP_SERVER_URL=$tunnelUrl"
    Set-Content -Path $envFile -Value $envContent -NoNewline
    Write-Host "Updated PA_APP_SERVER_URL in .env.dev" -ForegroundColor Green
} else {
    Write-Host "WARNING: $envFile not found." -ForegroundColor Yellow
    Write-Host "Set PA_APP_SERVER_URL=$tunnelUrl manually" -ForegroundColor Yellow
}

# --- Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dev environment ready" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Relay:   http://localhost:$Port"
Write-Host "  Tunnel:  $tunnelUrl"
Write-Host "  Health:  $tunnelUrl/health"
Write-Host "  Flow:    $tunnelUrl/send-to-flow"
Write-Host ""
Write-Host "  Next: .\deploy.ps1" -ForegroundColor Gray
Write-Host "  Stop: .\stop-dev.ps1" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan