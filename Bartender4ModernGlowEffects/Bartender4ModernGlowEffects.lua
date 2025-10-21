--[[
	Bartender4 Modern Glow Effects
	Replaces LibButtonGlow-1.0 effects with retail-style overlay glow
]] -- Localize globals for performance and clarity
local select, print, GetBuildInfo, CreateFrame = select, print, GetBuildInfo, CreateFrame
local ActionButton_ShowOverlayGlow, ActionButton_HideOverlayGlow = ActionButton_ShowOverlayGlow,
    ActionButton_HideOverlayGlow
local C_Timer_After = C_Timer.After
local LibStub = LibStub

-- Addon setup
local AddonName = "Bartender4ModernGlowEffects"
local debugMode = false -- Set to true to enable debug messages
local hasBeenSetup = false -- Guard to prevent multiple setups
local glowStateCache = {} -- Tracks the glow state of buttons to prevent flickering

-- Debug print function
local function DebugPrint(...)
    if debugMode then
        print("|cffff00ff[ModernGlow]|r", ...)
    end
end

-- Expose debug functionality for external files (like a debug-only file)
_G[AddonName] = _G[AddonName] or {} -- Ensure the global table exists
_G[AddonName].SetDebugMode = function(state)
    debugMode = state
end
_G[AddonName].GetDebugMode = function()
    return debugMode
end
_G[AddonName].DebugPrint = DebugPrint -- Expose the local DebugPrint for external files to use if they want to print

-- Print immediately to confirm addon is loading
DebugPrint("Addon file is loading...")

-- Check if we're on retail (WoW 10.0+) where the new glow exists
local WoW10 = select(4, GetBuildInfo()) >= 100000

if not WoW10 then
    print("|cffff0000[ModernGlow]|r This addon requires WoW 10.0 or higher (Retail)")
    return
end

DebugPrint("Running on WoW 10.0+")

-- Create frame to wait for addons
local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")

-- Function to refresh all Bartender4 bars to fix state issues after loading screens
local function RefreshAllBars()
    if not _G.Bartender4 or not _G.Bartender4.BarRegistry then
        return
    end

    DebugPrint("PLAYER_ENTERING_WORLD: Refreshing all Bartender4 bars...")
    for _, bar in pairs(_G.Bartender4.BarRegistry) do
        if bar and bar.Update then
            bar:Update()
        end
    end
    DebugPrint("Bar refresh complete.")
end

local function SetupGlowReplacement()
    if hasBeenSetup then
        return
    end -- Guard against multiple setups

    DebugPrint("Setting up glow replacement...")

    -- Method 1: Try LibStub
    local LibButtonGlow = LibStub and LibStub("LibButtonGlow-1.0", true)

    if LibButtonGlow then
        DebugPrint("Found LibButtonGlow via LibStub!")

        -- Store originals
        local OriginalShowOverlayGlow = LibButtonGlow.ShowOverlayGlow
        local OriginalHideOverlayGlow = LibButtonGlow.HideOverlayGlow

        -- Replace functions with state-aware versions to prevent animation flickering
        LibButtonGlow.ShowOverlayGlow = function(frame)
            if not frame then
                return
            end

            -- If we already think it's glowing, do nothing to prevent re-triggering the animation.
            if glowStateCache[frame] then
                DebugPrint("ShowOverlayGlow ignored (already glowing):", frame:GetName())
                return
            end

            DebugPrint("ShowOverlayGlow called on:", frame:GetName())

            -- Mark as glowing *before* showing the effect
            glowStateCache[frame] = true

            -- Make sure old glow is gone (belt-and-suspenders)
            if OriginalHideOverlayGlow then
                OriginalHideOverlayGlow(frame)
            end
            _G.ActionButton_ShowOverlayGlow(frame)
        end

        LibButtonGlow.HideOverlayGlow = function(frame)
            if not frame then
                return
            end

            -- Only hide if we think it's currently glowing
            if glowStateCache[frame] then
                DebugPrint("HideOverlayGlow called on:", frame:GetName())
                glowStateCache[frame] = nil -- Mark as not glowing
                ActionButton_HideOverlayGlow(frame)
            end
        end

        DebugPrint("Successfully replaced ShowOverlayGlow and HideOverlayGlow")
        hasBeenSetup = true -- Mark as set up

        -- Now that we're set up, register the event to fix stuck glows on reload/zone change.
        addon:RegisterEvent("PLAYER_ENTERING_WORLD")
        addon:SetScript("OnEvent", nil) -- Clear the old OnEvent script
        addon:SetScript("OnEvent", function(self, event, ...)
            if event == "PLAYER_ENTERING_WORLD" then
                -- On login/reload, clear our state cache as we can't be sure of the real state.
                -- The RefreshAllBars function will then fix everything.
                wipe(glowStateCache) -- Clear the cache
                DebugPrint("Glow state cache cleared.")
                -- Use a short timer to ensure everything is settled after loading in.
                C_Timer_After(0.2, RefreshAllBars) -- Then refresh all bars
            end
        end)

        -- The setup is complete, so we can unregister the initial events.
        addon:UnregisterEvent("ADDON_LOADED")
        addon:UnregisterEvent("PLAYER_LOGIN")
        addon:SetScript("OnEvent", nil) -- Clear the initial handler completely
    else
        print("|cffff0000[ModernGlow]|r Could not find LibButtonGlow!")
    end

    -- Method 2: Try global LBG
    if _G.LBG then
        DebugPrint("Found global LBG object!")
    end

    -- Method 3: Check LibActionButton
    local LAB = LibStub and LibStub("LibActionButton-1.0", true)
    if LAB then
        DebugPrint("Found LibActionButton-1.0")

        -- Try to hook UpdateOverlayGlow if it exists
        if LAB.UpdateOverlayGlow then
            DebugPrint("Found LAB.UpdateOverlayGlow, hooking...")
        end
    else
        print("|cffff0000[ModernGlow]|r Could not find LibActionButton!")
    end

    -- Method 4: Hook the retail API itself
    if ActionButton_ShowOverlayGlow then
        DebugPrint("Retail glow API found")
        local orig = _G.ActionButton_ShowOverlayGlow
        _G.ActionButton_ShowOverlayGlow = function(button)
            DebugPrint("Retail ShowOverlayGlow called on:", button and button:GetName() or "unknown")
            orig(button)
        end
    end
end

-- We need a more robust OnEvent handler now.
local initialOnEvent = function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Bartender4" then
        DebugPrint("Bartender4 loaded, attempting setup...")
        -- Wait a bit for libraries to initialize
        C_Timer_After(0.5, SetupGlowReplacement)
    elseif event == "PLAYER_LOGIN" then
        DebugPrint("PLAYER_LOGIN fired, checking for Bartender4...")
        -- Fallback setup if Bartender4 already loaded
        if _G.Bartender4 then
            C_Timer_After(1, SetupGlowReplacement)
        end
    end

    if hasBeenSetup then
        self:SetScript("OnEvent", nil)
    end
end
addon:SetScript("OnEvent", initialOnEvent)

-- Try immediate setup if Bartender4 is already loaded
if _G.Bartender4 then -- Use _G.Bartender4 for explicit global access
    DebugPrint("Bartender4 already loaded at file load time")
    C_Timer_After(1, SetupGlowReplacement)
end

DebugPrint("Addon file loaded completely")
