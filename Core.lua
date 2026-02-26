-- PersonalResourceOptions - Core.lua
-- Slim orchestrator: ADDON_LOADED, PLAYER_LOGIN, settings panel opener.
-- All logic is delegated to mixin modules loaded before this file.

local ADDON_NAME, PRO = ...

local categoryID
local hasAltPowerBar  = false
local hasClassFrame   = false

local displayManager = CreateFromMixins(PRO.DisplayManagerMixin)

-- ---------------------------------------------------------------------------
-- ADDON_LOADED: profile init, class detection, settings registration
-- ---------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded(ADDON_NAME, function()
	PersonalResourceOptionsDB = PersonalResourceOptionsDB or {}

	local classID = select(3, UnitClass("player"))

	-- Initialize profile system (migrations, resolve profile, build flat db)
	local db = PRO.profileManager:Initialize(PersonalResourceOptionsDB, classID)

	hasAltPowerBar = classID == Constants.UICharacterClasses.DemonHunter
		or classID == Constants.UICharacterClasses.Evoker
		or classID == Constants.UICharacterClasses.Monk
	hasClassFrame = classID == Constants.UICharacterClasses.Paladin
		or classID == Constants.UICharacterClasses.Rogue
		or classID == Constants.UICharacterClasses.DeathKnight
		or classID == Constants.UICharacterClasses.Mage
		or classID == Constants.UICharacterClasses.Warlock
		or classID == Constants.UICharacterClasses.Monk
		or classID == Constants.UICharacterClasses.Druid
		or classID == Constants.UICharacterClasses.Evoker
	local hasCooldownClassFrame = classID == Constants.UICharacterClasses.DeathKnight

	-- Callback wired into both Settings and profile CRUD.
	-- Deferred via C_Timer.After(0) to break the taint chain: the
	-- callback fires inside Blizzard's Settings execution context, and
	-- ApplySettings touches protected nameplate frames. Running it in a
	-- fresh context prevents the addon's frame modifications from
	-- tainting the Settings system (which would block later SetCVar calls).
	local function OnSettingChanged()
		PRO.profileManager:UnflattenToProfile(db, PRO.currentProfile, PRO.classID)
		C_Timer.After(0, function()
			displayManager:ApplySettings(db)
		end)
	end

	-- Store callback so ProfileManager CRUD wrappers can invoke it
	PRO.applyCallback = function(flatDb)
		C_Timer.After(0, function()
			displayManager:ApplySettings(flatDb)
		end)
	end

	categoryID = PRO.RegisterSettings(db, OnSettingChanged, hasAltPowerBar, hasClassFrame, hasCooldownClassFrame)
end)

-- ---------------------------------------------------------------------------
-- PLAYER_LOGIN: init overlays, install hooks, first ApplySettings
-- ---------------------------------------------------------------------------

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")

	local db = PRO.db
	if not PersonalResourceDisplayFrame or not db then return end

	-- When override mode is off, sync enableDisplay from the CVar so the
	-- addon reflects Options > Combat > Personal Resource Display.
	-- When override mode is on, we ignore the CVar and keep our own value.
	if not db.overrideDisplay then
		db.enableDisplay = C_CVar.GetCVar(PRO.PRD_ENABLED_CVAR) == "1"
	end

	-- Listen for external CVar changes (e.g. Blizzard's Combat settings)
	-- and update db + settings UI to stay in sync, but only when not
	-- overriding. Deferred to a fresh context and guarded against combat
	-- to avoid tainting Blizzard's Settings call chain.
	local syncPending = false
	local function SyncEnableDisplayFromCVar()
		syncPending = false
		if db.overrideDisplay then return end
		if InCombatLockdown() then
			syncPending = true
			return
		end
		local enabled = C_CVar.GetCVar(PRO.PRD_ENABLED_CVAR) == "1"
		if db.enableDisplay ~= enabled then
			db.enableDisplay = enabled
			if PRO.enableDisplaySetting then
				PRO.enableDisplaySetting:SetValue(enabled)
			end
		end
	end

	CVarCallbackRegistry:RegisterCallback(PRO.PRD_ENABLED_CVAR, function()
		if db.overrideDisplay then return end
		C_Timer.After(0, SyncEnableDisplayFromCVar)
	end)

	-- If a CVar change arrived during combat, apply it once we leave.
	local syncRegenFrame = CreateFrame("Frame")
	syncRegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	syncRegenFrame:SetScript("OnEvent", function()
		if syncPending then
			SyncEnableDisplayFromCVar()
		end
	end)

	displayManager:Init(db, hasAltPowerBar, hasClassFrame)
	displayManager:ApplySettings(db)
end)

-- ---------------------------------------------------------------------------
-- Settings panel opener (deferred to out-of-combat if needed)
-- ---------------------------------------------------------------------------

local pendingSettingsOpen = false

local combatEndFrame = CreateFrame("Frame")
combatEndFrame:SetScript("OnEvent", function()
	combatEndFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	pendingSettingsOpen = false
	if categoryID then
		Settings.OpenToCategory(categoryID)
	end
end)

local function OpenSettings()
	if not categoryID then return end
	if InCombatLockdown() then
		if not pendingSettingsOpen then
			pendingSettingsOpen = true
			combatEndFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
	else
		Settings.OpenToCategory(categoryID)
	end
end

SLASH_PERSONALRESOURCEOPTIONS1 = "/pro"
SlashCmdList["PERSONALRESOURCEOPTIONS"] = function()
	OpenSettings()
end

function PRO_OnAddonCompartmentClick()
	OpenSettings()
end
