-- PersonalResourceOptions - Core.lua
-- Combat health and power text overlays for the Personal Resource Display.
--
-- Values are passed straight through AbbreviateNumbers -> SetText with no
-- arithmetic or comparisons performed by addon code, satisfying taint
-- requirements in restricted (raid / M+) environments.

local ADDON_NAME, PRO = ...

local UnitHealth        = UnitHealth
local UnitPower         = UnitPower
local AbbreviateNumbers = AbbreviateNumbers
local GetRuneCooldown   = GetRuneCooldown
local GetTime           = GetTime
local ceil              = math.ceil

local categoryID
local healthText, powerText, altPowerText
local hasAltPowerBar  = false
local hasClassFrame   = false
local runeTexts       = {}

local ALT_POWER_OPTIONS = {
	-- breakpoint = 0 → applies to all values >= 0.
	-- significandDivisor / fractionDivisor pair controls decimal places:
	--   0 decimals: floor(v / 1)    / 1   = integer
	--   1 decimal:  floor(v / 0.1)  / 10  = one decimal  (e.g. 9.123 → 9.1)
	--   2 decimals: floor(v / 0.01) / 100 = two decimals (e.g. 9.123 → 9.12)
	[0] = { breakpointData = { { breakpoint = 0, abbreviation = "", abbreviationIsGlobal = false, significandDivisor = 1,    fractionDivisor = 1   } } },
	[1] = { breakpointData = { { breakpoint = 0, abbreviation = "", abbreviationIsGlobal = false, significandDivisor = 0.1,  fractionDivisor = 10  } } },
	[2] = { breakpointData = { { breakpoint = 0, abbreviation = "", abbreviationIsGlobal = false, significandDivisor = 0.01, fractionDivisor = 100 } } },
}
local altPowerOptions = ALT_POWER_OPTIONS[1]

-- ---------------------------------------------------------------------------
-- Profile system constants
-- ---------------------------------------------------------------------------

local CLASS_SPECIFIC_KEYS = {
	"classFrameScale",
	"classFrameOffsetX",
	"classFrameOffsetY",
	"enableRuneCooldownText",
	"runeCooldownTextAnchor",
	"runeCooldownTextFont",
	"runeCooldownTextSize",
	"runeCooldownTextOutline",
	"runeCooldownTextThickOutline",
	"runeCooldownTextMono",
	"runeCooldownTextColor",
}

local IS_CLASS_SPECIFIC = {}
for _, key in ipairs(CLASS_SPECIFIC_KEYS) do
	IS_CLASS_SPECIFIC[key] = true
end

local DEFAULTS = {
	enableDisplay             = true,
	enableHealthBar           = true,
	enablePowerBar            = true,
	enableAltPowerBar         = true,
	enableClassFrame          = true,
	displayScale              = 100,
	classFrameScale           = 100,
	classFrameOffsetX         = 0,
	classFrameOffsetY         = 0,
	enableHealthText          = true,
	healthTextAnchor          = "CENTER",
	healthTextFont            = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
	healthTextSize            = 14,
	healthTextOutline         = false,
	healthTextThickOutline    = true,
	healthTextMono            = false,
	healthTextColor           = "ffffffff",
	enablePowerText           = true,
	powerTextAnchor           = "CENTER",
	powerTextFont             = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
	powerTextSize             = 14,
	powerTextOutline          = false,
	powerTextThickOutline     = true,
	powerTextMono             = false,
	powerTextColor            = "ffffffff",
	enableAltPowerText        = true,
	altPowerTextAnchor        = "CENTER",
	altPowerTextFont          = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
	altPowerTextSize          = 14,
	altPowerTextOutline       = false,
	altPowerTextThickOutline  = true,
	altPowerTextMono          = false,
	altPowerTextColor         = "ffffffff",
	altPowerTextDecimals      = 1,
	enableRuneCooldownText       = true,
	runeCooldownTextAnchor       = "CENTER",
	runeCooldownTextFont         = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
	runeCooldownTextSize         = 12,
	runeCooldownTextOutline      = false,
	runeCooldownTextThickOutline = true,
	runeCooldownTextMono         = false,
	runeCooldownTextColor        = "ffffffff",
}

