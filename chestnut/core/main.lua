-- /chestnut/core/main.lua
-- Chestnut Core Launcher

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path
local util = require("chestnut.core.util")

-- Computer metadata
local COMPUTER_ID    = os.getComputerID()
local COMPUTER_LABEL = os.getComputerLabel() or "<no label>"


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
  { name = "Storage Node", path = "/chestnut/services/storagenode.lua" }
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
  print(("Computer ID   : %d"):format(COMPUTER_ID))
  print(("Computer Name : %s"):format(COMPUTER_LABEL))
  print(string.rep("-", 28))


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
    print("Starting " .. svc.name .. "...\n")

    shell.run(svc.path)

    print("\nService exited. Returning to launcher.")
    util.info("Service exited:", svc.name)
    sleep(1)

  elseif choice == #SERVICES + 1 then
    clear()
    print("Dropping to shell. Type 'reboot' to return to launcher.")
    util.info("Dropping to shell.")
    return

  else
    print("Invalid selection.")
    sleep(1)
  end
end
