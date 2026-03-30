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

  if (!fs.existsSync(versionPath)) {
    console.error("Missing version source:", versionPath);
    process.exitCode = 1;
    return;
  }

  const versionValue = readText(versionPath).trim();
  if (!versionValue) {
    console.error("Version.md is empty.");
    process.exitCode = 1;
    return;
  }

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
    da.instructions = da.instructions.replace(/\{\{version\}\}/g, versionValue);
    writeJson(daPath, da);
    console.log(`Patched declarativeAgent.json: {{version}} → ${versionValue}`);
  } else {
    console.warn("Warning: {{version}} placeholder not found in instructions.");
  }

  if (fs.existsSync(pkgPath)) {
    const pkg = readJson(pkgPath);
    if (pkg.version !== versionValue) {
      pkg.version = versionValue;
      writeJson(pkgPath, pkg);
      console.log(`Patched package.json: version → ${versionValue}`);
    }
  }
})();