# Manual Command Reference

Quick reference for running common development commands. Use these commands when you need to manually start/stop services or clear caches during development.

## 1. Relay Server

cd C:\Dev\Copilot\flow-relay-mcp-server

# Environment variables are loaded automatically from .env.dev and .env.dev.user by start-relay.ps1
# Do NOT set secrets here - they're managed via env files (gitignored for .env.dev.user)

node dist/index.js

### relay:start
npm run relay:start

### relay:stop
npm run relay:stop

### teams:cache:clear
npm run teams:cache:clear

## 4. Deploy
cd C:\Dev\Copilot\Magentic2
npm run compile
npm run patch:pa-spec
npm run patch:plugin-auth
npm run patch:pa-remove-card    
atk provision --env dev

## 5. Test Relay (optional)
Invoke-RestMethod -Method Post -Uri "https://mw6js38k-3001.euw.devtunnels.ms/send-to-flow" -ContentType "application/json" -Body '{"text":"tunnel test"}'

## 6. Rebuild and Reprovision
npm run compile
npm run patch:pa-spec
npm run patch:plugin-auth
npm run patch:agent-version
atk provision --env dev | tee deploy.log