-- /chestnut/core/main.lua
-- Chestnut Core Launcher

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path
local util = require("chestnut.core.util")

----------------------------------------------------------
-- Logging
----------------------------------------------------------
util.set_log_level("info")
util.set_log_file("/chestnut/data/logs/core.log")

----------------------------------------------------------
-- Services
----------------------------------------------------------
local SERVICES = {
  { name = "Hub",          path = "/chestnut/services/hub.lua" },
  { name = "Storage Node", path = "/chestnut/services/storagenode.lua" },
  { name = "Terminal",     path = "/chestnut/services/terminal.lua" },
  { name = "Hub CLI",      path = "/chestnut/services/hubcli.lua" },
}

----------------------------------------------------------
-- UI helpers
----------------------------------------------------------
local function clear()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
end

local function draw_menu()
  clear()
  print("Chestnut Launcher\n")

  for i, svc in ipairs(SERVICES) do
    print(("%d) %s"):format(i, svc.name))
  end
  print(("%d) Shell"):format(#SERVICES + 1))

  print("\nSelect option:")
end

----------------------------------------------------------
-- Main loop
----------------------------------------------------------
while true do
  draw_menu()
  write("> ")
  local choice = tonumber(read())

  if choice and choice >= 1 and choice <= #SERVICES then
    local svc = SERVICES[choice]
    clear()
    util.info("Starting service:", svc.name)
    print("Start