-- Event frames (one per bar type for independent register/unregister)
local healthFrame = CreateFrame("Frame")
healthFrame:SetScript("OnEvent", function()
	healthText:SetText(AbbreviateNumbers(UnitHealth("player")))
end)

local powerFrame = CreateFrame("Frame")
powerFrame:SetScript("OnEvent", function()
	powerText:SetText(AbbreviateNumbers(UnitPower("player")))
end)

local altPowerFrame = CreateFrame("Frame")
local function AltPowerOnUpdate()
	altPowerText:SetText(AbbreviateNumbers(
		PersonalResourceDisplayFrame.AlternatePowerBar:GetValue(), altPowerOptions))
end

local runeCooldownFrame = CreateFrame("Frame")
local function RuneCooldownOnUpdate()
	for i = 1, 6 do
		local t = runeTexts[i]
		if t then
			local start, duration, runeReady = GetRuneCooldown(i)
			if runeReady or not start then
				t:SetText("")
			else
				t:SetText(ceil(start + duration - GetTime()))
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function BuildFontFlags(thickOutline, outline, mono)
	local flags
	if thickOutline then
		flags = "THICKOUTLINE"
	elseif outline then
		flags = "OUTLINE"
	else
		flags = ""
	end
	if mono then
		flags = (flags == "") and "MONOCHROME" or (flags .. ",MONOCHROME")
	end
	return flags
end

--- Apply scale and offset to prdClassFrame.
local function ApplyClassFrameLayout(db)
	if not prdClassFrame or not PersonalResourceDisplayFrame.ClassFrameContainer then return end
	prdClassFrame:SetScale(db.classFrameScale / 100)
	prdClassFrame:ClearAllPoints()
	prdClassFrame:SetPoint("CENTER",
		PersonalResourceDisplayFrame.ClassFrameContainer, "CENTER",
		db.classFrameOffsetX, db.classFrameOffsetY)
end

-- ---------------------------------------------------------------------------
-- Profile system helpers
-- ---------------------------------------------------------------------------

--- Build a flat settings table from a profile, overlaying class-specific values.
local function FlattenProfile(profile, classID)
	local flat = {}
	for k, v in pairs(profile) do
		if k ~= "classSettings" then
			flat[k] = v
		end
	end
	local cs = profile.classSettings and profile.classSettings[classID]
	if cs then
		for _, key in ipairs(CLASS_SPECIFIC_KEYS) do
			if cs[key] ~= nil then
				flat[key] = cs[key]
			end
		end
	end
	for key, default in pairs(DEFAULTS) do
		if flat[key] == nil then
			flat[key] = default
		end
	end
	return flat
end

--- Write the flat db table back into a profile, separating class-specific keys.
local function UnflattenToProfile(db, profile, classID)
	for k, v in pairs(db) do
		if not IS_CLASS_SPECIFIC[k] then
			profile[k] = v
		end
	end
	if not profile.classSettings then
		profile.classSettings = {}
	end
	if not profile.classSettings[classID] then
		profile.classSettings[classID] = {}
	end
	local cs = profile.classSettings[classID]
	for _, key in ipairs(CLASS_SPECIFIC_KEYS) do
		cs[key] = db[key]
	end
end

--- Get the character identity key (Name-NormalizedRealm).
local function GetCharacterKey()
	local name = UnitName("player")
	local realm = GetNormalizedRealmName()
	return name .. "-" .. (realm or "")
end

--- Resolve which profile name the current character should use.
local function ResolveProfileName(savedDB, charKey)
	local name = savedDB.characterProfiles and savedDB.characterProfiles[charKey]
	if name and savedDB.profiles[name] then
		return name
	end
	return "Default"
end

--- Migrate flat v1 DB to v2 profile structure.
local function MigrateToV2(savedDB, classID)
	local profile = {}
	local classSettings = {}
	for k, v in pairs(savedDB) do
		if IS_CLASS_SPECIFIC[k] then
			classSettings[k] = v
		elseif k ~= "schemaVersion" then
			profile[k] = v
		end
	end
	if next(classSettings) then
		profile.classSettings = { [classID] = classSettings }
	end
	wipe(savedDB)
	savedDB.schemaVersion = 2
	savedDB.profiles = { ["Default"] = profile }
	savedDB.characterProfiles = {}
