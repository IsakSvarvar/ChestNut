-- /chestnut/modules/ap_storage.lua
-- Chestnut Advanced Peripherals unified storage backend
-- Supports multiple Drawer Controllers + all standard inventories
-- Safe fallback if AP not installed

local util = require("chestnut.core.util")
local M = {}

--------------------------------------------------------------
-- Internal discovery
--------------------------------------------------------------

local drawerControllers = {}
local inventories = {}

--------------------------------------------------------------
-- Detect drawers and inventories
--------------------------------------------------------------
local function scan_peripherals()
  drawerControllers = {}
  inventories = {}

  for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    local per = peripheral.wrap(name)

    if per then
      if t and t:find("storagedrawers:controller") then
        table.insert(drawerControllers, per)
      elseif type(per.list) == "function" and
             type(per.pushItems) == "function" and
             type(per.pullItems) == "function" then
        table.insert(inventories, per)
      end
    end
  end

  util.info(("AP Storage: found %d drawer controllers, %d inventories."):
    format(#drawerControllers, #inventories))
end



scan_peripherals()

--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------
local function merge_item_counts(target, name, count)
  target[name] = (target[name] or 0) + count
end

local function safe_call(fn, ...)
  local ok, res = pcall(fn, ...)
  if ok then return res else util.error("AP Storage call failed:", res) end
end

--------------------------------------------------------------
-- API: list()
--------------------------------------------------------------
function M.list()
  local combined = {}

  -- Drawer controllers
  for _, dc in ipairs(drawerControllers) do
    local list = safe_call(dc.list)
    if list then
      for _, item in pairs(list) do
        merge_item_counts(combined, item.name, item.count)
      end
    end
  end

  -- Vanilla inventories
  for _, inv in ipairs(inventories) do
    local list = safe_call(inv.list)
    if list then
      for _, item in pairs(list) do
        merge_item_counts(combined, item.name, item.count)
      end
    end
  end

  return combined
end


--------------------------------------------------------------
-- API: pull(itemName, count, target)
-- Moves items from any source (drawer or inventory) to target
--------------------------------------------------------------
function M.pull(itemName, count, target)
  local moved = 0
  local needed = count or 1

  -- Try drawers first (faster)
  for _, dc in ipairs(drawerControllers) do
    local n = safe_call(dc.extractItem, { name = itemName }, needed - moved, target)
    moved = moved + (n or 0)
    if moved >= needed then return moved end
  end

  -- Then try inventories
  for _, inv in ipairs(inventories) do
    for slot, item in pairs(inv.list()) do
      if item.name == itemName then
        local n = inv.pushItems(target, slot, needed - moved)
        moved = moved + n
        if moved >= needed then return moved end
      end
    end
  end

  util.info("Pulled", moved, "of", itemName, "→", target)
  return moved
end

--------------------------------------------------------------
-- API: push(source)
-- Moves items from source inventory → any storage
--------------------------------------------------------------
function M.push(source)
  local total = 0

  -- First push into drawers
  for _, dc in ipairs(drawerControllers) do
    local n = safe_call(dc.insertItem, source)
    total = total + (n or 0)
  end

  -- Then into vanilla inventories
  for _, inv in ipairs(inventories) do
    local n = inv.pullItems(source)
    total = total + (n or 0)
  end

  util.info("Pushed", total, "items from", source, "into storage.")
  return total
end

--------------------------------------------------------------
-- API: getItem(name)
--------------------------------------------------------------
function M.getItem(name)
  -- Search drawers first
  for _, dc in ipairs(drawerControllers) do
    local items = safe_call(dc.getAllItems)
    if items then
      for _, it in pairs(items) do
        if it.name == name then return it end
      end
    end
  end

  -- Search vanilla inventories
  for _, inv in ipairs(inventories) do
    for slot, item in pairs(inv.list()) do
      if item.name == name then
        return inv.getItemDetail(slot)
      end
    end
  end
  return nil
end

--------------------------------------------------------------
-- API: debugScan()
--------------------------------------------------------------
function M.debugScan()
  print(("Drawer controllers: %d  Inventories: %d"):format(#drawerControllers, #inventories))
  for _, dc in ipairs(drawerControllers) do
    print(" - DrawerController:", peripheral.getName(dc))
  end
  for _, inv in ipairs(inventories) do
    print(" - Inventory:", peripheral.getName(inv))
  end
end

return M