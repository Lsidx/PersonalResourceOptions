-- PersonalResourceOptions - Core.lua
-- Combat health and power text overlays for the Personal Resource Display.
--
-- Overhead contract when a text option is OFF:
--   Its unit event is unregistered entirely → zero runtime overhead.
-- Overhead when ON:
--   One SetText() per relevant unit event.  Values are passed straight through
--   AbbreviateNumbers → SetText with no arithmetic or comparisons performed by
--   addon code, satisfying the taint requirements of restricted (raid / M+)
--   environments.

local ADDON_NAME = "PersonalResourceOptions";

-- Upvalue the hot-path globals to avoid repeated table lookups.
local UnitHealth          = UnitHealth;
local UnitPower           = UnitPower;
local AbbreviateNumbers   = AbbreviateNumbers;
local GetRuneCooldown     = GetRuneCooldown;
local GetTime             = GetTime;
local ceil = math.ceil;

-- Category ID returned by PRO_RegisterSettings; used by the slash command.
local categoryID;

-- FontStrings drawn over their respective bars.  Created once, never destroyed.
local healthText;
local powerText;
local altPowerText;

-- Class capability flags set during init; used by ApplySettings to avoid
-- showing bars/frames that don't exist for the player's class.
local hasAltPowerBar = false;
local hasClassFrame  = false;

-- Dedicated frames that own their event registrations.
-- Keeping them separate means each can be registered/unregistered independently.
local healthFrame = CreateFrame("Frame");
healthFrame:SetScript("OnEvent", function()
	-- Hot path: pass the health value directly to the screen.
	-- No math, no comparisons, no branching on the value itself.
	healthText:SetText(AbbreviateNumbers(UnitHealth("player")));
end);

local powerFrame = CreateFrame("Frame");
powerFrame:SetScript("OnEvent", function()
	powerText:SetText(AbbreviateNumbers(UnitPower("player")));
end);

-- The alternate power bar (DH Soul Fragments, Evoker Ebon Might, Monk Stagger)
-- is OnUpdate-driven internally by Blizzard -- there is no consistent unit event
-- across all three.  We mirror that pattern with our own OnUpdate frame.
local altPowerFrame = CreateFrame("Frame");
local function AltPowerOnUpdate()
	altPowerText:SetText(AbbreviateNumbers(
		PersonalResourceDisplayFrame.AlternatePowerBar:GetValue()));
end;

-- Per-rune FontStrings for Death Knight cooldown countdown text (indices 1-6).
-- Created at init time if the player is a Death Knight; nil for all other classes.
local runeTexts = {};

-- OnUpdate frame for rune cooldown text.  The script is set/cleared in
-- ApplySettings so there is zero overhead when the feature is disabled.
local runeCooldownFrame = CreateFrame("Frame");
local function RuneCooldownOnUpdate()
	for i = 1, 6 do
		local t = runeTexts[i];
		if t then
			local start, duration, runeReady = GetRuneCooldown(i);
			if runeReady or not start then
				t:SetText("");
			else
				t:SetText(ceil(start + duration - GetTime()));
			end
		end
	end
end;
-- -----------------------------------------------------------------------------
-- ApplySettings
-- Reads all values from PersonalResourceOptionsDB and reconfigures the
-- FontString.  The db table is always current when this is called because
-- Settings.RegisterAddOnSetting writes changes to it automatically.
-- -----------------------------------------------------------------------------
-- Shared helper: builds the font flags string from three booleans.
local function BuildFontFlags(thickOutline, outline, mono)
	local flags;
	if thickOutline then
		flags = "THICKOUTLINE";
	elseif outline then
		flags = "OUTLINE";
	else
		flags = "";
	end
	if mono then
		flags = (flags == "") and "MONOCHROME" or (flags .. ",MONOCHROME");
	end
	return flags;
end

-- -----------------------------------------------------------------------------
-- ApplyClassFrameLayout
-- Applies scale and X/Y offset to prdClassFrame.  Kept as a separate function
-- because it is also called from prdClassFrame's OnShow post-hook: Blizzard's
-- own OnShow handler resets the CENTER anchor, so we re-apply ours afterward.
-- -----------------------------------------------------------------------------
local function ApplyClassFrameLayout(db)
	if not prdClassFrame then return; end
	prdClassFrame:SetScale(db.classFrameScale / 100);
	prdClassFrame:ClearAllPoints();
	prdClassFrame:SetPoint("CENTER",
		PersonalResourceDisplayFrame.ClassFrameContainer, "CENTER",
		db.classFrameOffsetX, db.classFrameOffsetY);
end

