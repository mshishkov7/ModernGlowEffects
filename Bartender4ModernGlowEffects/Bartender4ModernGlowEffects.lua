--[[ 
	Bartender4 Modern Glow Effects
	Replaces the standard ActionButton_ShowOverlayGlow with LibCustomGlow to support WoW 12.0 (Midnight)
	and provide a modern visual effect.
]]

local LibStub = LibStub
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local wipe = wipe
local pairs = pairs
local select = select
local GetBuildInfo = GetBuildInfo
local print = print

local AddonName = "Bartender4ModernGlowEffects"
local MIN_BUILD = 120000

-- Version guard
if select(4, GetBuildInfo()) < MIN_BUILD then
	print(AddonName .. ": WoW 12.0+ required, addon disabled.")
	return
end

print(AddonName .. ": File loaded OK")

local addonFrame = CreateFrame("Frame")
local debugMode = false
local hasBeenSetup = false
local glowStateCache = {}

-- Debug Interface
_G[AddonName] = {}
function _G[AddonName].SetDebugMode(enable)
	debugMode = enable
	print(AddonName .. ": Debug mode " .. (enable and "enabled" or "disabled"))
end
function _G[AddonName].GetDebugMode()
	return debugMode
end

local function DebugPrint(...)
	if debugMode then print(AddonName, ...) end
end

local function RefreshAllBars()
	if not _G.Bartender4 or not _G.Bartender4.BarRegistry then return end
	DebugPrint("Refreshing all bars...")
	for _, bar in pairs(_G.Bartender4.BarRegistry) do
		if bar.Update then bar:Update() end
	end
end

local function SetupGlowReplacement()
	if hasBeenSetup then return end
	
	local LBG = LibStub("LibButtonGlow-1.0", true)
	local LCG = LibStub("LibCustomGlow-1.0", true)
	
	if not LBG or not LCG then
		print(AddonName .. ": Missing libraries (LibButtonGlow-1.0 or LibCustomGlow-1.0).")
		return
	end
	
	-- Store original references (for debug/safety, not calling them)
	local originalShow = LBG.ShowOverlayGlow
	local originalHide = LBG.HideOverlayGlow
	
	-- Replace ShowOverlayGlow
	LBG.ShowOverlayGlow = function(frame)
		if not frame then return end
		if glowStateCache[frame] then return end -- Already glowing
		
		glowStateCache[frame] = true
		LCG.ButtonGlow_Start(frame)
		DebugPrint("ShowGlow", frame:GetName())
	end
	
	-- Replace HideOverlayGlow
	LBG.HideOverlayGlow = function(frame)
		if not frame then return end
		if not glowStateCache[frame] then return end -- Not glowing
		
		glowStateCache[frame] = nil
		LCG.ButtonGlow_Stop(frame)
		DebugPrint("HideGlow", frame:GetName())
	end
	
	hasBeenSetup = true
	
	-- Kill OnUpdate on any already-created LBG overlay frames to stop the secret value crash
	if LBG.numOverlays and LBG.numOverlays > 0 then
		for i = 1, LBG.numOverlays do
			local overlay = _G["ButtonGlowOverlay" .. i]
			if overlay then
				overlay:SetScript("OnUpdate", nil)
				overlay:Hide()
				DebugPrint("Patched overlay frame:", "ButtonGlowOverlay" .. i)
			end
		end
	end
	
	DebugPrint("Setup complete.")
end

addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:RegisterEvent("PLAYER_LOGIN")
addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

addonFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Bartender4" then
		SetupGlowReplacement()
	elseif event == "PLAYER_LOGIN" then
		SetupGlowReplacement()
	elseif event == "PLAYER_ENTERING_WORLD" then
		if hasBeenSetup then
			wipe(glowStateCache)
			C_Timer.After(0.3, RefreshAllBars)
		end
	end
end)
