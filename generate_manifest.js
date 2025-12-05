// generate_manifest.js
// Option A: Include startup.lua + everything in chestnut/

const fs = require("fs");
const { execSync } = require("child_process");

const MANIFEST = "manifest.txt";

// --- Collect startup file (explicit) ---
const alwaysInclude = ["startup.lua"];

// --- Collect everything inside chestnut/ ---
let chestnutFiles = execSync("git ls-files chestnut", { encoding: "utf8" })
  .split(/\r?\n/)
  .filter(Boolean);

// --- Merge lists ---
let files = [...alwaysInclude, ...chestnutFiles];

// --- Sort for cleanliness ---
files.sort();

// --- Write manifest ---
fs.writeFileSync(MANIFEST, files.join("\n") + "\n", "utf8");

console.log(`Generated manifest.txt with ${files.length} entries.`);
