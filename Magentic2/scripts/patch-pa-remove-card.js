#!/usr/bin/env node
/**
 * patch-pa-remove-card.js
 *
 * Removes adaptive card / fn.capabilities.response_semantics from the invokePAFlow function
 * in the generated plugin manifest. The PA flow returns a plain JSON object
 * and the default card template produces a useless placeholder card.
 */

const fs = require("fs");
const path = require("path");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n", "utf8");
}

(function main() {
  const generatedDir = path.resolve(__dirname, "..", "appPackage", ".generated");

  const pluginFiles = fs
  .readdirSync(generatedDir)
  .filter((name) => name.endsWith("-apiplugin.json") && !name.toLowerCase().includes("cinode"));

  if (pluginFiles.length === 0) {
    console.log("No plugin manifests found — skipping PA card removal.");
    return;
  }

  let patchedCount = 0;

  for (const name of pluginFiles) {
    const pluginPath = path.join(generatedDir, name);
    const doc = readJson(pluginPath);
    const functions = doc?.functions || [];

    let changed = false;
    for (const fn of functions) {
      if (fn.name === "invokePAFlow") {
        if (fn.capabilities?.response_semantics) {
          delete fn.capabilities.response_semantics;
          changed = true;
        }
      }
    }

    if (changed) {
      writeJson(pluginPath, doc);
      patchedCount++;
      console.log(`Removed adaptive card from invokePAFlow in: ${name}`);
    }
  }

  console.log(`PA card removal complete — ${patchedCount} file(s) updated.`);
})();
