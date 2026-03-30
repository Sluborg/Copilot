#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function readJson(filePath) {
  return JSON.parse(readText(filePath));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + "\n", "utf8");
}

(function main() {
  const magenticRoot = path.resolve(__dirname, "..");
  const repoRoot = path.resolve(magenticRoot, "..");

  const versionPath = path.join(repoRoot, "Version.md");
  const daPath = path.join(magenticRoot, "appPackage", ".generated", "declarativeAgent.json");
  const manifestPath = path.join(magenticRoot, "appPackage", "manifest.json");

  if (!fs.existsSync(versionPath)) {
    console.error("Missing version source:", versionPath);
    process.exitCode = 1;
    return;
  }

  if (!fs.existsSync(daPath)) {
    console.error("Missing generated declarative agent:", daPath);
    process.exitCode = 1;
    return;
  }

  // Read version, skipping comment lines
  const versionLines = readText(versionPath).split(/\r?\n/);
  let versionValue = versionLines.find(line => line.trim() && !line.trim().startsWith('#'));
  if (!versionValue) {
    console.error("Version.md is empty or only contains comments.");
    process.exitCode = 1;
    return;
  }
  versionValue = versionValue.trim();

  // Versioning scheme: 1.0.MDD.incremental (no leading zero for month)
  const today = new Date();
  const m = String(today.getMonth() + 1); // no leading zero
  const dd = String(today.getDate()).padStart(2, '0');
  const monthday = m + dd;
  const versionRegex = /^(1\.0\.(\d{3})\.(\d+))$/;
  let newVersion;
  let currentMonthDay = null;
  let currentIncrement = null;
  const match = versionValue.match(versionRegex);
  if (match) {
    currentMonthDay = match[2];
    currentIncrement = parseInt(match[3], 10);
  }
  if (currentMonthDay === monthday) {
    // Same day, increment
    newVersion = `1.0.${monthday}.${currentIncrement + 1}`;
  } else {
    // New day, reset incremental
    newVersion = `1.0.${monthday}.1`;
  }

  // Write new version to Version.md (preserve comments)
  const newVersionLines = [newVersion, ...versionLines.filter(line => line.trim().startsWith('#'))];
  fs.writeFileSync(versionPath, newVersionLines.join('\n'), 'utf8');
  console.log(`Incremented version: ${versionValue} -> ${newVersion}`);

  // Patch manifest.json version
  if (fs.existsSync(manifestPath)) {
    const manifest = readJson(manifestPath);
    if (manifest.version !== newVersion) {
      manifest.version = newVersion;
      writeJson(manifestPath, manifest);
      console.log(`Updated manifest.json version to: ${newVersion}`);
    } else {
      console.log(`manifest.json version already matches: ${newVersion}`);
    }
  } else {
    console.error("Missing manifest.json:", manifestPath);
  }

  const da = readJson(daPath);
  if (typeof da.instructions !== "string") {
    console.error("declarativeAgent.json has no instructions string.");
    process.exitCode = 1;
    return;
  }

  if (!da.instructions.includes("{{version}}")) {
    console.error("Warning: The instructions string does not contain the {{version}} placeholder.");
    process.exitCode = 1;
    return;
  }

  console.log(`Version.md is set to: ${newVersion}`);
  console.log("Instructions string contains the {{version}} placeholder.");
})();
