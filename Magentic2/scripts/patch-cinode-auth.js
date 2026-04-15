#!/usr/bin/env node
/**
 * patch-cinode-auth.js
 *
 * After TypeSpec compilation, injects ApiKeyPluginVault auth into the
 * generated plugin manifest for the Cinode API.
 *
 * Reads CINODE_API_KEY_REGISTRATION_ID from env/.env.dev (or the active env).
 * Identifies the Cinode plugin manifest by detecting api.cinode.com in the
 * corresponding OpenAPI spec.
 */

const fs = require("fs");
const path = require("path");

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n", "utf8");
}

function readEnvFile(envName) {
  const envPath = path.resolve(__dirname, "..", "env", `.env.${envName}`);
  if (!fs.existsSync(envPath)) return {};
  return Object.fromEntries(
    fs.readFileSync(envPath, "utf8")
      .split("\n")
      .filter(l => l.includes("=") && !l.startsWith("#"))
      .map(l => {
        const idx = l.indexOf("=");
        return [l.slice(0, idx).trim(), l.slice(idx + 1).trim()];
      })
  );
}

function buildPluginManifest(specDoc, pluginNamespace, specUrl) {
  const operations = [];

  for (const pathItem of Object.values(specDoc.paths || {})) {
    for (const operation of Object.values(pathItem || {})) {
      if (!operation || typeof operation !== "object") continue;
      if (!operation.operationId) continue;
      operations.push({
        name: operation.operationId,
        description: operation.description || operation.summary || operation.operationId,
        capabilities: {},
      });
    }
  }

  return {
    $schema: "https://developer.microsoft.com/json-schemas/copilot/plugin/v2.3/schema.json",
    schema_version: "v2.3",
    name_for_human: specDoc?.info?.title || pluginNamespace,
    description_for_human: specDoc?.info?.["x-description-for-human"] || specDoc?.info?.title || pluginNamespace,
    description_for_model: specDoc?.info?.["x-ai-description"] || specDoc?.info?.description || "",
    contact_email: "publisher-email@example.com",
    namespace: pluginNamespace,
    capabilities: {},
    functions: operations,
    runtimes: [
      {
        type: "OpenApi",
        auth: { type: "None" },
        spec: { url: specUrl },
        run_for_functions: operations.map((operation) => operation.name),
      },
    ],
  };
}

(function main() {
  const envName = process.argv[2] || "dev";
  const env = readEnvFile(envName);
  const registrationId = env["CINODE_API_KEY_REGISTRATION_ID"];

  if (!registrationId) {
    console.log("CINODE_API_KEY_REGISTRATION_ID not set — skipping Cinode auth patch.");
    return;
  }

  const generatedDir = path.resolve(__dirname, "..", "appPackage", ".generated");
  const specsDir = path.join(generatedDir, "specs");

  if (!fs.existsSync(specsDir)) {
    console.log("No specs directory found — skipping.");
    return;
  }

  // Find the spec that targets api.cinode.com
  const specFiles = fs.readdirSync(specsDir).filter(f => f.endsWith(".json"));
  let cinodeSpecBase = null;

  for (const specFile of specFiles) {
    const doc = JSON.parse(fs.readFileSync(path.join(specsDir, specFile), "utf8"));
    const servers = doc.servers || [];
    if (servers.some(s => (s.url || "").includes("api.cinode.com"))) {
      cinodeSpecBase = path.basename(specFile, ".json");
      break;
    }
  }

  if (!cinodeSpecBase) {
    console.log("No Cinode spec found in generated specs — skipping.");
    return;
  }

  // Find matching plugin manifest
  let pluginFile = fs.readdirSync(generatedDir)
    .find(f => f.endsWith("-apiplugin.json") && f.toLowerCase().includes("cinode"));

  if (!pluginFile) {
    const declarativeAgentPath = path.join(generatedDir, "declarativeAgent.json");
    const declarativeAgent = fs.existsSync(declarativeAgentPath)
      ? JSON.parse(fs.readFileSync(declarativeAgentPath, "utf8"))
      : null;
    const cinodeAction = declarativeAgent?.actions?.find((action) =>
      typeof action?.id === "string" && action.id.toLowerCase().includes("cinode")
    );

    if (cinodeAction?.file) {
      const specFileName = `${cinodeSpecBase}.json`;
      const specPath = path.join(specsDir, specFileName);
      const specDoc = JSON.parse(fs.readFileSync(specPath, "utf8"));
      const generatedPlugin = buildPluginManifest(specDoc, cinodeAction.id, `specs/${specFileName}`);
      const generatedPluginPath = path.join(generatedDir, cinodeAction.file);
      writeJson(generatedPluginPath, generatedPlugin);
      pluginFile = cinodeAction.file;
      console.log(`Generated missing Cinode plugin manifest: ${pluginFile}`);
    }
  }

  if (!pluginFile) {
    console.log("No Cinode plugin manifest found — skipping.");
    return;
  }

  const pluginPath = path.join(generatedDir, pluginFile);
  const plugin = JSON.parse(fs.readFileSync(pluginPath, "utf8"));

  let patched = false;
  for (const runtime of plugin.runtimes || []) {
    if (runtime?.type !== "OpenApi") continue;
    const nextAuth = { type: "ApiKeyPluginVault", reference_id: registrationId };
    if (JSON.stringify(runtime.auth) !== JSON.stringify(nextAuth)) {
      runtime.auth = nextAuth;
      patched = true;
    }
  }

  if (patched) {
    writeJson(pluginPath, plugin);
    console.log(`Patched Cinode plugin manifest with ApiKeyPluginVault (${registrationId}).`);
  } else {
    console.log("Cinode plugin manifest already up to date.");
  }
})();
