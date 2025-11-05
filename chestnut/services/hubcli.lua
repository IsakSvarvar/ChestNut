-- /chestnut/services/hubcli.lua
-- Chestnut Hub Command Line Interface
-- Allows querying nodes, searching items, and requesting transfers.

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path


local util = require("chestnut.core.util")
local bus = require("chestnut.core.bus")

local cache_path = "/chestnut/cache/inventory.json"
local running = true

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function load_cache()
  if not fs.exists(cache_path) then return {} end
  local f = fs.open(cache_path, "r")
  local data = textutils.unserializeJSON(f.readAll())
  f.close()
  return data or {}
end

local function list_nodes()
  local cache = load_cache()
  print("\nNodes:")
  for node, data in pairs(cache) do
    print(" -", node, "items:", util.table_size(data.items or {}))
  end
end

local function search_item(name)
  local cache = load_cache()
  print("\nSearch results for:", name)
  for node, data in pairs(cache) do
    for item, count in pairs(data.items or {}) do
      if item:find(name) then
        print(" -", node, ":", item, "x", count)
      end
    end
  end
end

local function request_transfer(node, item, count, target)
  print("Requesting", count, item, "from", node, "to", target)
  bus.open()
  bus.send(data.sender or 0, "transfer", {item=item, count=count, target=target})
end

----------------------------------------------------------------
-- CLI loop
----------------------------------------------------------------
local function help()
  print([[
Commands:
  nodes                - list all nodes
  search <name>        - search for an item
  transfer <item> <count> <target> - request item move (from best node)
  clear                - clear screen
  exit                 - quit CLI
]])
end

local function main()
  help()
  while running do
    io.write("\n> ")
    local input = read()
    local args = {}
    for w in input:gmatch("%S+") do table.insert(args, w) end
    local cmd = args[1]

    if cmd == "nodes" then
      list_nodes()
    elseif cmd == "search" then
      search_item(args[2] or "")
    elseif cmd == "transfer" then
      local item, count, target = args[2], tonumber(args[3]), args[4]
      if not (item and count and target) then
        print("Usage: transfer <item> <count> <target>")
      else
        local cache = load_cache()
        -- pick node that has the item
        for node, data in pairs(cache) do
          if data.items and data.items[item] then
            bus.broadcast("transfer", {item=item, count=count, target=target})
            print("Requested from", node)
            break
          end
        end
      end
    elseif cmd == "clear" then
      term.clear()
      term.setCursorPos(1,1)
      help()
    elseif cmd == "exit" then
      running = false
    else
      print("Unknown command. Type 'help' for help.")
    end
  end
end

----------------------------------------------------------------
-- Start
----------------------------------------------------------------
local M = {}
function M.run()
  util.info("Starting Chestnut Hub CLI")
  main()
end
if not ... then
  M.run()
end
return M
