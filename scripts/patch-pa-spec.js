#!/usr/bin/env node
/**
 * patch-pa-spec.js
 *
 * After TypeSpec compilation, inject `api-version=1` as a fixed query
 * parameter into every operation in the PA flow OpenAPI spec.
 *
 * The parameter is intentionally left without a description so it is
 * invisible to the Copilot LLM (it sees only described parameters).
 * The Copilot runtime still sends it with its default value on every call.
 *
 * This runs BEFORE patch-plugin-auth.js so the plugin manifest patching
 * happens on the already-corrected spec.
 */

const fs = require("fs");
const path = require("path");

const API_VERSION_PARAM = {
  name: "api-version",
  in: "query",
  required: true,
  schema: { type: "string", enum: ["1"], default: "1" },
};

(function main() {
  const specsDir = path.resolve(
    __dirname,
    "..",
    "appPackage",
    ".generated",
    "specs"
  );

  if (!fs.existsSync(specsDir)) {
    console.log("No specs directory found — skipping PA spec patch.");
    return;
  }

  const specFiles = fs
    .readdirSync(specsDir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => path.join(specsDir, f));

  if (specFiles.length === 0) {
    console.log("No OpenAPI spec files found — skipping PA spec patch.");
    return;
  }

  let patchedCount = 0;

  for (const specPath of specFiles) {
    const doc = JSON.parse(fs.readFileSync(specPath, "utf8"));

    // Only patch specs that contain the PA flow invoke path
    const paths = doc.paths || {};
    const paPath = Object.keys(paths).find((p) =>
      p.includes("/powerautomate/automations/direct/workflows/")
    );

    if (!paPath) continue;

    let changed = false;

    for (const method of Object.values(paths[paPath])) {
      if (typeof method !== "object" || !method.operationId) continue;

      const params = method.parameters || [];
      const alreadyHas = params.some((p) => p.name === "api-version");

      if (!alreadyHas) {
        method.parameters = [API_VERSION_PARAM, ...params];
        changed = true;
      }
    }

    if (changed) {
      fs.writeFileSync(specPath, JSON.stringify(doc, null, 2) + "\n", "utf8");
      patchedCount += 1;
      console.log(`Patched api-version into: ${path.basename(specPath)}`);
    }
  }

  console.log(
    `PA spec patch complete — ${patchedCount} file(s) updated.`
  );
})();
