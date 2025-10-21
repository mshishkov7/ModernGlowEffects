--[[
	Bartender4 Modern Glow Effects - Debug Module
	This file contains debug-specific functionality and should be excluded from release builds.
]] local AddonName = "Bartender4ModernGlowEffects"
local addonTable = _G[AddonName]

if not addonTable or not addonTable.SetDebugMode or not addonTable.GetDebugMode or not addonTable.DebugPrint then
    print("|cffff0000[ModernGlow Debug]|r Error: Main addon debug interface not found. Debug module cannot initialize.")
    return
end

-- Enable debug mode immediately when this file is loaded
addonTable.SetDebugMode(true)
addonTable.DebugPrint("Debug module loaded. Debug mode ENABLED by default.")

-- Slash command to toggle debug mode
SLASH_MGLOWDEBUG1 = "/mglowdebug"
SlashCmdList["MGLOWDEBUG"] = function(msg)
    local isEnabled = not addonTable.GetDebugMode()
    addonTable.SetDebugMode(isEnabled)
    print((isEnabled and "|cff00ff00" or "|cffff0000") .. "[ModernGlow]|r Debug mode " ..
              (isEnabled and "ENABLED" or "DISABLED"))
end
