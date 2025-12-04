// generate_manifest.js
// Generate manifest.txt from tracked files in Git.
// - Respects .gitignore automatically via `git ls-files`
// - Excludes .gitignore, README/README.md, and (optionally) manifest.txt itself.

const { execSync } = require("child_process");
const fs = require("fs");

let output = execSync("git ls-files", { encoding: "utf8" })
  .split(/\r?\n/)
  .filter(Boolean);

// Exclude some specific files
output = output.filter((f) => {
  const lower = f.toLowerCase();
  if (f === ".gitignore") return false;
  if (lower === "readme" || lower === "readme.md") return false;
  if (lower === "manifest.txt") return false;
  return true;
});

fs.writeFileSync("manifest.txt", output.join("\n") + "\n", "utf8");
console.log(`Generated manifest.txt with ${output.length} entries.`);
