-- /chestnut/modules/vanilla_storage.lua
-- Chestnut vanilla storage backend
-- Works with multiple inventories connected via wired modems or direct sides.
-- No Advanced Peripherals required.

local util = require("chestnut.core.util")
local M = {}

----------------------------------------------------------------
-- Internal: discover and manage connected inventories
----------------------------------------------------------------

-- cache to avoid re-wrapping peripherals constantly
local known_inventories = {}
local last_scan = 0
local scan_interval = 30 -- seconds between rescan of peripheral list

-- returns list of peripheral objects exposing inventory methods
local function find_inventories(force)
  local now = os.clock()
  if not force and (now - last_scan) < scan_interval and #known_inventories > 0 then
    return known_inventories
  end

  known_inventories = {}
  for _, name in ipairs(peripheral.getNames()) do
    local per = peripheral.wrap(name)
    if per and per.list and per.pushItems and per.pullItems then
      table.insert(known_inventories, per)
    end
  end
  last_scan = now

  util.info("Discovered", #known_inventories, "inventory peripherals.")
  return known_inventories
end

----------------------------------------------------------------
-- Utility: iterate over all items in all connected inventories
----------------------------------------------------------------
local function all_items(callback)
  for _, inv in ipairs(find_inventories()) do
    for slot, item in pairs(inv.list()) do
      callback(inv, slot, item)
    end
  end
end

----------------------------------------------------------------
-- API: list all items across all inventories
----------------------------------------------------------------
function M.list()
  local combined = {}
  all_items(function(_, _, item)
    combined[item.name] = (combined[item.name] or 0) + item.count
  end)
  return combined
end

----------------------------------------------------------------
-- API: move items from storage to another inventory
----------------------------------------------------------------
-- target: name of target peripheral (e.g. "minecraft:hopper_2" or side)
function M.pull(itemName, count, target)
  local moved = 0
  for _, inv in ipairs(find_inventories()) do
    for slot, item in pairs(inv.list()) do
      if item.name == itemName then
        local n = inv.pushItems(target, slot, count - moved)
        moved = moved + n
        if moved >= count then
          util.info("Pulled", moved, "of", itemName, "→", target)
          return moved
        end
      end
    end
  end
  util.info("Pulled", moved, "of", itemName, "→", target)
  return moved
end

----------------------------------------------------------------
-- API: move items into storage from another inventory
----------------------------------------------------------------
function M.push(source)
  local total = 0
  for _, inv in ipairs(find_inventories()) do
    local moved = inv.pullItems(source)
    total = total + moved
    if moved > 0 then
      util.info("Pulled", moved, "items from", source, "into", peripheral.getName(inv))
    end
  end
  return total
end

----------------------------------------------------------------
-- API: get detailed info for one item (first match)
----------------------------------------------------------------
function M.getItem(name)
  local result
  all_items(function(inv, slot, item)
    if item.name == name and not result then
      result = inv.getItemDetail(slot)
    end
  end)
  return result
end

----------------------------------------------------------------
-- Diagnostics
----------------------------------------------------------------
function M.debugScan()
  local invs = find_inventories(true)
  print("Found inventories:")
  for _, per in ipairs(invs) do
    print(" -", peripheral.getName(per), "type:", peripheral.getType(per))
  end
end

return M
