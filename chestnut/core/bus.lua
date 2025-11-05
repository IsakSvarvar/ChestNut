-- /chestnut/core/bus.lua
-- Chestnut Communication Bus
-- Supports both normal and AP Ender Modems (infinite range).
-- Keeps things simple and reliable.

local util = require("chestnut.core.util")
local M = {}

local PROTOCOL = "chestnut"
local modemList = {}
local isOpen = false

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function find_modems()
  local found = {}
  for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "modem" or t == "ender_modem" then
      table.insert(found, { name = name, type = t })
    end
  end
  return found
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------
function M.open()
  if isOpen then return true end
  modemList = find_modems()

  if #modemList == 0 then
    util.warn("No modems detected — Rednet not available.")
    return false
  end

  util.info("=== Initializing Communication Bus ===")
  for _, m in ipairs(modemList) do
    local ok, err = pcall(rednet.open, m.name)
    if ok then
      util.info(("Opened modem on: %s"):format(m.name))
    else
      util.error(("Failed to open modem on %s: %s"):format(m.name, tostring(err)))
    end
  end

  isOpen = true
  return true
end

function M.close()
  if not isOpen then return end
  for _, m in ipairs(modemList) do
    pcall(rednet.close, m.name)
  end
  isOpen = false
  util.info("Rednet connections closed.")
end

function M.send(target, type, body)
  if not isOpen then M.open() end
  if not isOpen then return false, "no_modem" end
  local msg = { sender = os.getComputerID(), type = type, body = body }
  local ok = rednet.send(target, msg, PROTOCOL)
  util.debug("→", target, type, body)
  return ok
end

function M.broadcast(type, body)
  if not isOpen then M.open() end
  if not isOpen then return false, "no_modem" end
  local msg = { sender = os.getComputerID(), type = type, body = body }
  local ok = rednet.broadcast(msg, PROTOCOL)
  util.debug("→ broadcast", type, body)
  return ok
end

function M.listen(handler)
  if not isOpen then M.open() end
  if not isOpen then return false, "no_modem" end

  util.info("Listening on protocol:", PROTOCOL)
  while true do
    local id, msg, proto = rednet.receive(PROTOCOL)
    if type(msg) == "table" and msg.type then
      util.debug("←", msg.type, "from", id)
      local ok, stop = pcall(handler, msg.type, msg.body, id)
      if not ok then util.error("Handler error:", stop) end
      if stop then
        util.info("Listener stopped by handler.")
        break
      end
    else
      util.warn("Received malformed message from", id)
    end
  end
end

function M.is_open()
  return isOpen
end

return M