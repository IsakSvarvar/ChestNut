-- ChestNut Installer from GitHub (No http.get needed)
-- Uses only wget (works even when HTTP API is disabled)

local REPO = "https://raw.githubusercontent.com/IsakSvarvar/ChestNut/main/"
local MANIFEST = "manifest.txt"

local function fetch(url, out)
    -- Ensure directory exists
    local dir = fs.getDir(out)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    print("Downloading " .. out .. "...")
    local ok = shell.run("wget", url, out)
    if not ok then
        print("Failed to download: " .. url)
        return false
    end
    return true
end

print("=== ChestNut Installer ===")
print("Downloading manifest...")

if not fetch(REPO .. MANIFEST, MANIFEST) then
    error("Could not download manifest.txt")
end

-- Read manifest
local list = {}
local f = fs.open(MANIFEST, "r")
while true do
    local line = f.readLine()
    if not line then break end
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then
        table.insert(list, line)
    end
end
f.close()

print("Found " .. #list .. " files to install.")
print("Starting download...")

-- Download all files in manifest
for _, file in ipairs(list) do
    local url = REPO .. file
    if not fetch(url, file) then
        print("Error downloading: " .. file)
    end
end

print("\nChestNut installed successfully!")
print("You can now run it depending on your setup.")