end

-- ---------------------------------------------------------------------------
-- ApplySettings
-- ---------------------------------------------------------------------------

local function ApplySettings(db)
	local prd = PersonalResourceDisplayFrame
	if not prd then return end

	if not db.enableDisplay then
		prd:Hide()
	else
		prd:UpdateShownState()
	end

	if prd.HealthBarsContainer then
		prd.HealthBarsContainer:SetShown(db.enableHealthBar)
	end
	if prd.PowerBar then
		prd.PowerBar:SetShown(db.enablePowerBar)
	end
	if prd.AlternatePowerBar then
		prd.AlternatePowerBar:SetShown(hasAltPowerBar and db.enableAltPowerBar)
	end
	prd:SetScale(db.displayScale / 100)

	if prdClassFrame then
		if db.enableClassFrame then
			prdClassFrame:Show()
			ApplyClassFrameLayout(db)
		elseif prdClassFrame:IsVisible() then
			prdClassFrame:Hide()
		end
	end

	-- Health text
	if healthText then
		if not db.enableHealthText then
			healthFrame:UnregisterEvent("UNIT_HEALTH")
			healthText:Hide()
		else
			healthText:SetFont(db.healthTextFont, db.healthTextSize,
				BuildFontFlags(db.healthTextThickOutline, db.healthTextOutline, db.healthTextMono))
			healthText:SetTextColor(CreateColorFromHexString(db.healthTextColor):GetRGBA())
			local bar = prd and prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar
			if bar then
				healthText:ClearAllPoints()
				healthText:SetPoint(db.healthTextAnchor, bar, db.healthTextAnchor)
			end
			healthText:Show()
			healthFrame:RegisterUnitEvent("UNIT_HEALTH", "player")
			healthText:SetText(AbbreviateNumbers(UnitHealth("player")))
		end
	end

	-- Power text
	if powerText then
		if not db.enablePowerText then
			powerFrame:UnregisterEvent("UNIT_POWER_FREQUENT")
			powerFrame:UnregisterEvent("UNIT_DISPLAYPOWER")
			powerText:Hide()
		else
			powerText:SetFont(db.powerTextFont, db.powerTextSize,
				BuildFontFlags(db.powerTextThickOutline, db.powerTextOutline, db.powerTextMono))
			powerText:SetTextColor(CreateColorFromHexString(db.powerTextColor):GetRGBA())
			local bar = prd and prd.PowerBar
			if bar then
				powerText:ClearAllPoints()
				powerText:SetPoint(db.powerTextAnchor, bar, db.powerTextAnchor)
			end
			powerText:Show()
			powerFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
			powerFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
			powerText:SetText(AbbreviateNumbers(UnitPower("player")))
		end
	end

	-- Alternate power text (OnUpdate-driven, only for DH/Evoker/Monk)
	if hasAltPowerBar and altPowerText then
		if not db.enableAltPowerText then
			altPowerFrame:SetScript("OnUpdate", nil)
			altPowerText:Hide()
		else
			altPowerText:SetFont(db.altPowerTextFont, db.altPowerTextSize,
				BuildFontFlags(db.altPowerTextThickOutline, db.altPowerTextOutline, db.altPowerTextMono))
			altPowerText:SetTextColor(CreateColorFromHexString(db.altPowerTextColor):GetRGBA())
			local bar = prd and prd.AlternatePowerBar
			if bar then
				altPowerText:ClearAllPoints()
				altPowerText:SetPoint(db.altPowerTextAnchor, bar, db.altPowerTextAnchor)
			end
			altPowerText:Show()
			altPowerOptions = ALT_POWER_OPTIONS[db.altPowerTextDecimals or 1]
			altPowerFrame:SetScript("OnUpdate", AltPowerOnUpdate)
		end
	end

	-- Rune cooldown text (Death Knight only)
	if runeTexts[1] then
		if not db.enableRuneCooldownText then
			runeCooldownFrame:SetScript("OnUpdate", nil)
			for i = 1, 6 do
				if runeTexts[i] then runeTexts[i]:Hide() end
			end
		else
			local flags = BuildFontFlags(
				db.runeCooldownTextThickOutline,
				db.runeCooldownTextOutline,
				db.runeCooldownTextMono)
			local rColor = CreateColorFromHexString(db.runeCooldownTextColor)
			for i = 1, 6 do
				local t = runeTexts[i]
				if t then
					t:SetFont(db.runeCooldownTextFont, db.runeCooldownTextSize, flags)
					t:SetTextColor(rColor:GetRGBA())
					local rune = prdClassFrame and prdClassFrame.Runes and prdClassFrame.Runes[i]
					if rune then
						t:ClearAllPoints()
						t:SetPoint(db.runeCooldownTextAnchor, rune, db.runeCooldownTextAnchor)
					end
					t:Show()
				end
			end
			runeCooldownFrame:SetScript("OnUpdate", RuneCooldownOnUpdate)
		end
	end
