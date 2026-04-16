import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import { z } from "zod";

// --- Config ---

const FLOW_WEBHOOK_URL = process.env.FLOW_WEBHOOK_URL;

if (!FLOW_WEBHOOK_URL) {
  console.error("FATAL: FLOW_WEBHOOK_URL environment variable is required");
  process.exit(1);
}

const CINODE_BASIC_TOKEN = process.env.CINODE_BASIC_TOKEN;
if (!CINODE_BASIC_TOKEN) {
  console.error("WARN: CINODE_BASIC_TOKEN not set - Cinode proxy will return 503");
}

const RELAY_SECRET = process.env.RELAY_SECRET;
if (!RELAY_SECRET) {
  console.error("WARN: RELAY_SECRET not set - /send-to-flow is unprotected");
}
const CINODE_BASE = "https://api.cinode.com";

// --- Shared logic ---

interface FlowResponse {
  success: boolean;
  status: number;
  body: string;
}

async function callFlow(text: string): Promise<FlowResponse> {
  const res: Response = await fetch(FLOW_WEBHOOK_URL!, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text }),
  });

  const body = await res.text();

  return {
    success: res.ok,
    status: res.status,
    body,
  };
}

// --- Cinode helpers ---

let cinodeToken: string | null = null;
let cinodeTokenExpiry = 0;

async function getCinodeToken(): Promise<string> {
  if (cinodeToken && Date.now() < cinodeTokenExpiry - 15000) {
    return cinodeToken;
  }

  const res: Response = await fetch(`${CINODE_BASE}/token`, {
    method: "GET",
    headers: { Authorization: CINODE_BASIC_TOKEN! },
  });

  if (!res.ok) {
    throw new Error(`Cinode /token failed: ${res.status} ${await res.text()}`);
  }

  const data = (await res.json()) as { access_token: string };
  cinodeToken = data.access_token;
  cinodeTokenExpiry = Date.now() + 90000;
  return cinodeToken;
}

async function cinodeRequest(
  method: string,
  path: string,
  body?: unknown,
): Promise<{ ok: boolean; status: number; body: unknown }> {
  const token = await getCinodeToken();
  const opts: RequestInit = {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  };

  if (body !== undefined) {
    opts.body = JSON.stringify(body);
  }

  const res: Response = await fetch(`${CINODE_BASE}${path}`, opts);
  const text = await res.text();
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { ok: res.ok, status: res.status, body: json };
}

// --- MCP Server ---

const server = new McpServer({
  name: "flow-relay-mcp-server",
  version: "1.0.0",
});

const SendToFlowInput = z
  .object({
    text: z
      .string()
      .min(1, "Text must not be empty")
      .max(10000, "Text must not exceed 10000 characters")
      .describe("The message text to send to the Power Automate flow"),
  })
  .strict();

server.registerTool("send_to_flow", {
  title: "Send to Flow",
  description: `Send a text message to a Power Automate flow via webhook.

The flow receives a JSON payload with a single "text" field.
Returns the HTTP status and response body from the flow.

Args:
  - text (string): The message to send (1-10000 chars)

Returns:
  { "success": boolean, "status": number, "body": string }`,
  inputSchema: { text: SendToFlowInput.shape.text },
  annotations: {
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: true,
  },
}, async ({ text }: { text: string }) => {
  try {
    const result = await callFlow(text);
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      content: [
        {
          type: "text" as const,
          text: `Error calling flow: ${message}`,
        },
      ],
    };
  }
});

// --- Transport: stdio ---

async function runStdio(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("MCP server running on stdio");
}

// --- Transport: HTTP + REST ---

async function runHTTP(): Promise<void> {
  const app = express();
  app.use(express.json());

  // Health check
  app.get("/health", (_req, res) => {
    res.json({ status: "ok", version: "1.0.0", cinode: !!CINODE_BASIC_TOKEN });
  });

  // REST endpoint for Agent Toolkit / OpenAPI
  app.post("/send-to-flow", async (req, res) => {
    if (RELAY_SECRET && req.body.secret !== RELAY_SECRET) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    const { text } = req.body;
    if (!text || typeof text !== "string") {
      res.status(400).json({ error: "Missing or invalid 'text' field" });
      return;
    }
    try {
      const result = await callFlow(text);
      res.status(result.status >= 400 ? 502 : 200).json(result);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      res.status(500).json({ error: message });
    }
  });

  // Cinode proxy - handles all /v0.1/companies/* routes
  app.all("/v0.1/*", async (req, res) => {
    if (!CINODE_BASIC_TOKEN) {
      res.status(503).json({ error: "CINODE_BASIC_TOKEN not configured" });
      return;
    }
    try {
      const hasBody = req.method === "POST" || req.method === "PUT";
      const result = await cinodeRequest(req.method, req.path, hasBody ? req.body : undefined);
      res.status(result.status).json(result.body);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      res.status(500).json({ error: message });
    }
  });

  // MCP endpoint (streamable HTTP)
  app.post("/mcp", async (req, res) => {
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });
    res.on("close", () => transport.close());
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  });

  const port = parseInt(process.env.PORT || "3000");
  app.listen(port, () => {
    console.error(`HTTP server running on http://localhost:${port}`);
    console.error(`  MCP endpoint:  POST /mcp`);
    console.error(`  REST endpoint: POST /send-to-flow`);
    console.error(`  Health check:  GET  /health`);
  });
}

// --- Entry point ---

const transport = process.env.TRANSPORT || "stdio";
if (transport === "http") {
  runHTTP().catch((err) => {
    console.error("Server error:", err);
    process.exit(1);
  });
} else {
  runStdio().catch((err) => {
    console.error("Server error:", err);
    process.exit(1);
  });
}
