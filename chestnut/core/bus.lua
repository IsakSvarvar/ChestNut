-- /chestnut/core/bus.lua
-- Chestnut Communication Bus
-- Supports both normal and AP Ender Modems (infinite range).
-- Keeps things simple and reliable.

local util = require("chestnut.core.util")
local protocol = require("chestnut.core.protocol")
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
    util.warn("No modems detected - Rednet not available.")
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
  util.debug("->", target, type, body)
  return ok
end

function M.broadcast(type, body)
  if not isOpen then M.open() end
  if not isOpen then return false, "no_modem" end
  local msg = { sender = os.getComputerID(), type = type, body = body }
  local ok = rednet.broadcast(msg, PROTOCOL)
  util.debug("-> broadcast", type, body)
  return ok
end

function M.listen(handler)
  if not isOpen then M.open() end
  if not isOpen then return false, "no_modem" end

  util.info("Listening on protocol:", PROTOCOL)

  while true do
    local id, msg, proto = rednet.receive(PROTOCOL)

    -- basic shape check
    if type(msg) ~= "table" then
      util.warn("Dropping non-table packet from", id)
      goto continue
    end

    -- protocol validation
    local ok, err = protocol.validate_packet(msg)
    if not ok then
      util.warn("Dropping invalid packet from", id, ":", err)
      goto continue
    end

    -- HARD-CODED SYSTEM HANDLER: ping/pong
    if msg.type == "ping" then
      local name = os.getComputerLabel() or "node_" .. os.getComputerID() --TODO: find universal way to track naming SUGGESTION when configuring system first time, give it a name. this variable is used everywhere.
      M.send(id, "pong", { node = name })
      goto continue
    end

    -- application-level handling
    util.debug("<-", msg.type, "from", id)
    local success, stop = pcall(handler, msg.type, msg.body, id)
    if not success then
      util.error("Handler error:", stop)
    end
    if stop then
      util.info("Listener stopped by handler.")
      break
    end

    ::continue::
  end
end


function M.is_open()
  return isOpen
end

return M