local function ApplySettings(db)
	-- ── Display / bar visibility ───────────────────────────────────────
	local prd = PersonalResourceDisplayFrame;
	if prd then
		if not db.enableDisplay then
			prd:Hide();
		else
			prd:Show();
			if prd.HealthBarsContainer then
				if db.enableHealthBar then
					prd.HealthBarsContainer:Show();
				else
					prd.HealthBarsContainer:Hide();
				end
			end
			if prd.PowerBar then
				if db.enablePowerBar then
					prd.PowerBar:Show();
				else
					prd.PowerBar:Hide();
				end
			end
			if prd.AlternatePowerBar then
				if hasAltPowerBar and db.enableAltPowerBar then
					prd.AlternatePowerBar:Show();
				else
					prd.AlternatePowerBar:Hide();
				end
			end
		end
		prd:SetScale(db.displayScale / 100);
	end

	-- ── Class frame layout ─────────────────────────────────────────────
	if prdClassFrame then
		if not hasClassFrame or not db.enableDisplay or not db.enableClassFrame then
			prdClassFrame:Hide();
		else
			prdClassFrame:Show();
		end
	end
	ApplyClassFrameLayout(db);

	-- ── Health text ──────────────────────────────────────────────────────
	if healthText then
		if not db.enableHealthText then
			healthFrame:UnregisterEvent("UNIT_HEALTH");
			healthText:Hide();
		else
			healthText:SetFont(db.healthTextFont, db.healthTextSize,
				BuildFontFlags(db.healthTextThickOutline, db.healthTextOutline, db.healthTextMono));

			local hColor = CreateColorFromHexString(db.healthTextColor);
			healthText:SetTextColor(hColor:GetRGBA());

			local healthBar = PersonalResourceDisplayFrame
				and PersonalResourceDisplayFrame.HealthBarsContainer
				and PersonalResourceDisplayFrame.HealthBarsContainer.healthBar;
			if healthBar then
				healthText:ClearAllPoints();
				healthText:SetPoint(db.healthTextAnchor, healthBar, db.healthTextAnchor);
			end

			healthText:Show();
			healthFrame:RegisterUnitEvent("UNIT_HEALTH", "player");
			healthText:SetText(AbbreviateNumbers(UnitHealth("player")));
		end
	end

	-- ── Power text ───────────────────────────────────────────────────────
	if powerText then
		if not db.enablePowerText then
			powerFrame:UnregisterEvent("UNIT_POWER_FREQUENT");
			powerFrame:UnregisterEvent("UNIT_DISPLAYPOWER");
			powerText:Hide();
		else
			powerText:SetFont(db.powerTextFont, db.powerTextSize,
				BuildFontFlags(db.powerTextThickOutline, db.powerTextOutline, db.powerTextMono));

			local pColor = CreateColorFromHexString(db.powerTextColor);
			powerText:SetTextColor(pColor:GetRGBA());

			local powerBar = PersonalResourceDisplayFrame
				and PersonalResourceDisplayFrame.PowerBar;
			if powerBar then
				powerText:ClearAllPoints();
				powerText:SetPoint(db.powerTextAnchor, powerBar, db.powerTextAnchor);
			end

			powerText:Show();
			powerFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player");
			powerFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player");
			powerText:SetText(AbbreviateNumbers(UnitPower("player")));
		end
	end
	-- ── Alternate power text ─────────────────────────────────────────────
	-- Guard with hasAltPowerBar: altPowerText is created for every class because
	-- AlternatePowerBar always exists in the XML, but we must not set an OnUpdate
	-- for classes that never use it or the frame will fire every frame for nothing.
	if hasAltPowerBar and altPowerText then
		if not db.enableAltPowerText then
			altPowerFrame:SetScript("OnUpdate", nil);
			altPowerText:Hide();
		else
			altPowerText:SetFont(db.altPowerTextFont, db.altPowerTextSize,
				BuildFontFlags(db.altPowerTextThickOutline, db.altPowerTextOutline, db.altPowerTextMono));

			local aColor = CreateColorFromHexString(db.altPowerTextColor);
			altPowerText:SetTextColor(aColor:GetRGBA());

			local altPowerBar = PersonalResourceDisplayFrame
				and PersonalResourceDisplayFrame.AlternatePowerBar;
			if altPowerBar then
				altPowerText:ClearAllPoints();
				altPowerText:SetPoint(db.altPowerTextAnchor, altPowerBar, db.altPowerTextAnchor);
			end

			altPowerText:Show();
			altPowerFrame:SetScript("OnUpdate", AltPowerOnUpdate);
		end
	end

	-- ── Rune cooldown text (Death Knight only) ───────────────────────────
	if runeTexts[1] then
		if not db.enableRuneCooldownText then
			runeCooldownFrame:SetScript("OnUpdate", nil);
			for i = 1, 6 do
				if runeTexts[i] then runeTexts[i]:Hide(); end
			end
		else
			local flags = BuildFontFlags(
				db.runeCooldownTextThickOutline,
				db.runeCooldownTextOutline,
				db.runeCooldownTextMono);
			local rColor = CreateColorFromHexString(db.runeCooldownTextColor);
			for i = 1, 6 do
				local t = runeTexts[i];
				if t then
					t:SetFont(db.runeCooldownTextFont, db.runeCooldownTextSize, flags);
					t:SetTextColor(rColor:GetRGBA());
					local rune = prdClassFrame and prdClassFrame.Runes and prdClassFrame.Runes[i];
					if rune then
						t:ClearAllPoints();
						t:SetPoint(db.runeCooldownTextAnchor, rune, db.runeCooldownTextAnchor);
					end
					t:Show();
				end
			end
			runeCooldownFrame:SetScript("OnUpdate", RuneCooldownOnUpdate);
		end
	end
