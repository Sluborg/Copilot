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
