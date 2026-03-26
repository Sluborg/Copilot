# AGENTS.md

## Memory Loop (Mandatory)
All agents operating in this repository must follow this loop:

1. Read memory/SHARED_MEMORY.md at start.
2. Append validated learnings at the end of memory/SHARED_MEMORY.md.
3. Record rationale changes in memory/DECISIONS.md.
4. Flag disagreements in memory/CONFLICTS.md instead of silently overwriting.

## Logs
Write run summaries to the agent-specific logs under logs/:
- logs/claude.md
- logs/copilot.md
- logs/codex.md
- logs/cursor.md

## Entry Quality
- Use concise, factual entries.
- Include date and affected files.
- Preserve history; prefer append-only updates.
