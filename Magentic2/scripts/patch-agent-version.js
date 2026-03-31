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
  const pkgPath = path.join(magenticRoot, "package.json");
  const manifestPath = path.join(magenticRoot, "appPackage", "manifest.json");

  if (!fs.existsSync(versionPath)) {
    console.error("Missing version source:", versionPath);
    process.exitCode = 1;
    return;
  }

  // Read first non-comment, non-empty line as version
  const raw = readText(versionPath);
  const versionLine = raw.split(/\r?\n/).find(l => l.trim() && !l.trim().startsWith("#"));
  if (!versionLine) {
    console.error("No version found in Version.md.");
    process.exitCode = 1;
    return;
  }

  const current = versionLine.trim();
  const parts = current.split(".");
  if (parts.length !== 3 || parts.some(p => isNaN(parseInt(p)))) {
    console.error(`Invalid version format in Version.md: ${current}. Expected x.y.z`);
    process.exitCode = 1;
    return;
  }

  // Auto-increment patch segment
  const newVersion = `${parts[0]}.${parts[1]}.${parseInt(parts[2]) + 1}`;
  fs.writeFileSync(versionPath, raw.replace(current, newVersion), "utf8");
  console.log(`Auto-incremented version: ${current} → ${newVersion}`);

  // Patch declarativeAgent.json (valid JSON, safe to parse)
  if (!fs.existsSync(daPath)) {
    console.error("Missing generated declarative agent:", daPath);
    process.exitCode = 1;
    return;
  }

  const da = readJson(daPath);
  if (typeof da.instructions !== "string") {
    console.error("declarativeAgent.json has no instructions string.");
    process.exitCode = 1;
    return;
  }

  if (da.instructions.includes("{{version}}")) {
    da.instructions = da.instructions.replace(/\{\{version\}\}/g, newVersion);
    writeJson(daPath, da);
    console.log(`Patched declarativeAgent.json: {{version}} → ${newVersion}`);
  } else {
    console.warn("Warning: {{version}} placeholder not found in instructions.");
  }

  // Patch package.json (valid JSON, safe to parse)
  if (fs.existsSync(pkgPath)) {
    const pkg = readJson(pkgPath);
    pkg.version = newVersion;
    writeJson(pkgPath, pkg);
    console.log(`Patched package.json: version → ${newVersion}`);
  }

  // Patch manifest.json as TEXT — contains ${{TOKEN}} placeholders, not valid JSON
  if (fs.existsSync(manifestPath)) {
    const manifestText = readText(manifestPath);
    const patched = manifestText.replace(/"version"\s*:\s*"[^"]*"/, `"version": "${newVersion}"`);
    fs.writeFileSync(manifestPath, patched, "utf8");
    console.log(`Patched manifest.json: version → ${newVersion}`);
  }
})();