end

-- ---------------------------------------------------------------------------
-- ADDON_LOADED: DB migration, profile resolution, settings registration
-- ---------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded(ADDON_NAME, function()
	PersonalResourceOptionsDB = PersonalResourceOptionsDB or {}
	local savedDB = PersonalResourceOptionsDB

	local classID = select(3, UnitClass("player"))

	-- Migrate flat DB (v1) to profile structure (v2)
	if not savedDB.schemaVersion or savedDB.schemaVersion < 2 then
		MigrateToV2(savedDB, classID)
	end

	-- Ensure structure exists
	if not savedDB.profiles then savedDB.profiles = {} end
	if not savedDB.profiles["Default"] then savedDB.profiles["Default"] = {} end
	if not savedDB.characterProfiles then savedDB.characterProfiles = {} end

	local charKey = GetCharacterKey()
	local profileName = ResolveProfileName(savedDB, charKey)
	local profile = savedDB.profiles[profileName]

	-- Build flat db for Settings API (preserving table identity across switches)
	local db = {}
	local flat = FlattenProfile(profile, classID)
	for k, v in pairs(flat) do
		db[k] = v
	end

	-- Store references for cross-module access
	PRO.savedDB = savedDB
	PRO.db = db
	PRO.classID = classID
	PRO.charKey = charKey
	PRO.currentProfileName = profileName
	PRO.currentProfile = profile

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

	local function OnSettingChanged()
		UnflattenToProfile(db, PRO.currentProfile, PRO.classID)
		ApplySettings(db)
	end

	categoryID = PRO.RegisterSettings(db, OnSettingChanged, hasAltPowerBar, hasClassFrame, hasCooldownClassFrame)
end)

-- ---------------------------------------------------------------------------
-- Profile CRUD (called from Settings.lua UI)
-- ---------------------------------------------------------------------------

--- Switch the current character to a different profile.
function PRO.SwitchProfile(name)
	if not PRO.savedDB.profiles[name] then return end
	UnflattenToProfile(PRO.db, PRO.currentProfile, PRO.classID)
	PRO.savedDB.characterProfiles[PRO.charKey] = name
	PRO.currentProfileName = name
	PRO.currentProfile = PRO.savedDB.profiles[name]
	wipe(PRO.db)
	local flat = FlattenProfile(PRO.currentProfile, PRO.classID)
	for k, v in pairs(flat) do
		PRO.db[k] = v
	end
	ApplySettings(PRO.db)
end

--- Create a new profile with default values.
function PRO.CreateProfile(name)
	if not name or name == "" or PRO.savedDB.profiles[name] then return false end
	PRO.savedDB.profiles[name] = {}
	return true
end

--- Delete a profile (Default cannot be deleted).
function PRO.DeleteProfile(name)
	if name == "Default" or not PRO.savedDB.profiles[name] then return false end
	PRO.savedDB.profiles[name] = nil
	for charKey, pName in pairs(PRO.savedDB.characterProfiles) do
		if pName == name then
			PRO.savedDB.characterProfiles[charKey] = nil
		end
	end
	if PRO.currentProfileName == name then
		PRO.SwitchProfile("Default")
	end
	return true
end

--- Copy all settings from a source profile into the current profile.
function PRO.CopyProfile(sourceName)
	local source = PRO.savedDB.profiles[sourceName]
	if not source then return false end
	local copy = CopyTable(source)
	wipe(PRO.currentProfile)
	for k, v in pairs(copy) do
		PRO.currentProfile[k] = v
	end
	wipe(PRO.db)
	local flat = FlattenProfile(PRO.currentProfile, PRO.classID)
	for k, v in pairs(flat) do
		PRO.db[k] = v
	end
	ApplySettings(PRO.db)
	return true
