-- ChestNut Updater - GitHub + Manifest-based
-- Works without http.get; uses only wget.
-- Overwrites program files but preserves config files.

local REPO = "https://raw.githubusercontent.com/IsakSvarvar/ChestNut/main/"
local MANIFEST = "manifest.txt"

-- Files we do NOT want to overwrite during update
local EXCLUDE = {
    ["system.json"] = true,
    ["node.json"]   = true,
    ["hub.json"]    = true,
}

----------------------------------------------------------------
-- Helper: download file using wget
----------------------------------------------------------------
local function fetch(url, out)
    local dir = fs.getDir(out)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    print("Downloading " .. out .. "...")
    local ok = shell.run("wget", url, out)
    if not ok then
        print("Failed: " .. url)
        return false
    end
    return true
end

----------------------------------------------------------------
-- Step 1: Fetch latest manifest
----------------------------------------------------------------
print("=== ChestNut Updater ===")
print("Fetching manifest...")

if not fetch(REPO .. MANIFEST, MANIFEST .. ".new") then
    error("Could not download updated manifest file.")
end

-- Load it
local f = fs.open(MANIFEST .. ".new", "r")
local list = {}
while true do
    local line = f.readLine()
    if not line then break end
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then table.insert(list, line) end
end
f.close()

print("Found " .. #list .. " files in new manifest.")

----------------------------------------------------------------
-- Step 2: Download new copies of files
----------------------------------------------------------------
local function shouldSkip(path)
    return EXCLUDE[path] == true
end

local updated = 0

for _, file in ipairs(list) do
    if shouldSkip(file) then
        print("Skipping config file:", file)
    else
        local url = REPO .. file
        fetch(url, file .. ".new")
        updated = updated + 1
    end
end

----------------------------------------------------------------
-- Step 3: Replace old files with new versions
----------------------------------------------------------------
print("\nApplying updates...")

-- Replace manifest
fs.delete(MANIFEST)
fs.move(MANIFEST .. ".new", MANIFEST)

for _, file in ipairs(list) do
    if not shouldSkip(file) then
        if fs.exists(file .. ".new") then
            if fs.exists(file) then fs.delete(file) end
            fs.move(file .. ".new", file)
            print("Updated:", file)
        end
    end
end

print("\nChestNut updated successfully!")
print("Updated files:", updated)
