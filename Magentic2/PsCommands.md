# 1. Relay Server
cd C:\Dev\Template\mcp\flow-relay-mcp-server
$env:NODE_TLS_REJECT_UNAUTHORIZED="0"
$env:FLOW_WEBHOOK_URL='https://f97ec0186468e5028db0622bbd110e.5a.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/5ac24948f429454fabd65f9060edc478/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=8_E3xI3I2iaIzhy122smoXJi9ksgAwyEYmrlTEN-hqE'
$env:TRANSPORT="http"
$env:PORT="3001"
node dist/index.js

# 2. DevTunnel
devtunnel host -p 3001 --allow-anonymous

# 3. Patch .env
$id = (devtunnel list 2>&1 | Select-String '(\S+\.euw)\s+1').Matches[0].Groups[1].Value; $url = (devtunnel show $id 2>&1 | Select-String '(https://\S+\.devtunnels\.ms)').Matches[0].Groups[1].Value.TrimEnd('/'); (Get-Content C:\Dev\Copilot\Magentic2\env\.env.dev -Raw) -replace '(?m)^PA_APP_SERVER_URL=.*$', "PA_APP_SERVER_URL=$url" | Set-Content C:\Dev\Copilot\Magentic2\env\.env.dev -NoNewline; Write-Host "Patched .env.dev with $url — run deploy next" -ForegroundColor Green

# 4. Deploy
npm run compile
npm run patch:pa-spec
npm run patch:plugin-auth
npm run patch:pa-remove-card   
npm run patch:agent-version    
atk provision --env dev

# Test relay (optional)
Invoke-RestMethod -Method Post -Uri "https://mw6js38k-3001.euw.devtunnels.ms/send-to-flow" -ContentType "application/json" -Body '{"text":"tunnel test"}'

# Rebuild and reprovision
npm run compile
npm run patch:pa-spec
npm run patch:plugin-auth
npm run patch:agent-version
atk provision --env dev | tee deploy.log