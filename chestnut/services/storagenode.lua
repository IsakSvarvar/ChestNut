-- /chestnut/services/storagenode.lua
-- Chestnut StorageNode Service (ping handled by bus)

package.path = "/?.lua;/?/init.lua;/chestnut/?.lua;/chestnut/?/init.lua;" .. package.path

local util = require("chestnut.core.util")
local bus = require("chestnut.core.bus")

-- Load configs
local sys_cfg  = util.load_json("/chestnut/config/system.json", {})
local node_cfg = util.load_json("/chestnut/config/node.json", {})

-- Dynamic storage backend
local backend_name = node_cfg.storage_backend or "vanilla"
local storage = require("chestnut.modules." .. backend_name .. "_storage")

-- Node metadata
local NODE_ID   = os.getComputerID()
local BASE_NAME = node_cfg.node_name or "node"
local NODE_NAME = ("%s_%d"):format(BASE_NAME, NODE_ID)
local SCAN_INTERVAL = node_cfg.scan_interval or 10
local HUB_ID = node_cfg.hub_id
assert(HUB_ID, "node.json missing hub_id (required)")


local running = true

----------------------------------------------------------
-- Helpers
----------------------------------------------------------
local function send_update()
  local items = storage.list()
  bus.send(HUB_ID, "node_update", {
    node      = NODE_NAME,
    items     = items,
    timestamp = os.clock()
  })
  util.info("Sent update with", util.table_size(items), "item types.")
end

----------------------------------------------------------
-- Threads
----------------------------------------------------------
local function scanner()
  while running do
    send_update()
    sleep(SCAN_INTERVAL)
  end
end

local function listener()
  bus.listen(function(msgType, body, sender)
    if msgType == "transfer" then
      local moved = storage.pull(body.item, body.count, body.target)
      util.info("Transfer", moved, body.item, "→", body.target)
      bus.send(sender, "transfer_result", {
        node  = NODE_NAME,
        item  = body.item,
        moved = moved
      })
    end
  end)
end

----------------------------------------------------------
-- Main
----------------------------------------------------------
local M = {}
function M.run()
  util.info("Starting Chestnut Node:", NODE_NAME)
  bus.open()
  parallel.waitForAny(scanner, listener)
end

if not ... then M.run() end
return M
