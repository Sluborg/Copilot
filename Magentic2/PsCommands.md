# Manual Command Reference

Quick reference for running common development commands. Use these commands when you need to manually start/stop services or clear caches during development.

## 1. Relay Server

cd C:\Dev\Copilot\flow-relay-mcp-server

# Environment variables are loaded automatically from env/.env.dev by start-relay.ps1
# Keep env/.env.dev as your single source of truth (it is gitignored)

node dist/index.js

### relay:start
npm run relay:start

### relay:stop
npm run relay:stop

### relay:test:health
# Auto-checks local health and tunnel health. It reads PA_APP_SERVER_URL from env/.env.dev.
npm run relay:test:health

### relay:patch:tunnel-url
# Reads the named dev tunnel magentic2-relay on port 3001 and updates PA_APP_SERVER_URL in env/.env.dev.
npm run relay:patch:tunnel-url

### teams:cache:clear
npm run teams:cache:clear

## 2. Agent Visibility Checks

# Open the current dev app directly by TEAMS_APP_ID (from env/.env.dev)
npm run app:open:dev

# If app is not visible: fully quit Desktop Teams and Microsoft 365 Copilot app,
# close Teams/Copilot browser tabs, then re-open only one client and test again.

# If still missing: run one controlled reset/reprovision cycle.
npm run app:reset:dev

## 3. Deploy
cd C:\Dev\Copilot\Magentic2
npm run compile
npm run patch:pa-spec
npm run patch:plugin-auth
npm run patch:pa-remove-card    
atk provision --env dev

## 3b. Smart Deploy (recommended)
# Runs health checks first, starts or reuses the dev tunnel, restarts relay if needed, re-checks, then deploys:
# ensure tunnel -> compile -> patch:pa-spec -> patch:plugin-auth -> patch:cinode-auth -> patch:pa-remove-card -> patch:agent-version -> atk provision --env dev
npm run deploy:smart

# Health checks only (no deploy). Also ensures relay + dev tunnel are up.
npm run deploy:smart:health

# One-command startup for Desktop/Autostart use:
# - Starts/repairs relay + tunnel
# - Patches PA_APP_SERVER_URL
# - Republishes only when URL changed (or when forced)
# - Uses the named anonymous dev tunnel: magentic2-relay
npm run startup:smart
npm run startup:smart:force

# BAT launcher for Desktop/Autostart:
# C:\Dev\Copilot\Magentic2\Start-Magentic2.bat

## 3c. VS Code Integrated Terminal Workflow
# Copilot now exposes the Magentic2 tasks at the workspace root, so they show up in Run Task.
# Use these two explicit commands from anywhere in the Copilot workspace:
#   Terminal -> Run Task -> Start It All Up
#     Starts the relay server, starts the dev tunnel, patches PA_APP_SERVER_URL, and runs relay health.
#   Terminal -> Run Task -> Deploy New Agent Version
#     Compiles, patches, versions, and provisions the dev agent.
#
# One-command full flow is still available if you want both in sequence:
#   Terminal -> Run Task -> Magentic2: Smart Deploy
# or:
#   Terminal -> Run Build Task

# If the flow fails after a reboot, run these two checks first:
#   npm run relay:patch:tunnel-url
#   npm run relay:test:health

# The older Magentic2-local task name is still in Magentic2/.vscode/tasks.json,
# but the Copilot-root task is the main entry point when VS Code is opened on C:\Dev\Copilot.

## New Deploy (from Claude)
# 3. Deploy agent
cd C:\Dev\Copilot\Magentic2
npm run compile && npm run patch:pa-spec && npm run patch:plugin-auth && npm run patch:cinode-auth && npm run patch:pa-remove-card && npm run patch:agent-version && atk provision --env dev

## 4. Test Relay (optional)
Invoke-RestMethod -Method Post -Uri "https://mw6js38k-3001.euw.devtunnels.ms/send-to-flow" -ContentType "application/json" -Body '{"text":"tunnel test"}'

## 5. Rebuild and Reprovision
npm run compile
npm run patch:pa-spec
npm run patch:plugin-auth
npm run patch:agent-version
atk provision --env dev | tee deploy.log