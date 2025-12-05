-- ChestNut Bootstrap Installer (Option A)
-- This file is never installed locally; it only installs ChestNut runtime files.
-- Uses wget exclusively (works even with http disabled).

local REPO = "https://raw.githubusercontent.com/IsakSvarvar/ChestNut/main/"
local MANIFEST = "manifest.txt"

----------------------------------------------------------------
-- Helper: download a file and ensure its directory exists
----------------------------------------------------------------
local function fetch(url, out)
    local dir = fs.getDir(out)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    print("Downloading: " .. out)
    local ok = shell.run("wget", url, out)
    if not ok then
        print("FAILED downloading " .. url)
        return false
    end
    return true
end

----------------------------------------------------------------
-- Step 1: Fetch manifest
----------------------------------------------------------------
print("=== ChestNut Installer ===")
print("Fetching manifest...")

if not fetch(REPO .. MANIFEST, MANIFEST) then
    error("Could not download manifest.txt. Aborting.")
end

----------------------------------------------------------------
-- Step 2: Read manifest entries
----------------------------------------------------------------
local f = fs.open(MANIFEST, "r")
local files = {}
while true do
    local line = f.readLine()
    if not line then break end

    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then
        table.insert(files, line)
    end
end
f.close()

print("Manifest loaded. " .. #files .. " files to install.\n")

----------------------------------------------------------------
-- Step 3: Download all files listed in manifest
----------------------------------------------------------------
for _, file in ipairs(files) do
    if not fetch(REPO .. file, file) then
        print("WARNING: Could not fetch " .. file)
    end
end

----------------------------------------------------------------
-- Step 4: Cleanup installer traces
-- If installer was run via `wget run`, no cleanup needed.
-- But if run manually, this prevents the installer from staying installed.
----------------------------------------------------------------
if fs.exists("install.lua") then
    print("Removing installer (cleanup)...")
    fs.delete("install.lua")
end

----------------------------------------------------------------
-- Step 5: Finish
----------------------------------------------------------------
print("\nChestNut installed successfully!")
print("Ensure /startup.lua contains:")
print('  shell.run("startup.lua")  (if startup.lua contains the logic)')
print("or if startup.lua calls into chestnut:")
print('  shell.run("chestnut/startup.lua")')

print("\nYou can now run:")
print("  chestnut/startup.lua  (or your chosen entrypoint)")
