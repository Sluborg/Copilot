# Agent Log

Append-only log for run summaries.

## Entry Template
- Timestamp:
- Task:
- Files:
- Result:
- Follow-up:

- Timestamp: 2026-04-15
- Task: Fix patch-pa-remove-card.js to restrict processing to PA manifest scope and identify generated PA plugin manifest filename.
- Files: Magentic2/scripts/patch-pa-remove-card.js; memory/SHARED_MEMORY.md; memory/DECISIONS.md
- Result: Updated plugin file filter to exclude filenames containing "cinode"; confirmed generated apiplugin files and identified paflowapi-apiplugin.json as the PA manifest filename.
- Follow-up: Run the full compile/patch/provision chain again from Magentic2 if needed.

- Timestamp: 2026-04-15
- Task: Make Cinode actions always use company ID 1851 without prompting user.
- Files: Magentic2/src/agent/actions/cinode.tsp; memory/SHARED_MEMORY.md; memory/DECISIONS.md
- Result: Removed companyId path parameter from all Cinode actions, hardcoded /companies/1851/ routes, verified successful TypeSpec compile and generated OpenAPI routes.
- Follow-up: Run full publish chain for next deployment to propagate updated action schema.

- Timestamp: 2026-04-15
- Task: Expose Cinode and Flow actions in the packaged Magentic2 agent and fix repeat provision/publish timeout path.
- Files: Magentic2/src/agent/main.tsp; Magentic2/src/agent/prompts/instructions.tsp; Magentic2/scripts/patch-cinode-auth.js; Magentic2/scripts/patch-agent-version.js; Magentic2/m365agents.yml
- Result: Moved Cinode ops into the agent namespace, added explicit instructions for Fujitsu/Cinode and Power Automate flow usage, generated missing cinodeapi-apiplugin.json from the OpenAPI spec, patched Cinode auth, corrected release stamping to description fields, and verified atk provision --env dev completed successfully.
- Follow-up: Use atk deploy --env dev only when you explicitly want to refresh the Microsoft 365 title extension path.

- Timestamp: 2026-04-16
- Task: Add Work IQ MCP wiring in Magentic2 without breaking existing relay-backed MCP configuration.
- Files: Magentic2/.vscode/mcp.json; memory/SHARED_MEMORY.md; memory/DECISIONS.md
- Result: Kept the existing cinode HTTP MCP entry intact and added workiq as a second server entry using npx @microsoft/workiq@latest mcp; validated the JSON file after the edit.
- Follow-up: Reload Copilot Chat tools in VS Code and attempt the Work IQ auth flow from Agent mode to confirm browser-based sign-in behavior.

- Timestamp: 2026-04-16
- Task: Expose Magentic2 startup and deploy tasks from the Copilot workspace root so they appear in VS Code Run Task.
- Files: .vscode/tasks.json; Magentic2/PsCommands.md; memory/SHARED_MEMORY.md; memory/DECISIONS.md
- Result: Added root-level Copilot tasks for relay, dev tunnel, tunnel URL patch, health check, auto-start on folder open, and full smart deploy; updated the Magentic2 command guide to point at the new root task entry point.
- Follow-up: On next VS Code launch, allow automatic tasks once so Magentic2: Resume Dev Stack can start automatically.

- Timestamp: 2026-04-16
- Task: Split the Copilot-root Magentic2 workflow into two explicit commands matching the user's preferred wording.
- Files: .vscode/tasks.json; Magentic2/PsCommands.md; memory/SHARED_MEMORY.md; memory/DECISIONS.md
- Result: Replaced folder-open auto-start with an explicit Start It All Up task, exposed Deploy New Agent Version as the separate deploy command, and kept Magentic2: Smart Deploy as the one-command combined path.
- Follow-up: Run Start It All Up first after a reboot, then run Deploy New Agent Version when you want to publish a fresh build.

- Timestamp: 2026-04-16
- Task: Automate and stabilize dev tunnel URL updates after tunnel rotation.
- Files: Magentic2/scripts/patch-tunnel-url.ps1; .vscode/tasks.json; Magentic2/.vscode/tasks.json; Magentic2/package.json; Magentic2/PsCommands.md; memory/SHARED_MEMORY.md; memory/DECISIONS.md
- Result: Added a shared tunnel patch script using devtunnel JSON output, wired both VS Code task files to it, added npm run relay:patch:tunnel-url, and validated relay:test:health passes with the newly patched tunnel URL.
- Follow-up: If flow calls fail, run relay:patch:tunnel-url then relay:test:health before redeploying.
