-- /chestnut/core/main.lua
-- Chestnut Core Bootstrap

package.path = "/?.lua;/?/init.lua;" .. package.path
local util = require("chestnut.core.util")

-- === 1. Startup log ===
util.set_log_level("info")
util.set_log_file("/chestnut/data/logs/core.log")

util.info("==== Chestnut Boot ====")

-- === 2. Load configuration ===
local cfg = util.load_json("/chestnut/config/settings.json", {})
util.debug("Loaded config:", cfg)

-- === 3. Detect environment ===
local computerLabel = os.getComputerLabel() or ("Computer_" .. os.getComputerID())
util.info(("Running on: %s (ID %d)"):format(computerLabel, os.getComputerID()))

-- === 4. Print summary ===
util.info("Storage provider:", cfg.storage_provider or "none")
util.info("Hub ID:", cfg.hub_id or "(none)")

-- === 5. Check paths ===
util.ensure_dir_for("/chestnut/data/logs/core.log")

-- === 6. Friendly greeting ===
term.setTextColor(colors.yellow)
print("Chestnut is online and standing by.")
term.setTextColor(colors.white)

-- === 7. Idle / hold loop ===
-- For now, just wait for Ctrl+T (terminate)
while true do
	os.pullEvent("terminate")
	util.warn("Manual terminate received - shutting down.")
	break
end

util.info("Goodbye from Chestnut.")
