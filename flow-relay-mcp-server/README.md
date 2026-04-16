# flow-relay-mcp-server

Relay messages to a Power Automate webhook. Dual-mode: MCP (stdio) for Claude/Copilot MCP clients, REST (HTTP) for Agent Toolkit via OpenAPI.

## Setup

```bash
npm install
npm run build
```

## Config

Copy `.env.example` to `.env` and set `FLOW_WEBHOOK_URL` to your signed Power Automate callback URL.

## Run

### MCP mode (stdio) — for Claude Code, Copilot Chat, etc.
```bash
FLOW_WEBHOOK_URL="https://..." node dist/index.js
```

### HTTP mode — for Agent Toolkit + tunnel
```bash
FLOW_WEBHOOK_URL="https://..." TRANSPORT=http PORT=3000 node dist/index.js
```

Then expose via devtunnel:
```bash
devtunnel host -p 3000 --allow-anonymous
```

Update the `servers[0].url` in `openapi.yaml` with the tunnel URL.

## Endpoints (HTTP mode)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/send-to-flow` | REST relay (Agent Toolkit) |
| POST | `/mcp` | MCP streamable HTTP |
| GET | `/health` | Health check |

## Security

- Webhook URL contains a secret (`sig`). Store in env var, never commit.
- Rotate the Flow callback URL in Power Automate → update `.env` → restart server. No code changes needed.
- For production: add API key middleware to the REST endpoint.
