# stop-dev.ps1
# Stops relay server and devtunnel
# Usage: .\stop-dev.ps1

param([int]$Port = 3001)

Write-Host "Stopping dev environment..." -ForegroundColor Cyan

# Kill relay (node on port)
$conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Stopping relay (PID $($proc.Id))..." -ForegroundColor Yellow
        Stop-Process -Id $proc.Id -Force
    }
}

# Kill devtunnel processes
$tunnels = Get-Process -Name "devtunnel" -ErrorAction SilentlyContinue
if ($tunnels) {
    Write-Host "Stopping devtunnel..." -ForegroundColor Yellow
    $tunnels | Stop-Process -Force
}

# Clean temp log
$tunnelLog = "$env:TEMP\devtunnel-output.txt"
if (Test-Path $tunnelLog) { Remove-Item $tunnelLog }

Write-Host "Dev environment stopped." -ForegroundColor Green