local logPath = "/chestnut/data/debug_peripherals.log"
fs.makeDir(fs.getDir(logPath))
local f = fs.open(logPath, "w")

f.writeLine("=== Peripheral dump ===")
for _, name in ipairs(peripheral.getNames()) do
  local t = peripheral.getType(name)
  local per = peripheral.wrap(name)
  f.writeLine(("[%s] type=%s"):format(name, tostring(t)))

  if per then
    local fns = {}
    for k, v in pairs(per) do
      if type(v) == "function" then table.insert(fns, k) end
    end
    table.sort(fns)
    f.writeLine("  functions: " .. table.concat(fns, ", "))
  else
    f.writeLine("  (wrap failed)")
  end

  f.writeLine("")
end
f.writeLine("=== End ===")
f.close()

print("Peripheral list written to: " .. logPath)
print("Use 'edit " .. logPath .. "' or 'less " .. logPath .. "' to view it.")
