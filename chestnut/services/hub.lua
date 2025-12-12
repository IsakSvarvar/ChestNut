-- /chestnut/services/hub.lua
-- Chestnut Hub Service (ping handled by bus)

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path

local util = require("chestnut.core.util")
local bus  = require("chestnut.core.bus")

----------------------------------------------------------
-- Config
----------------------------------------------------------
local hub_cfg = util.load_json("/chestnut/config/hub.json", {
  scan_interval     = 10,
  save_interval     = 30,
  cache_path        = "/chestnut/cache/inventory.json",
  job_cache_path    = "/chestnut/cache/pending_jobs.json",
  ping_interval     = 20,
  offline_timeout   = 60
})

----------------------------------------------------------
-- State
----------------------------------------------------------
local inventory_cache = {}
local node_status     = {}
local pending_jobs    = {}
local running         = true

----------------------------------------------------------
-- Cache helpers
----------------------------------------------------------
local function save_cache()
  util.save_json(hub_cfg.cache_path, inventory_cache)
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

----------------------------------------------------------
-- Node tracking
----------------------------------------------------------
local function mark_online(node, sender)
  node_status[node] = node_status[node] or {}
  node_status[node].online    = true
  node_status[node].last_seen = os.clock()
  node_status[node].sender    = sender
end

local function mark_offline(node)
  if node_status[node] and node_status[node].online then
    node_status[node].online = false
    util.warn("Node", node, "marked offline.")
  end
end

----------------------------------------------------------
-- Message handling
----------------------------------------------------------
local function on_message(type, body, sender)
  if type == "node_update" then
    mark_online(body.node, sender)
    inventory_cache[body.node] = {
      items     = body.items,
      timestamp = body.timestamp,
      sender    = sender
    }
    util.info("Update from", body.node)

  elseif type == "pong" then
    mark_online(body.node, sender)

  elseif type == "transfer_result" then
    mark_online(body.node, sender)
    util.info("Transfer result from", body.node, body.moved, body.item)

  elseif type == "whois_hub" then
    bus.send(sender, "hub_hello", {
      node = "hub",
      id   = os.getComputerID()
    })

  elseif type == "query_inventory" then
    bus.send(sender, "inventory_data", {
      data = inventory_cache
    })

  else
    util.warn("Unhandled message:", type)
  end
end

----------------------------------------------------------
-- Background threads
----------------------------------------------------------
local function pinger()
  while running do
    for node, stat in pairs(node_status) do
      if stat.sender then
        bus.send(stat.sender, "ping", {})
      end
    end
    sleep(hub_cfg.ping_interval)
  end
end

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

----------------------------------------------------------
-- Main
----------------------------------------------------------
local M = {}
function M.run()
  util.info("Starting Chestnut Hub")
  bus.open()
  load_cache()
  load_jobs()
  parallel.waitForAny(
    function() bus.listen(on_message) end,
    pinger,
    offline_watcher
  )
end

if not ... then M.run() end
return M
