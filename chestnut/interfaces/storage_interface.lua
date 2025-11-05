-- /chestnut/interfaces/storage_interface.lua
-- Defines the common API that all storage providers must follow.

--[[
Expected functions:
- list() → table { [itemName] = count, ... }
- pull(itemName, count, targetPeripheral) → number moved
- push(sourcePeripheral) → number moved
- getItem(name) → item detail table or nil
]]

local M = {}

function M.list()
	error("storage_interface.list() not implemented")
end

function M.pull(itemName, count, target)
	error("storage_interface.pull() not implemented")
end

function M.push(source)
	error("storage_interface.push() not implemented")
end

function M.getItem(name)
	error("storage_interface.getItem() not implemented")
end

return M