end
-- Runs once when our addon finishes loading.  Using EventUtil.ContinueOnAddOnLoaded
-- is the canonical pattern recommended in Blizzard_ImplementationReadme.lua.
-- -----------------------------------------------------------------------------
EventUtil.ContinueOnAddOnLoaded(ADDON_NAME, function()
	-- Ensure saved-variable table exists and every key has a valid value.
	-- Settings.RegisterAddOnSetting will also default-initialize nil keys, but
	-- ApplySettings reads from db directly so we fill in any gaps now.
	PersonalResourceOptionsDB = PersonalResourceOptionsDB or {};
	local db = PersonalResourceOptionsDB;

	local defaults = {
		-- Display
		enableDisplay             = true,
		enableHealthBar           = true,
		enablePowerBar            = true,
		enableAltPowerBar         = true,
		enableClassFrame          = true,
		displayScale              = 100,
		-- Class frame
		classFrameScale           = 100,
		classFrameOffsetX         = 0,
		classFrameOffsetY         = 0,
		-- Health text
		enableHealthText       = true,
		healthTextAnchor       = "CENTER",
		healthTextFont         = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
		healthTextSize         = 14,
		healthTextOutline      = false,
		healthTextThickOutline = true,
		healthTextMono         = false,
		healthTextColor        = "ffffffff",
		-- Power text
		enablePowerText        = true,
		powerTextAnchor        = "CENTER",
		powerTextFont          = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
		powerTextSize          = 14,
		powerTextOutline       = false,
		powerTextThickOutline  = true,
		powerTextMono          = false,
		powerTextColor         = "ffffffff",
		-- Alternate power text
		enableAltPowerText        = true,
		altPowerTextAnchor        = "CENTER",
		altPowerTextFont          = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
		altPowerTextSize          = 14,
		altPowerTextOutline       = false,
		altPowerTextThickOutline  = true,
		altPowerTextMono          = false,
		altPowerTextColor         = "ffffffff",
		-- Rune cooldown text (Death Knight)
		enableRuneCooldownText       = true,
		runeCooldownTextAnchor       = "CENTER",
		runeCooldownTextFont         = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF",
		runeCooldownTextSize         = 12,
		runeCooldownTextOutline      = false,
		runeCooldownTextThickOutline = true,
		runeCooldownTextMono         = false,
		runeCooldownTextColor        = "ffffffff",
	};
	for key, default in pairs(defaults) do
		if db[key] == nil then
			db[key] = default;
		end
	end

	-- Create FontStrings parented to their bars so they inherit show/hide state
	-- and move with the bars automatically.
	local healthBar = PersonalResourceDisplayFrame
		and PersonalResourceDisplayFrame.HealthBarsContainer
		and PersonalResourceDisplayFrame.HealthBarsContainer.healthBar;
	if healthBar then
		healthText = healthBar:CreateFontString(nil, "OVERLAY");
	end

	local powerBar = PersonalResourceDisplayFrame
		and PersonalResourceDisplayFrame.PowerBar;
	if powerBar then
		powerText = powerBar:CreateFontString(nil, "OVERLAY");
	end

	-- AlternatePowerBar always exists in the XML (hidden by default); parent our
	-- FontString to it so it inherits the bar's show/hide state automatically.
	local altPowerBar = PersonalResourceDisplayFrame
		and PersonalResourceDisplayFrame.AlternatePowerBar;
	if altPowerBar then
		altPowerText = altPowerBar:CreateFontString(nil, "OVERLAY");
	end

	-- Hook bars so our disable preference is re-asserted whenever Blizzard
	-- re-shows them.  HookScript leaves Blizzard's own OnShow logic intact.
	local prdHook = PersonalResourceDisplayFrame;
	if prdHook then
		prdHook:HookScript("OnShow", function()
			if not db.enableDisplay then prdHook:Hide(); end
		end);
		if prdHook.HealthBarsContainer then
			prdHook.HealthBarsContainer:HookScript("OnShow", function()
				if not db.enableDisplay or not db.enableHealthBar then
					prdHook.HealthBarsContainer:Hide();
				end
			end);
		end
		if prdHook.PowerBar then
			prdHook.PowerBar:HookScript("OnShow", function()
				if not db.enableDisplay or not db.enablePowerBar then
					prdHook.PowerBar:Hide();
				end
			end);
		end
		if prdHook.AlternatePowerBar then
			prdHook.AlternatePowerBar:HookScript("OnShow", function()
				if not db.enableDisplay or not db.enableAltPowerBar then
					prdHook.AlternatePowerBar:Hide();
				end
			end);
		end
	end

	-- Detect whether this character's class can ever have an alternate power bar.
	-- Used by PRO_RegisterSettings to conditionally show the alt power section.
	local classID = select(3, UnitClass("player"));
	hasAltPowerBar = classID == Constants.UICharacterClasses.DemonHunter
		or classID == Constants.UICharacterClasses.Evoker
		or classID == Constants.UICharacterClasses.Monk;

	-- Detect whether this class has a prdClassFrame at all, and whether it is
	-- a cooldown-based resource (only DK runes have GetRuneCooldown support).
	hasClassFrame = classID == Constants.UICharacterClasses.Paladin
		or classID == Constants.UICharacterClasses.Rogue
		or classID == Constants.UICharacterClasses.DeathKnight
		or classID == Constants.UICharacterClasses.Mage
		or classID == Constants.UICharacterClasses.Warlock
		or classID == Constants.UICharacterClasses.Monk
		or classID == Constants.UICharacterClasses.Druid
		or classID == Constants.UICharacterClasses.Evoker;
	local hasCooldownClassFrame = classID == Constants.UICharacterClasses.DeathKnight;

	-- For DK: create one FontString per rune for cooldown countdown display.
	-- prdClassFrame is the global frame created by Blizzard_PersonalResourceDisplay.
	if hasCooldownClassFrame and prdClassFrame and prdClassFrame.Runes then
		for i = 1, 6 do
			local rune = prdClassFrame.Runes[i];
			if rune then
				runeTexts[i] = rune:CreateFontString(nil, "OVERLAY");
			end
		end
	end

	-- Maintain our class frame offset when Blizzard's own OnShow handler
	-- resets the anchor.  The post-hook fires after Blizzard's handler.
	if hasClassFrame and prdClassFrame then
		prdClassFrame:HookScript("OnShow", function()
			if not db.enableDisplay or not db.enableClassFrame then
				prdClassFrame:Hide();
				return;
			end
			ApplyClassFrameLayout(db);
		end);
	end

	-- Register the Blizzard Settings panel (defined in Settings.lua).
	-- The callback re-applies all settings whenever any value is committed.
	categoryID = PRO_RegisterSettings(db, function()
		ApplySettings(db);
	end, hasAltPowerBar, hasClassFrame, hasCooldownClassFrame);

	-- Reflect stored settings on the FontString for the current session.
	ApplySettings(db);
end);

