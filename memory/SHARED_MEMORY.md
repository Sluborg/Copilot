# SHARED_MEMORY

## Purpose
Shared discoveries and reusable patterns for all coding agents in this repo.

## Start-of-Run Checklist
- Read this file before making changes.
- Reuse existing patterns before creating new ones.
- Append new learnings at the end after validation.

## Entries
- 2026-03-26: Baseline initialized.
- 2026-04-15: In Magentic2, patch scripts that scan appPackage/.generated should filter apiplugin files to exclude names containing "cinode" when targeting PA-only behavior.
- 2026-04-15: Cinode action routes in Magentic2 can be hardcoded to /companies/1851/... to remove companyId from the model-facing API and stop user prompts for tenant ID.
- 2026-04-15: If TypeSpec emits a declarativeAgent action entry for Cinode but omits the corresponding *-apiplugin.json file, generate the plugin manifest from the emitted OpenAPI spec before applying auth patches.
- 2026-04-15: For routine Magentic2 updates, provision can stop at teamsApp/update; keep extendToM365 in a separate deploy lifecycle to avoid repeated timeout failures during normal republish.
