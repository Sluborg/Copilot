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

function getStockholmReleaseStamp() {
  const now = new Date();
  const date = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Europe/Stockholm",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).format(now);
  const time = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Europe/Stockholm",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false
  }).format(now);
  return `${date} ${time} (Swedish time)`;
}

(function main() {
  const magenticRoot = path.resolve(__dirname, "..");
  const repoRoot = path.resolve(magenticRoot, "..");

  const versionPath = path.join(repoRoot, "Version.md");
  const daPath = path.join(magenticRoot, "appPackage", ".generated", "declarativeAgent.json");
  const pkgPath = path.join(magenticRoot, "package.json");
  const lockPath = path.join(magenticRoot, "package-lock.json");
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

  // Versioning scheme: major.MDD.increment (MDD = month + two-digit day)
  const now = new Date();
  const todayMdd = `${now.getMonth() + 1}${String(now.getDate()).padStart(2, "0")}`;
  const major = String(parseInt(parts[0], 10));
  const currentMdd = String(parseInt(parts[1], 10));
  const currentIncrement = parseInt(parts[2], 10);
  const nextIncrement = currentMdd === todayMdd ? currentIncrement + 1 : 1;
  const newVersion = `${major}.${todayMdd}.${nextIncrement}`;
  const releaseStamp = getStockholmReleaseStamp();
  fs.writeFileSync(versionPath, raw.replace(current, newVersion), "utf8");
  console.log(`Computed version: ${current} → ${newVersion}`);

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
    console.log(`Patched declarativeAgent.json: {{version}} → ${newVersion}`);
  } else {
    console.warn("Warning: {{version}} placeholder not found in instructions.");
  }

  if (typeof da.description === "string") {
    const baseDescription = da.description.replace(/\s+\|\s+Release:\s+.*$/, "");
    da.description = `${baseDescription} | Release: ${newVersion} @ ${releaseStamp}`;
    console.log("Patched declarativeAgent.json: description release stamp updated.");
  }

  writeJson(daPath, da);

  // Patch package.json (valid JSON, safe to parse)
  if (fs.existsSync(pkgPath)) {
    const pkg = readJson(pkgPath);
    pkg.version = newVersion;
    writeJson(pkgPath, pkg);
    console.log(`Patched package.json: version → ${newVersion}`);
  }

  if (fs.existsSync(lockPath)) {
    const lock = readJson(lockPath);
    lock.version = newVersion;
    if (lock.packages?.[""]) {
      lock.packages[""].version = newVersion;
    }
    writeJson(lockPath, lock);
    console.log(`Patched package-lock.json: version → ${newVersion}`);
  }

  // Patch manifest.json as TEXT — contains ${{TOKEN}} placeholders, not valid JSON
  if (fs.existsSync(manifestPath)) {
    const manifestText = readText(manifestPath);
    const patchedVersion = manifestText.replace(/"version"\s*:\s*"[^"]*"/, `"version": "${newVersion}"`);
    const cleanedName = patchedVersion.replace(
      /(\"name\"\s*:\s*\{[\s\S]*?\"full\"\s*:\s*\")([^\"]*)(\")/,
      (_, p1, p2, p3) => {
        const baseName = p2.replace(/\s+\|\s+Release:\s+.*$/, "");
        return `${p1}${baseName}${p3}`;
      }
    );
    const patched = cleanedName.replace(
      /(\"description\"\s*:\s*\{[\s\S]*?\"full\"\s*:\s*\")([^\"]*)(\")/,
      (_, p1, p2, p3) => {
        const baseDescription = p2.replace(/\s+\|\s+Release:\s+.*$/, "");
        const nextDescription = `${baseDescription} | Release: ${newVersion} @ ${releaseStamp}`;
        return `${p1}${nextDescription}${p3}`;
      }
    );
    fs.writeFileSync(manifestPath, patched, "utf8");
    console.log(`Patched manifest.json: version → ${newVersion}, description release stamp updated.`);
  }
})();