# deploy.ps1
# Builds and provisions the agent
# Usage: .\deploy.ps1

param(
    [string]$AgentPath = "C:\Dev\Magentic2"
)

$ErrorActionPreference = "Stop"

Push-Location $AgentPath


# Less verbose, status lines in Blue, errors default to Red if they occur
Write-Host "Generating env..." -ForegroundColor Blue
npm run generate:env -- dev | Out-Null

Write-Host "Compiling TypeSpec..." -ForegroundColor Blue
npm run compile | Out-Null

Write-Host "Patching PA spec..." -ForegroundColor Blue
npm run patch:pa-spec | Out-Null

Write-Host "Patching plugin auth..." -ForegroundColor Blue
npm run patch:plugin-auth | Out-Null

Write-Host "Patching agent version..." -ForegroundColor Blue
npm run patch:agent-version | Out-Null

Write-Host "Provisioning..." -ForegroundColor Blue
atk provision --env dev 2>&1 | Tee-Object -FilePath deploy.log

Pop-Location

Write-Host ""
Write-Host "Done. Log saved to $AgentPath\deploy.log" -ForegroundColor Green