-- -----------------------------------------------------------------------------
-- Settings panel opener
-- OpenSettingsPanel() is a protected function; calling it in combat triggers
-- ADDON_ACTION_BLOCKED.  We defer the open until PLAYER_REGEN_ENABLED when the
-- player is still in combat lockdown.
-- -----------------------------------------------------------------------------
local pendingSettingsOpen = false;

local combatEndFrame = CreateFrame("Frame");
combatEndFrame:SetScript("OnEvent", function()
	combatEndFrame:UnregisterEvent("PLAYER_REGEN_ENABLED");
	pendingSettingsOpen = false;
	if categoryID then
		Settings.OpenToCategory(categoryID);
	end
end);

local function OpenSettings()
	if not categoryID then return; end
	if InCombatLockdown() then
		if not pendingSettingsOpen then
			pendingSettingsOpen = true;
			combatEndFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
		end
	else
		Settings.OpenToCategory(categoryID);
	end
end

-- -----------------------------------------------------------------------------
-- Slash command  /pro  →  opens the addon settings panel
-- -----------------------------------------------------------------------------
SLASH_PERSONALRESOURCEOPTIONS1 = "/pro";
SlashCmdList["PERSONALRESOURCEOPTIONS"] = function()
	OpenSettings();
end;

-- -----------------------------------------------------------------------------
-- Addon Compartment click handler
-- Declared global for the Blizzard Addon Compartment system, which looks up
-- this function by name (via AddonCompartmentFunc in the .toc file) and calls
-- it with (addonName, buttonName) on each click.
-- -----------------------------------------------------------------------------
function PRO_OnAddonCompartmentClick(addonName, buttonName)
	OpenSettings();
end;
