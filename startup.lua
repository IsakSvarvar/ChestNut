-- Chestnut loader --
if fs.exists("/chestnut/core/main.lua") then
    shell.run("/chestnut/core/main.lua")
else
    print("Chestnut not found.")
end