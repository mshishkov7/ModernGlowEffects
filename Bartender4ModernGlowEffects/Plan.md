The execution plan
Step 0 — Manual download you do yourself before the agent runs
Go to https://github.com/Stanzilla/LibCustomGlow and download the repo as a ZIP. You need these files placed into your addon folder:
Bartender4ModernGlowEffects/
  libs/
    LibStub/
      LibStub.lua          ← grab from any Ace3 addon's libs folder, or the LibStub repo
    LibCustomGlow-1.0/
      LibCustomGlow-1.0.lua
      LibCustomGlow-1.0.xml
LibStub is almost certainly already in your WoW addons folder inside Bartender4's own libs/LibStub/. You can copy it from there. You don't need LibCustomGlow-1.0.toc — that's only for standalone use. You only need the .lua and .xml files.

Agent command
Hand this entire block to your IDE agent as its prompt:

AGENT TASK: Rewrite the WoW companion addon "Bartender4ModernGlowEffects" to work with WoW 12.0 (Midnight)
You are working on a World of Warcraft addon written in Lua. The addon is a small companion to Bartender4 that replaces the old "running ants" glow effect on action buttons with a modern visual. The previous version used ActionButton_ShowOverlayGlow which is now broken in WoW 12.0 due to Blizzard's Secret Value API restrictions.
Project folder structure you are working with:
Bartender4ModernGlowEffects/
  libs/
    LibStub/
      LibStub.lua
    LibCustomGlow-1.0/
      LibCustomGlow-1.0.lua
      LibCustomGlow-1.0.xml
  Bartender4ModernGlowEffects.lua   ← the old file, provided for reference
  Bartender4ModernGlowEffects.toc   ← needs to be rewritten
Task 1 — Rewrite the TOC file Bartender4ModernGlowEffects.toc
The TOC must:

Set ## Interface: 120000 (WoW 12.0 / Midnight, hard requirement or addon won't load)
Set ## Version: 2.0.0
Set ## Title: Bartender4 Modern Glow Effects
Set ## Notes: Replaces Bartender4 button glow with LibCustomGlow visual effects
Set ## Author: (keep original author)
Set ## Dependencies: Bartender4 (hard dep, no point running without it)
Load files in this exact order:

libs/LibStub/LibStub.lua
libs/LibCustomGlow-1.0/LibCustomGlow-1.0.xml
Bartender4ModernGlowEffects.lua



Task 2 — Rewrite Bartender4ModernGlowEffects.lua from scratch
Using the old file as a reference only (do not copy its logic). Write a clean new version with the following requirements:
Architecture:

All locals at the top, localise LibStub, CreateFrame, C_Timer, wipe, pairs
One addonFrame for event handling, no globals except the optional debug table
debugMode defaulting to false
Keep the _G[AddonName].SetDebugMode / GetDebugMode debug interface from the old file

Startup sequence:

Register ADDON_LOADED to detect when Bartender4 has finished loading
Register PLAYER_LOGIN (fires once after all addons load, safer than PLAYER_ENTERING_WORLD for initial setup)
Register PLAYER_ENTERING_WORLD only for the post-setup refresh logic

Core logic — the intercept:
In SetupGlowReplacement():

Grab LibButtonGlow via LibStub("LibButtonGlow-1.0", true) — the true flag means it won't error if missing
Grab LCG via LibStub("LibCustomGlow-1.0", true)
If either is nil, print an error and return — do not proceed
Store LibButtonGlow.ShowOverlayGlow and LibButtonGlow.HideOverlayGlow as upvalues (but do NOT call them — they are broken and only stored for reference/debug)
Replace LibButtonGlow.ShowOverlayGlow with a new function that:

Returns early if frame is nil
Returns early if glowStateCache[frame] is already true (prevents animation restart flicker)
Sets glowStateCache[frame] = true
Calls LCG.ButtonGlow_Start(frame) — this is the clean modern visual, no taint risk


Replace LibButtonGlow.HideOverlayGlow with a new function that:

Returns early if frame is nil
Returns early if glowStateCache[frame] is nil (not glowing, nothing to do)
Sets glowStateCache[frame] = nil
Calls LCG.ButtonGlow_Stop(frame)


Set hasBeenSetup = true

Post-setup refresh (PLAYER_ENTERING_WORLD):

wipe(glowStateCache) to clear stale state after zone changes / reloads
Use C_Timer.After(0.3, RefreshAllBars) to let the UI settle before refreshing
RefreshAllBars iterates Bartender4.BarRegistry (guarded with if not _G.Bartender4 or not _G.Bartender4.BarRegistry then return end), calls bar:Update() on each bar only if the method exists

Version guard:

Replace the old WoW10 build number check with: if select(4, GetBuildInfo()) < 120000 then print error and return end
This correctly gates on Midnight (12.0 = build 120000)

What to remove entirely from the old file:

Method 2 (_G.LBG check) — dead code
Method 3 (the LAB UpdateOverlayGlow hook stub that did nothing) — dead code
Method 4 (the _G.ActionButton_ShowOverlayGlow global hook) — this function is tainted/restricted in 12.0, calling it will cause a ForceTaint error
The UnregisterEvent("ADDON_LOADED") scattered in two places — handle it cleanly in one place
The double SetScript("OnEvent") assignment (old file sets it twice, second one overwrites first)

Code quality requirements:

No magic numbers — define a constant MIN_BUILD = 120000 at the top
Add a single comment header block describing what the addon does and why LibCustomGlow is used instead of ActionButton_ShowOverlayGlow
Keep the file under 120 lines total — this is a small focused addon
Every function must be local
No global namespace pollution except _G[AddonName] for the debug interface