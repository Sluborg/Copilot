#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n", "utf8");
}

function getAuthReferenceId(openApiDoc) {
  const schemes = openApiDoc?.components?.securitySchemes || {};
  for (const schemeName of Object.keys(schemes)) {
    const scheme = schemes[schemeName] || {};
    const ref = scheme["x-ai-auth-reference-id"];
    if (typeof ref === "string" && ref.trim()) {
      return ref.trim();
    }
  }
  return null;
}

function patchPluginAuth(pluginDoc, referenceId) {
  if (!Array.isArray(pluginDoc.runtimes)) return false;

  let changed = false;
  for (const runtime of pluginDoc.runtimes) {
    if (runtime?.type !== "OpenApi") continue;

    const nextAuth = {
      type: "OAuthPluginVault",
      reference_id: referenceId,
    };

    if (
      !runtime.auth ||
      runtime.auth.type !== nextAuth.type ||
      runtime.auth.reference_id !== nextAuth.reference_id
    ) {
      runtime.auth = nextAuth;
      changed = true;
    }
  }

  return changed;
}

(function main() {
  const root = path.resolve(__dirname, "..");
  const generatedDir = path.join(root, "appPackage", ".generated");
  const specsDir = path.join(generatedDir, "specs");

  // Collect all generated OpenAPI specs (handles single or multi-API output)
  let specFiles = [];
  if (fs.existsSync(specsDir)) {
    specFiles = fs.readdirSync(specsDir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => path.join(specsDir, f));
  }

  if (specFiles.length === 0) {
    console.log("No OpenAPI spec files found – skipping plugin auth patch.");
    return;
  }

  // Find a referenceId across all specs
  let referenceId = null;
  for (const specPath of specFiles) {
    const doc = readJson(specPath);
    referenceId = getAuthReferenceId(doc);
    if (referenceId) break;
  }

  if (!referenceId) {
    console.log("No x-ai-auth-reference-id found in any OpenAPI spec – no patch needed.");
    return;
  }

  const pluginFiles = fs
    .readdirSync(generatedDir)
    .filter((name) => name.endsWith("-apiplugin.json"));

  if (pluginFiles.length === 0) {
    console.error("No generated plugin manifests found in", generatedDir);
    process.exitCode = 1;
    return;
  }

  let patchedCount = 0;
  for (const name of pluginFiles) {
    const pluginPath = path.join(generatedDir, name);
    const pluginDoc = readJson(pluginPath);
    const changed = patchPluginAuth(pluginDoc, referenceId);
    if (changed) {
      writeJson(pluginPath, pluginDoc);
      patchedCount += 1;
    }
  }

  console.log(`Patched ${patchedCount}/${pluginFiles.length} plugin manifest(s) with OAuthPluginVault (${referenceId}).`);
})();
