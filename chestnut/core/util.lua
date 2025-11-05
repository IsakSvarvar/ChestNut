-- /chestnut/core/util.lua
-- Minimal, dependable helpers for Chestnut.
-- Keep this file vanilla-CC safe (no AP calls).

local M = {}

----------------------------------------------------------------
-- time / ids
----------------------------------------------------------------

-- Returns an ISO-like UTC timestamp, e.g. 2025-10-24T18:03:12Z
function M.iso_now()
	-- os.epoch("utc") is CC:Tweaked; falls back to os.time if missing
	local ok, ms = pcall(os.epoch, "utc")
	if ok then
		local s = math.floor(ms / 1000)
		local t = textutils.formatTime((s % 86400) / 3600, true) -- HH:MM (24h)
		-- We still want a date; CC doesn't give it natively, so we store epoch too.
		return ("%sZ|%d"):format(t, s) -- "HH:MMZ|epoch_seconds"
	else
		-- Old-style fallback (no epoch): just HH:MM with |0
		return (textutils.formatTime(os.time(), true)) .. "Z|0"
	end
end

-- Lightweight unique-ish id for logs, orders, etc.
function M.uuid(prefix)
	prefix = prefix or "id"
	local r = math.random
	return ("%s-%08x%08x"):format(prefix, r(0, 0xffffffff), r(0, 0xffffffff))
end

----------------------------------------------------------------
-- filesystem
----------------------------------------------------------------

-- Ensure the directory for a given path exists
function M.ensure_dir_for(path)
	local dir = fs.getDir(path)
	if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

-- Read whole file; returns nil if missing
function M.read_all(path)
	if not fs.exists(path) then return nil end
	local h = fs.open(path, "r")
	if not h then return nil end
	local s = h.readAll()
	h.close()
	return s
end

-- Write whole file (overwrites)
function M.write_all(path, text)
	M.ensure_dir_for(path)
	local h = fs.open(path, "w")
	if not h then
		return false, "open-failed"
	end
	h.write(text or "")
	h.close()
	return true
end

-- Load JSON -> table (safe). If file missing, return default or {}.
function M.load_json(path, default)
  if not fs.exists(path) then return default end
  local f = fs.open(path, "r")
  if not f then return default end
  local ok, data = pcall(textutils.unserializeJSON, f.readAll())
  f.close()
  if ok and data then return data else return default end
end

-- Save table -> JSON (compact)
function M.save_json(path, tbl)
	local ok, s = pcall(textutils.serializeJSON, tbl or {})
	if not ok then return false, "json-serialize-failed" end
	return M.write_all(path, s)
end

----------------------------------------------------------------
-- logging
----------------------------------------------------------------

-- simple log levels
local LEVELS = { trace=1, debug=2, info=3, warn=4, error=5 }
local currentLevel = LEVELS.info
local logFile = nil

function M.set_log_level(level)
	if LEVELS[level] then currentLevel = LEVELS[level] end
end

function M.set_log_file(path)
	logFile = path
	if path then M.ensure_dir_for(path) end
end

local function level_name(n)
	for k,v in pairs(LEVELS) do if v==n then return k end end
	return "info"
end

local function append_file(path, line)
	local h = fs.open(path, fs.exists(path) and "a" or "w")
	if h then h.write(line .. "\n"); h.close() end
end

local function print_colored(level, msg)
	-- Keep colors optional (works on basic computers too)
	local color = term.isColor and term.isColor() and ({
		[LEVELS.trace]=colors.lightGray,
		[LEVELS.debug]=colors.cyan,
		[LEVELS.info]=colors.white,
		[LEVELS.warn]=colors.yellow,
		[LEVELS.error]=colors.red,
	})[level] or nil

	if color then term.setTextColor(color) end
	print(msg)
	if color then term.setTextColor(colors.white) end
end

local function log_at(level, ...)
	if level < currentLevel then return end
	local ts = M.iso_now()
	local parts = {}
	for i=1, select("#", ...) do
		local v = select(i, ...)
		parts[#parts+1] = type(v)=="table" and textutils.serialize(v) or tostring(v)
	end
	local line = ("[%s] %-5s | %s"):format(ts, level_name(level):upper(), table.concat(parts, " "))
	M._append_recent(line)
	print_colored(level, line)
	if logFile then append_file(logFile, line) end
end

function M.trace(...) log_at(LEVELS.trace, ...) end
function M.debug(...) log_at(LEVELS.debug, ...) end
function M.info(...)  log_at(LEVELS.info,  ...) end
function M.warn(...)  log_at(LEVELS.warn,  ...) end
function M.error(...) log_at(LEVELS.error, ...) end

----------------------------------------------------------------
-- runtime log buffer (for UIs)
----------------------------------------------------------------
local recent_logs = {}

-- Keep last N lines of logs for dashboards
function M._append_recent(line)
  table.insert(recent_logs, 1, line)
  if #recent_logs > 15 then table.remove(recent_logs) end
end

-- Public getter (read-only)
function M.get_recent_logs()
  return recent_logs
end

----------------------------------------------------------------
-- control flow helpers
----------------------------------------------------------------

-- Safe call: returns ok, result_or_err
function M.try(fn, ...)
	return pcall(fn, ...)
end

-- Waits until cond() returns truthy or timeout seconds elapse (nil = no timeout).
-- Returns true if condition met, false on timeout.
function M.wait_for(cond, timeout)
	local t0 = os.clock()
	while true do
		if cond() then return true end
		os.sleep(0) -- yield
		if timeout and (os.clock() - t0) >= timeout then return false end
	end
end

-- Debounce wrapper: returns a function that only runs after quiet period.
function M.debounce(delay, fn)
	local timerId = nil
	return function(...)
		local args = { ... }
		if timerId then -- cancel previous timer by ignoring it
			timerId = nil
		end
		local thisTimer = os.startTimer(delay)
		timerId = thisTimer
		while true do
			local e, id = os.pullEvent("timer")
			if id == thisTimer and timerId == thisTimer then
				fn(table.unpack(args))
				return
			elseif id == thisTimer then
				-- was superseded; do nothing
				return
			end
		end
	end
end

function M.table_size(t)
  local c = 0
  for _ in pairs(t) do c = c + 1 end
  return c
end

----------------------------------------------------------------
-- peripheral label mapping
----------------------------------------------------------------
local label_map_path = "/chestnut/config/labels.json"
local label_map = M.load_json(label_map_path, {})

-- resolve_target("alias") → "minecraft:chest_1"
function M.resolve_target(name)
  if not name then return nil end
  return label_map[name] or name
end

-- set_label("alias", "minecraft:chest_1")
function M.set_label(alias, periph)
  if not alias or not periph then
    return false, "missing args"
  end
  label_map[alias] = periph
  M.save_json(label_map_path, label_map)
  return true
end

-- get_label_map() → table of all aliases
function M.get_label_map()
  return label_map
end


return M
