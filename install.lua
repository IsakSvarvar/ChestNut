-- argv[1] may contain the URL when using `wget run`
local args = { ... }
local selfUrl = args[1] or ""
print("installer URL arg:", textutils.serialize(args))
local branch = "main" -- fallback

-- Match ANY branch name between ChestNut/<branch>/install.lua
local detected = selfUrl:match("ChestNut/([^/]+)/install.lua")

if detected then
    branch = detected
end

local REPO = "https://raw.githubusercontent.com/IsakSvarvar/ChestNut/" .. branch .. "/"
local MANIFEST = "manifest.txt"

local function fetch(url, out)
    local dir = fs.getDir(out)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    print("Downloading: " .. out)
    return shell.run("wget", url, out)
end

print("=== ChestNut Installer ===")
print("Using branch:", branch)
print("Repository:", REPO)
print("Fetching manifest...")

if not fetch(REPO .. MANIFEST, MANIFEST) then
    error("Could not download manifest")
end

-- Load manifest
local f = fs.open(MANIFEST, "r")
local files = {}
while true do
    local line = f.readLine()
    if not line then break end
    table.insert(files, line)
end
f.close()

print("Installing " .. #files .. " files...\n")

for _, file in ipairs(files) do
    fetch(REPO .. file, file)
end

-- Auto-remove installer if present
if fs.exists("install.lua") then
    fs.delete("install.lua")
end

print("\nChestNut install complete!")
