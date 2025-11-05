-- /chestnut/services/hub.lua
-- Chestnut Hub Service
-- Handles node inventory aggregation, online/offline tracking,
-- queued job replay, and command routing.

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path

local util = require("chestnut.core.util")
local bus = require("chestnut.core.bus")

local M = {}

----------------------------------------------------------------
-- Config & defaults
----------------------------------------------------------------
local hub_cfg = util.load_json("/chestnut/config/hub.json", {
  scan_interval = 10,                -- screen refresh rate (seconds)
  save_interval = 30,                -- cache save interval
  cache_path = "/chestnut/cache/inventory.json",
  job_cache_path = "/chestnut/cache/pending_jobs.json",
  ping_interval = 20,                -- how often hub sends pings
  offline_timeout = 60               -- seconds until a node is considered offline
})

----------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------
local inventory_cache = {}   -- last known inventories
local node_status = {}       -- { [node] = { online=true, last_seen=0, sender=id } }
local pending_jobs = {}      -- { [node] = { {type, body}, ... } }
local running = true

----------------------------------------------------------------
-- === Cache Management ===
----------------------------------------------------------------
local function save_cache()
  util.save_json(hub_cfg.cache_path, inventory_cache)
  util.info("Cache saved:", hub_cfg.cache_path)
end

local function load_cache()
  inventory_cache = util.load_json(hub_cfg.cache_path, {}) or {}
end

local function save_jobs()
  util.save_json(hub_cfg.job_cache_path, pending_jobs)
end

local function load_jobs()
  pending_jobs = util.load_json(hub_cfg.job_cache_path, {}) or {}
end

----------------------------------------------------------------
-- === Node Tracking ===
----------------------------------------------------------------
local function mark_online(node, sender)
  node_status[node] = node_status[node] or {}
  node_status[node].online = true
  node_status[node].last_seen = os.clock()
  node_status[node].sender = sender
end

local function mark_offline(node)
  if node_status[node] and node_status[node].online then
    node_status[node].online = false
    util.warn("Node", node, "marked offline (timeout).")
  end
end

----------------------------------------------------------------
-- === Job Queue System ===
----------------------------------------------------------------
local function queue_job(node, type, body)
  pending_jobs[node] = pending_jobs[node] or {}
  table.insert(pending_jobs[node], { type = type, body = body })
  util.warn("Queued job for", node, ":", type)
  save_jobs()
end

local function flush_jobs(node)
  if not pending_jobs[node] or #pending_jobs[node] == 0 then return end
  local id = node_status[node] and node_status[node].sender
  if not id then return end

  util.info("Flushing", #pending_jobs[node], "queued job(s) for", node)
  for _, job in ipairs(pending_jobs[node]) do
    bus.send(id, job.type, job.body)
    util.debug("→ replayed", job.type, "to", node)
  end
  pending_jobs[node] = {}
  save_jobs()
end

----------------------------------------------------------------
-- === Message Handling ===
----------------------------------------------------------------
local function on_message(type, body, sender)
	if type == "node_update" then
		mark_online(body.node, sender)
		inventory_cache[body.node] = {
			items = body.items,
			timestamp = body.timestamp,
			sender = sender
		}
		util.info("Update from", body.node, ":", util.table_size(body.items), "items.")
		flush_jobs(body.node)

	elseif type == "pong" then
		mark_online(body.node, sender)
		util.debug("Pong from", body.node)

	elseif type == "transfer_result" then
		mark_online(body.node, sender)
		util.info("Transfer result from", body.node, ":", body.moved, body.item)

	elseif type == "whois_hub" then
		bus.send(sender, "hub_hello", { node = "hub", id = os.getComputerID() })

	elseif type == "query_inventory" then
		bus.send(sender, "inventory_data", inventory_cache)

	elseif type == "request_item" then
		-- future expansion for queued requests
		util.debug("Received request_item from", sender)

	elseif type == "list_inventories_request" then
		-- terminal asking for all node inventories
		util.debug("Inventory list request from", sender)
		for node, data in pairs(node_status) do
			if data.online and data.sender then
				bus.send(data.sender, "list_inventories", {})
			end
		end
		M._pending_list_request = sender

	elseif type == "inventory_list" then
		-- node replied with its inventories
		if M._pending_list_request then
			bus.send(M._pending_list_request, "inventory_list_result", body)
		end

	else
		util.warn("Unhandled message:", type)
	end
end

----------------------------------------------------------------
-- === Background Threads ===
----------------------------------------------------------------
-- Periodically send pings to all known nodes
local function pinger()
  while running do
    for node, data in pairs(inventory_cache) do
      local id = node_status[node] and node_status[node].sender
      if id then
        bus.send(id, "ping", { hub = "main" })
      end
    end
    sleep(hub_cfg.ping_interval)
  end
end

-- Detect offline nodes by timeout
local function offline_watcher()
  while running do
    local now = os.clock()
    for node, stat in pairs(node_status) do
      if stat.online and (now - (stat.last_seen or 0)) > hub_cfg.offline_timeout then
        mark_offline(node)
      end
    end
    sleep(10)
  end
end

-- Periodically save cache
local function autosave()
  while running do
    sleep(hub_cfg.save_interval)
    save_cache()
    save_jobs()
  end
end

-- Text-mode UI
local function display()
  while running do
    local w, h = term.getSize()

    -- clear and reset cursor to top
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    -- Header
    print("Chestnut Hub Dashboard")
    print(("Time: %s\n"):format(util.iso_now()))

    -- Node status area (fixed height)
    print("Nodes:")
    local line = 4
    for node, data in pairs(inventory_cache) do
      if line > math.floor(h / 2) then break end -- top half for nodes
      term.setCursorPos(1, line)
      term.clearLine()
      local status = (node_status[node] and node_status[node].online) and "ONLINE" or "OFFLINE"
      local color = (status == "ONLINE") and colors.green or colors.red
      if term.isColor() then term.setTextColor(color) end
      io.write(("  %-10s %-7s (%3d items)\n"):format(node, status, util.table_size(data.items or {})))
      if term.isColor() then term.setTextColor(colors.white) end
      line = line + 1
    end

    -- Divider
    term.setCursorPos(1, line)
    term.clearLine()
    print(string.rep("-", w))
    line = line + 1

    -- Recent logs (bottom half)
    local logs = util.get_recent_logs()
    local maxLogs = math.min(#logs, h - line - 1)
    for i = 1, maxLogs do
      term.setCursorPos(1, line + i - 1)
      term.clearLine()
      io.write(" " .. logs[i] .. "\n")
    end

    sleep(hub_cfg.scan_interval)
  end
end




----------------------------------------------------------------
-- === Public API ===
----------------------------------------------------------------
-- Send a command now, or queue it if node is offline
function M.send_or_queue(node, type, body)
  if node_status[node] and node_status[node].online then
    local id = node_status[node].sender
    if id then
      bus.send(id, type, body)
      util.debug("→", node, type, "(direct)")
    else
      queue_job(node, type, body)
    end
  else
    queue_job(node, type, body)
  end
end

----------------------------------------------------------------
-- === Main ===
----------------------------------------------------------------
function M.run()
  util.info("Starting Chestnut Hub Service")
  bus.open()
  load_cache()
  load_jobs()
  parallel.waitForAny(
    function() bus.listen(on_message) end,
    pinger,
    offline_watcher,
    autosave,
    display
  )
end
if not ... then
  M.run()
end
return M