end

--- Return a sorted list of all profile names.
function PRO.GetProfileNames()
	local names = {}
	for name in pairs(PRO.savedDB.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

--- Export the current profile as a Base64-encoded string.
function PRO.ExportProfile()
	UnflattenToProfile(PRO.db, PRO.currentProfile, PRO.classID)
	local data = CopyTable(PRO.currentProfile)
	local cbor = C_EncodingUtil.SerializeCBOR(data)
	local compressed = C_EncodingUtil.CompressString(cbor, Enum.CompressionType.Deflate)
	return C_EncodingUtil.EncodeBase64(compressed)
end

--- Import a profile from a Base64-encoded string.
function PRO.ImportProfile(name, encoded)
	local ok, compressed = pcall(C_EncodingUtil.DecodeBase64, encoded)
	if not ok or not compressed then return false, "Invalid Base64 data." end
	local ok2, cbor = pcall(C_EncodingUtil.DecompressString, compressed, Enum.CompressionType.Deflate)
	if not ok2 or not cbor then return false, "Decompression failed." end
	local ok3, data = pcall(C_EncodingUtil.DeserializeCBOR, cbor)
	if not ok3 or type(data) ~= "table" then return false, "Invalid profile data." end
	PRO.savedDB.profiles[name] = data
	return true
end

-- ---------------------------------------------------------------------------
-- PLAYER_LOGIN: create FontStrings, install hooks, apply settings
-- ---------------------------------------------------------------------------

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")

	local db = PRO.db
	local prd = PersonalResourceDisplayFrame
	if not prd or not db then return end

	local healthBar = prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar
	if healthBar then
		healthText = healthBar:CreateFontString(nil, "OVERLAY")
	end
	if prd.PowerBar then
		powerText = prd.PowerBar:CreateFontString(nil, "OVERLAY")
	end
	if prd.AlternatePowerBar then
		altPowerText = prd.AlternatePowerBar:CreateFontString(nil, "OVERLAY")
	end

	-- DK rune cooldown FontStrings
	if select(3, UnitClass("player")) == Constants.UICharacterClasses.DeathKnight
		and prdClassFrame and prdClassFrame.Runes then
		for i = 1, 6 do
			local rune = prdClassFrame.Runes[i]
			if rune then
				runeTexts[i] = rune:CreateFontString(nil, "OVERLAY")
			end
		end
	end

	prd:HookScript("OnShow", function()
		if not db.enableDisplay then
			prd:Hide()
			return
		end
		if prd.HealthBarsContainer and not db.enableHealthBar then
			prd.HealthBarsContainer:Hide()
		end
		if prd.PowerBar and not db.enablePowerBar then
			prd.PowerBar:Hide()
		end
		if prd.AlternatePowerBar and (not hasAltPowerBar or not db.enableAltPowerBar) then
			prd.AlternatePowerBar:Hide()
		end
		if hasClassFrame and prdClassFrame then
			prdClassFrame:SetShown(db.enableClassFrame)
			if db.enableClassFrame then
				ApplyClassFrameLayout(db)
			end
		end
	end)

	if prd.HealthBarsContainer then
		prd.HealthBarsContainer:HookScript("OnShow", function()
			if not db.enableDisplay or not db.enableHealthBar then
				prd.HealthBarsContainer:Hide()
			end
		end)
	end
	if prd.PowerBar then
		prd.PowerBar:HookScript("OnShow", function()
			if not db.enableDisplay or not db.enablePowerBar then
				prd.PowerBar:Hide()
			end
		end)
	end
	if prd.AlternatePowerBar then
		prd.AlternatePowerBar:HookScript("OnShow", function()
			if not db.enableDisplay or not db.enableAltPowerBar then
				prd.AlternatePowerBar:Hide()
			end
		end)
	end
	if hasClassFrame and prdClassFrame then
		prdClassFrame:HookScript("OnShow", function()
			if db.enableDisplay and db.enableClassFrame then
				ApplyClassFrameLayout(db)
			end
		end)
	end

	ApplySettings(db)
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
