-- /chestnut/services/terminal.lua
-- Chestnut Terminal (Kiosk UI)
-- Connects to Hub for viewing and requesting storage items.

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path

local util = require("chestnut.core.util")
local bus = require("chestnut.core.bus")

-------------------------------------------------------------
-- Config
-------------------------------------------------------------
local REFRESH_INTERVAL = 15     -- seconds between cache refresh
local HUB_TIMEOUT = 5           -- seconds wait for hub reply
local running = true

-------------------------------------------------------------
-- State
-------------------------------------------------------------
local hub_id = nil
local inventory_cache = {}

-------------------------------------------------------------
-- Helpers
-------------------------------------------------------------
local function find_hub()
  util.info("Searching for hub...")
  bus.open()
  bus.broadcast("whois_hub", { role="terminal" })
  local id, msg = rednet.receive("chestnut", HUB_TIMEOUT)
  if type(msg) == "table" and msg.type == "hub_hello" then
    util.info("Connected to hub ID:", id)
    return id
  else
    util.warn("No hub found.")
    return nil
  end
end

local function flatten_inventory(data)
  -- Accepts either a flat map already, or the hub's per-node cache
  -- Hub format: cache[node] = { items = { [name]=count }, timestamp=..., sender=... }
  local flat = {}

  -- If it's already flat (value is a number), just return it
  local anyK, anyV = next(data)
  if type(anyV) == "number" then return data end

  -- Otherwise, merge per-node item maps
  for _, nodeEntry in pairs(data or {}) do
    local items = nodeEntry.items or {}
    for name, count in pairs(items) do
      flat[name] = (flat[name] or 0) + (count or 0)
    end
  end
  return flat
end


local function fetch_inventory()
  if not hub_id then return end
  bus.send(hub_id, "query_inventory", { request = "all" })
  local id, msg = rednet.receive("chestnut", HUB_TIMEOUT)
  if id == hub_id and type(msg) == "table" and msg.type == "inventory_data" then
    -- msg.body may be per-node cache; flatten it
    inventory_cache = flatten_inventory(msg.body or {})
    util.debug("Received inventory data: " .. tostring((function(t) local c=0 for _ in pairs(t) do c=c+1 end; return c end)(inventory_cache)) .. " items")
  else
    util.warn("No inventory data received.")
  end
end


local function render_inventory(filter)
  term.clear()
  term.setCursorPos(1,1)
  print("Chestnut Storage Terminal\n")
  local count = 0
  for name, qty in pairs(inventory_cache) do
    if (not filter) or name:find(filter) then
      print(string.format(" - %s x%d", name, qty))
      count = count + 1
      if count > 18 then break end
    end
  end
  if count == 0 then print("(no items match)") end
  print("\nType help for commands.")
end

-------------------------------------------------------------
-- Command Loop
-------------------------------------------------------------
local function handle_input()
  while running do
    io.write("\n> ")
    local input = read()
    local args = {}
    for w in input:gmatch("%S+") do table.insert(args, w) end
    local cmd = args[1]

    if cmd == "exit" then
      running = false
      break
    elseif cmd == "refresh" then
      fetch_inventory()
      render_inventory()
    elseif cmd == "search" then
      render_inventory(args[2] or "")
    elseif cmd == "request" then
      local item, count, target = args[2], tonumber(args[3]), args[4]
      if not (item and count and target) then
        print("Usage: request <item> <count> <target>")
      else
        bus.send(hub_id, "request_item", { item=item, count=count, target=util.resolve_target(target) })
        print("Request sent to hub.")
      end
    elseif cmd == "help" then
      print([[
Commands:
  refresh               - reload item list
  search <name>         - filter items by substring
  request <item> <n> <target> - ask hub to send item
  exit                  - quit terminal
]])
    elseif cmd == "label" then
      local sub = args[2]
    if sub == "list" then
      local map = util.get_label_map()
      print("\nDefined labels:")
      for alias, per in pairs(map) do
       print((" - %-12s -> %s"):format(alias, per)) end
       if next(map) == nil then print("(none defined)") end

    elseif sub == "set" then
      local alias, periph = args[3], args[4]
      if not alias or not periph then
        print("Usage: label set <alias> <peripheral_name>")
      else
        local ok, err = util.set_label(alias, periph)
        if ok then
          print(("Linked '%s' → %s"):format(alias, periph))
        else
          print("Error:", err)
        end
      end
      else
      print([[Usage:
label list                  - show all labels
label set <alias> <name>    - link alias to peripheral name
Examples:
label set ingots minecraft:chest_1
label list
]])
      end
    elseif cmd == "listinv" then
      bus.send(hub_id, "list_inventories_request", {})
      print("Requesting inventory list from nodes...")

      local t0 = os.clock()
      while os.clock() - t0 < 5 do
        local id, msg = rednet.receive("chestnut", 5)
        if id and msg and msg.type == "inventory_list_result" then
          local node = msg.body.node or "unknown"
          print(("\nNode: %s"):format(node))
          for _, inv in ipairs(msg.body.inventories or {}) do
            print((" - %s (%s)"):format(inv.name, inv.type))
          end
        end
      end

    else
      print("Unknown command. Type 'help'.")
    end
  end
end

-------------------------------------------------------------
-- Main
-------------------------------------------------------------
local function main()
  util.info("Starting Chestnut Terminal")
  hub_id = find_hub()
  if not hub_id then
    util.error("Could not find hub. Exiting.")
    return
  end
  fetch_inventory()
  render_inventory()

  parallel.waitForAny(
    handle_input,
    function()
      while running do
        sleep(REFRESH_INTERVAL)
        fetch_inventory()
      end
    end
  )

  util.info("Terminal shutting down.")
end

if not ... then main() end
return { run = main }