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
local debugMode = true -- Set to true to enable debug messages
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
addon:RegisterEvent("PLAYER_ENTERING_WORLD")

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

        -- Wrapper to modify the glow after it's shown
        LibButtonGlow.ShowOverlayGlow = function(frame)
            if not frame then
                return
            end

            -- Call the original function to create/show the overlay
            if OriginalShowOverlayGlow then
                OriginalShowOverlayGlow(frame)
            end

            -- Modify the overlay to look like modern retail (hide ants, adjust textures, add pulse)
            local overlay = frame.__LBGoverlay
            if overlay then
                if overlay.ants then
                    overlay.ants:SetAlpha(0)
                    overlay.ants:Hide()
                end

                -- Create Pulse animation if it doesn't exist
                if not overlay.animPulse then
                    overlay.animPulse = overlay:CreateAnimationGroup()
                    overlay.animPulse:SetLooping("BOUNCE")

                    local alpha = overlay.animPulse:CreateAnimation("Alpha")
                    alpha:SetTarget(overlay.outerGlow)
                    alpha:SetDuration(0.5)
                    alpha:SetFromAlpha(1)
                    alpha:SetToAlpha(0.5)
                    alpha:SetSmoothing("IN_OUT")

                    local scale = overlay.animPulse:CreateAnimation("Scale")
                    scale:SetTarget(overlay.outerGlow)
                    scale:SetDuration(0.5)
                    scale:SetScale(1.05, 1.05)
                    scale:SetSmoothing("IN_OUT")
                end

                -- Play Pulse if not already playing
                if not overlay.animPulse:IsPlaying() then
                    overlay.animPulse:Play()
                end
            end
        end

        LibButtonGlow.HideOverlayGlow = function(frame)
            if not frame then
                return
            end

            local overlay = frame.__LBGoverlay
            if overlay and overlay.animPulse then
                overlay.animPulse:Stop()
            end

            if OriginalHideOverlayGlow then
                OriginalHideOverlayGlow(frame)
            end
        end

        DebugPrint("Successfully replaced ShowOverlayGlow and HideOverlayGlow")
        hasBeenSetup = true -- Mark as set up

        -- Now that we're set up, register the event to fix stuck glows on reload/zone change.
        -- The main event handler will now only process PLAYER_ENTERING_WORLD because ADDON_LOADED is unregistered.
        addon:SetScript("OnEvent", function(self, event, ...)
            if event == "PLAYER_ENTERING_WORLD" then
                -- On login/reload, clear our state cache as we can't be sure of the real state.
                -- The RefreshAllBars function will then fix everything.
                wipe(glowStateCache) -- Clear the cache
                -- Use a short timer to ensure everything is settled after loading in.
                C_Timer_After(0.2, RefreshAllBars) -- Then refresh all bars
            end
        end)

        -- The setup is complete, so we can unregister the initial events.
        addon:UnregisterEvent("ADDON_LOADED")
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

-- The main event handler for the addon.
-- The main event handler for the addon.
addon:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- On login/reload, our setup should have run already.
        -- We always clear state and refresh bars to fix any stuck glows from loading screens.
        wipe(glowStateCache)
        DebugPrint("Glow state cache cleared.")
        C_Timer_After(0.2, RefreshAllBars) -- Use a short timer to ensure UI is settled.
    end
end)

-- Attempt to set up the glow replacement immediately.
-- Since Bartender4 is a dependency, it should be loaded.
SetupGlowReplacement()

DebugPrint("Addon file loaded completely")
