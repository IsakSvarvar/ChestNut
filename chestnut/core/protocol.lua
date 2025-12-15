-- Chestnut protocol registry + message validation helpers
local M = {}

M.VERSION = 1
M.STRICT = false -- rejects unknown keys in body (t.ex. typos)

----------------------------------------------------------------
-- Schema registry
-- Each message type defines required and optional keys for msg.body
----------------------------------------------------------------
M.SCHEMAS = {
  -- === Discovery / identity ===
  whois_hub = {
    required = {},
    optional = { "sender_name" }, -- name of requester
  },

  hub_hello = {
    required = { "node", "id" }, -- node="hub", id=<computer id>
    optional = { "version" }, -- protocol version
  },

  -- === Ping ===
  ping = {
    required = {},
    optional = {},
  },

  pong = {
    required = { "node" },
    optional = {},
  },

  -- === Inventory ===
  node_update = {
    required = { "node", "items", "timestamp" },
    optional = { "node_type", "version" },
  },

  query_inventory = {
    required = {},
    optional = { "request" }, -- e.g. "all", "flat", "node:<name>"
  },

  inventory_data = {
    required = { "data" }, -- payload (flat map OR hub cache)
    optional = { "format" }, -- "flat" | "per_node"
  },

  -- === Transfers ===
  transfer = {
    required = { "item", "count", "target" },
    optional = { "request_id", "requester" }, -- requester is sender id or terminal name
  },

  transfer_result = {
    required = { "node", "item", "moved" },
    optional = { "request_id", "target" },
  },

  -- === Higher-level requests (hub decides routing) ===
  request_item = {
    required = { "item", "count", "target" },
    optional = { "request_id" },
  },

  -- === Inventory peripheral listing (for debugging/UI) ===
  list_inventories_request = {
    required = {},
    optional = {},
  },

  inventory_list = {
    required = { "node", "inventories" }, -- inventories = { {name=..., type=...}, ... }
    optional = {},
  },
}

----------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------
local function to_set(list)
  local s = {}
  for _, k in ipairs(list or {}) do s[k] = true end
  return s
end

local function is_table(x) return type(x) == "table" end

----------------------------------------------------------------
-- Public: validate a body against schema for message type
-- Returns: ok:boolean, err:string|nil
----------------------------------------------------------------
function M.validate_body(msg_type, body)
  local schema = M.SCHEMAS[msg_type]
  if not schema then
    return false, ("unknown message type '%s'"):format(tostring(msg_type))
  end
  if not is_table(body) then
    return false, "body must be a table"
  end

  -- required fields
  for _, key in ipairs(schema.required or {}) do
    if body[key] == nil then
      return false, ("missing required field '%s'"):format(key)
    end
  end

  -- strict mode: reject unknown keys
  if M.STRICT then
    local allowed = to_set(schema.required)
    for k, _ in pairs(to_set(schema.optional)) do allowed[k] = true end
    for k, _ in pairs(body) do
      if not allowed[k] then
        return false, ("unknown field '%s' for type '%s'"):format(tostring(k), tostring(msg_type))
      end
    end
  end

  return true
end

----------------------------------------------------------------
-- Public: build a normalized packet for sending
-- Packet shape matches your bus.lua: { type=..., body=..., v=... }
----------------------------------------------------------------
function M.make(msg_type, body)
  local ok, err = M.validate_body(msg_type, body or {})
  if not ok then
    error(("protocol.make(%s) failed: %s"):format(tostring(msg_type), tostring(err)), 2)
  end

  local packet = {
    type = msg_type,
    body = body or {},
    v = M.VERSION,
  }
  return packet
end

----------------------------------------------------------------
-- Public: validate an inbound packet (as received from bus)
-- Expected shape: { sender=?, type=?, body=? }
----------------------------------------------------------------
function M.validate_packet(packet)
  if not is_table(packet) then return false, "packet must be a table" end
  if packet.type == nil then return false, "packet missing 'type'" end
  if packet.body == nil then return false, "packet missing 'body'" end
  return M.validate_body(packet.type, packet.body)
end

return M