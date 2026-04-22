# DECISIONS

## Purpose
Capture key decisions and rationale so future agents avoid re-litigating settled design choices.

## Decision Log
- 2026-03-26: Standardized memory/log loop adopted across repos (memory/ + logs/).
- 2026-04-15: Updated patch-pa-remove-card.js filter to only process *-apiplugin.json files that do not include "cinode", preventing non-PA plugin manifests from being patched.
- 2026-04-15: Cinode actions now hardcode company ID 1851 in TypeSpec routes and removed companyId parameters so the agent never asks users for company selection.
- 2026-04-15: Cinode plugin auth patch now generates cinodeapi-apiplugin.json from the emitted OpenAPI spec when the TypeSpec emitter references the action in declarativeAgent.json but omits the plugin file.
- 2026-04-15: Removed teamsApp/extendToM365 from the normal provision lifecycle and added a separate deploy lifecycle for explicit M365 extension updates, because routine provision/update was blocked by repeat timeout failures.
- 2026-04-16: Added Work IQ as a second MCP server in Magentic2/.vscode/mcp.json instead of replacing the existing cinode relay entry, to avoid regressing current relay-backed functionality.
- 2026-04-16: Added root-level Copilot tasks for Magentic2 startup and deploy so VS Code task discovery works from the actual workspace folder the user opens.
- 2026-04-16: Removed folder-open auto-start and exposed explicit top-level tasks named Start It All Up and Deploy New Agent Version to match the user's intended workflow.
- 2026-04-16: Replaced regex-based tunnel URL patching with a shared script that uses devtunnel JSON output, and wired both task files to that script for deterministic PA_APP_SERVER_URL updates.
- 2026-04-21: Added startup-smart flow that always boots relay+tunnel but conditionally republishes only when runtime tunnel URL and generated PA spec URL differ.
- 2026-04-21: Updated generate-env.js to merge toolkit-generated env/.env.dev.user into env/.env.dev and remove it automatically before env generation, preserving the single-source env policy while allowing atk provision to run.
- 2026-04-21: Removed teamsApp/extendToM365 from the routine provision/deploy lifecycle again so agent republishes complete successfully at teamsApp/update instead of failing on the known timeout-prone title extension step.
- 2026-04-21: Added a separate `m365agents.extend.yml` path for explicit web-store refresh attempts so normal deploys stay reliable while `teamsApp/extendToM365` remains isolated behind a known timeout-prone command.
- 2026-04-22: Standardized Magentic2 on the named anonymous dev tunnel `magentic2-relay` so `PA_APP_SERVER_URL` stays stable across restarts and the startup/health scripts stop binding to random tunnel IDs.
