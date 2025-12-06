local args = { ... }
local branch = args[1] or "main"

local REPO = "https://raw.githubusercontent.com/IsakSvarvar/ChestNut/" .. branch .. "/"
local MANIFEST = "manifest.txt"

-- Files that should not be overwritten
local EXCLUDE = {
    ["chestnut/config/system.json"] = true,
    ["chestnut/config/node.json"]   = true,
    ["chestnut/config/hub.json"]    = true,
}

local function fetch(url, out)
    local dir = fs.getDir(out)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    print("Downloading: " .. out)
    return shell.run("wget", url, out)
end

print("=== ChestNut Updater ===")
print("Fetching updated manifest...")

if not fetch(REPO .. MANIFEST, MANIFEST .. ".new") then
    error("Could not fetch manifest")
end

-- Load manifest
local f = fs.open(MANIFEST .. ".new", "r")
local files = {}
while true do
    local line = f.readLine()
    if not line then break end
    if line ~= "" then table.insert(files, line) end
end
f.close()

print("Updating " .. #files .. " files...\n")

-- Download updated versions
for _, file in ipairs(files) do
    if EXCLUDE[file] then
        print("Skipping config:", file)
    else
        fetch(REPO .. file, file .. ".new")
    end
end

print("\nApplying updates...")

-- Replace old files
for _, file in ipairs(files) do
    if not EXCLUDE[file] and fs.exists(file .. ".new") then
        if fs.exists(file) then fs.delete(file) end
        fs.move(file .. ".new", file)
        print("Updated:", file)
    end
end

-- Update manifest itself
if fs.exists(MANIFEST) then fs.delete(MANIFEST) end
fs.move(MANIFEST .. ".new", MANIFEST)

print("\nChestNut updated successfully!")
