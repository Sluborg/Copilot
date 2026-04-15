# DECISIONS

## Purpose
Capture key decisions and rationale so future agents avoid re-litigating settled design choices.

## Decision Log
- 2026-03-26: Standardized memory/log loop adopted across repos (memory/ + logs/).
- 2026-04-15: Updated patch-pa-remove-card.js filter to only process *-apiplugin.json files that do not include "cinode", preventing non-PA plugin manifests from being patched.
- 2026-04-15: Cinode actions now hardcode company ID 1851 in TypeSpec routes and removed companyId parameters so the agent never asks users for company selection.
- 2026-04-15: Cinode plugin auth patch now generates cinodeapi-apiplugin.json from the emitted OpenAPI spec when the TypeSpec emitter references the action in declarativeAgent.json but omits the plugin file.
- 2026-04-15: Removed teamsApp/extendToM365 from the normal provision lifecycle and added a separate deploy lifecycle for explicit M365 extension updates, because routine provision/update was blocked by repeat timeout failures.
