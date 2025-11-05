-- /chestnut/services/storagenode.lua
-- Chestnut StorageNode Service
-- Runs on storage computers. Reports inventory state to the hub and executes basic commands.

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path

local util = require("chestnut.core.util")
local bus = require("chestnut.core.bus")

-- Load configs
local sys_cfg = util.load_json("/chestnut/config/system.json", {})
local node_cfg = util.load_json("/chestnut/config/node.json", {})

-- Dynamic storage backend
local backend_name = node_cfg.storage_backend or "vanilla"
local storage = require("chestnut.modules." .. backend_name .. "_storage")

-- Node metadata
local NODE_NAME = node_cfg.node_name or "UnnamedNode"
local NODE_TYPE = node_cfg.node_type or "storage"
local HUB_ID = node_cfg.hub_id
local SCAN_INTERVAL = node_cfg.scan_interval or 10

local M = {}

----------------------------------------------------------
-- INTERNAL STATE
----------------------------------------------------------
local running = true
local lastReport = {}

----------------------------------------------------------
-- HELPERS
----------------------------------------------------------
local function send_update()
  local items = storage.list()
  lastReport = items
  local msg = {
    type = "node_update",
    node = NODE_NAME,
    items = items,
    timestamp = os.clock()
  }
  bus.broadcast("node_update", {
  node = NODE_NAME,
  items = items,
  timestamp = os.clock()
  })
  util.info("Sent update to hub with", util.table_size(items), "item types.")
end

local function handle_command(msg)
  if msg.type == "ping" then
    util.info("Received ping from hub.")
    bus.broadcast({type="pong", node=NODE_NAME})
  elseif msg.type == "transfer" then
    local moved = storage.pull(msg.item, msg.count, msg.target)
    util.info("Transfer:", moved, msg.item, "→", msg.target)
    bus.broadcast({type="transfer_result", node=NODE_NAME, item=msg.item, count=moved})
  else
    util.warn("Unknown command:", msg.type)
  end
end

----------------------------------------------------------
-- THREADS
----------------------------------------------------------
local function scanner()
  while running do
    send_update()
    sleep(SCAN_INTERVAL)
  end
end

local function listener()
  bus.listen(function(msgType, body, sender)
    if msgType=="ping" then
      util.info("Ping from",sender)
      bus.send(sender,"pong",{node=NODE_NAME})
      
    elseif msgType=="transfer" then
      local moved=storage.pull(body.item,body.count,body.target)
      util.info("Transfer",moved,body.item,"→",body.target)
      bus.send(sender,"transfer_result",{node=NODE_NAME,item=body.item,moved=moved})
    
    end
  end)
end

----------------------------------------------------------
-- MAIN
----------------------------------------------------------
function M.run()
  util.info("Starting Chestnut Node:", NODE_NAME)
  local modem = peripheral.find("modem")
  bus.open()
  parallel.waitForAny(scanner, listener)
end
if not ... then
  M.run()
end
return M
