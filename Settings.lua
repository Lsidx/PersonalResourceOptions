-- PersonalResourceOptions - Settings.lua
-- Registers addon settings with the Blizzard Settings panel.
-- PRO.RegisterSettings is called once from Core.lua after ADDON_LOADED.

local _, PRO = ...

local CATEGORY_NAME = "Personal Resource Options"

local FONT_DEFAULT = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF"

local ANCHOR_OPTIONS = {
	{ value = "LEFT",        label = "Left"         },
	{ value = "CENTER",      label = "Center"       },
	{ value = "RIGHT",       label = "Right"        },
}

local FONT_OPTIONS = {
	{ value = FONT_DEFAULT,          label = "Expressway"    },
	{ value = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata" },
	{ value = "Fonts\\ARIALN.TTF",   label = "Arial Narrow"  },
	{ value = "Fonts\\MORPHEUS.TTF", label = "Morpheus"      },
	{ value = "Fonts\\SKURRI.TTF",   label = "Skurri"        },
}

local OUTLINE_OPTIONS = {
	{ value = "NONE",         label = "None"          },
	{ value = "OUTLINE",      label = "Outline"       },
	{ value = "THICKOUTLINE", label = "Thick Outline" },
}

-- ---------------------------------------------------------------------------
-- Profile management dialogs
-- ---------------------------------------------------------------------------

StaticPopupDialogs["PRO_NEW_PROFILE"] = {
	text = "Enter a name for the new profile:",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	OnShow = function(dialog)
		dialog:GetEditBox():SetFocus()
	end,
	OnAccept = function(dialog)
		local name = strtrim(dialog:GetEditBox():GetText())
		if name == "" then return end
		if PRO.CreateProfile(name) then
			PRO.profileSetting:SetValue(name)
		else
			print("|cffff6666PRO:|r A profile named '" .. name .. "' already exists.")
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		local btn = dialog:GetButton1()
		if btn and btn:IsEnabled() then
			btn:Click()
		end
	end,
	EditBoxOnTextChanged = StaticPopup_StandardNonEmptyTextHandler,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["PRO_DELETE_PROFILE"] = {
	text = "Delete profile '%s'?\n\nAny characters using this profile will be switched to Default.",
	button1 = DELETE,
	button2 = CANCEL,
	OnAccept = function(dialog, data)
		if PRO.DeleteProfile(data) then
			PRO.profileSetting:SetValue("Default")
		end
	end,
	showAlert = true,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["PRO_EXPORT_PROFILE"] = {
	text = "Copy the export string below (Ctrl+A, Ctrl+C):",
	button1 = DONE,
	hasEditBox = 1,
	OnShow = function(dialog)
		local editBox = dialog:GetEditBox()
		editBox:SetMaxLetters(0)
		local encoded = PRO.ExportProfile()
		editBox:SetText(encoded)
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["PRO_IMPORT_PROFILE"] = {
	text = "Paste an exported profile string:",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	OnShow = function(dialog)
		local editBox = dialog:GetEditBox()
		editBox:SetMaxLetters(0)
		editBox:SetFocus()
	end,
	OnAccept = function(dialog)
		local encoded = strtrim(dialog:GetEditBox():GetText())
		if encoded == "" then return end
		local data, err = PRO.ValidateImport(encoded)
		if not data then
			print("|cffff6666PRO:|r Import failed: " .. (err or "unknown error"))
			return
		end
		PRO._pendingImportData = data
		StaticPopup_Show("PRO_IMPORT_NAME")
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		local btn = dialog:GetButton1()
		if btn and btn:IsEnabled() then
			btn:Click()
		end
	end,
	EditBoxOnTextChanged = StaticPopup_StandardNonEmptyTextHandler,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["PRO_IMPORT_NAME"] = {
	text = "Enter a name for the imported profile (or leave blank for auto-name):",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	OnShow = function(dialog)
		local editBox = dialog:GetEditBox()
		editBox:SetText("")
		editBox:SetFocus()
	end,
	OnAccept = function(dialog)
		local data = PRO._pendingImportData
		PRO._pendingImportData = nil
		if not data then return end
		local input = strtrim(dialog:GetEditBox():GetText())
		local name
		if input ~= "" and not PRO.savedDB.profiles[input] then
			name = input
		else
			if input ~= "" then
				print("|cffff6666PRO:|r '" .. input .. "' already exists, using auto-name.")
			end
			name = PRO.GenerateImportName()
		end
		PRO.StoreImportedProfile(name, data)
		print("|cff00ff00PRO:|r Profile imported as '" .. name .. "'.")
		PRO.profileSetting:SetValue(name)
	end,
	OnCancel = function()
		PRO._pendingImportData = nil
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		local btn = dialog:GetButton1()
		if btn then
			btn:Click()
		end
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["PRO_RENAME_PROFILE"] = {
	text = "Enter a new name for profile '%s':",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	OnShow = function(dialog)
		dialog:GetEditBox():SetFocus()
	end,
	OnAccept = function(dialog, oldName)
		local newName = strtrim(dialog:GetEditBox():GetText())
		if newName == "" then return end
		if PRO.RenameProfile(oldName, newName) then
			print("|cff00ff00PRO:|r Profile renamed to '" .. newName .. "'.")
		else
			print("|cffff6666PRO:|r Could not rename: a profile named '" .. newName .. "' already exists.")
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		local btn = dialog:GetButton1()
		if btn and btn:IsEnabled() then
			btn:Click()
		end
	end,
	EditBoxOnTextChanged = StaticPopup_StandardNonEmptyTextHandler,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

-- Registers all settings controls and returns the numeric category ID.
--
-- db                    : PersonalResourceOptionsDB (already initialized)
-- onChanged             : zero-arg callback; called after any setting is committed
-- hasAltPowerBar        : true for DH / Evoker / Monk
-- hasClassFrame         : true for classes with a prdClassFrame widget
-- hasCooldownClassFrame : true for Death Knight (rune cooldown text)
function PRO.RegisterSettings(db, onChanged, hasAltPowerBar, hasClassFrame, hasCooldownClassFrame)
	local category, layout = Settings.RegisterVerticalLayoutCategory(CATEGORY_NAME)

	-- ── Combat-lockdown predicate applied to all controls ─────────────────
	-- Disables (greys out) every setting while the player is in combat,
	-- since protected nameplate frames cannot be modified from addon code.
	local function NotInCombat()
		return not InCombatLockdown()
	end

	-- ── Spec-aware predicate for alternate power bar ────────────────────
	-- Blizzard sets alternatePowerRequirementsMet on the PRD's AlternatePowerBar
	-- widget based on the current spec (Brewmaster Monk, Vengeance DH, Augmentation
	-- Evoker).  We use this to hide alt-power settings for specs that never see the bar.
	local function SpecUsesAltPower()
		local prd = PersonalResourceDisplayFrame
		return prd and prd.AlternatePowerBar
			and prd.AlternatePowerBar.alternatePowerRequirementsMet == true
	end

	-- ── Shared option-list builders ───────────────────────────────────────

	local function GetAnchorOptions()
		local c = Settings.CreateControlTextContainer()
		for _, o in ipairs(ANCHOR_OPTIONS) do c:Add(o.value, o.label) end
		return c:GetData()
	end

	local function GetFontOptions()
		local c = Settings.CreateControlTextContainer()
		for _, o in ipairs(FONT_OPTIONS) do c:Add(o.value, o.label) end
		return c:GetData()
	end

	local function GetOutlineOptions()
		local c = Settings.CreateControlTextContainer()
		for _, o in ipairs(OUTLINE_OPTIONS) do c:Add(o.value, o.label) end
		return c:GetData()
	end

	-- ── Generic control helpers (close over category / db / onChanged) ────

	local function AddCheckbox(settingKey, dbKey, label, tooltip, default, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.Boolean, label, default)
		local i = Settings.CreateCheckbox(category, s, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		i:AddModifyPredicate(NotInCombat)
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
		s:SetValueChangedCallback(onChanged)
		return i
	end

	local function AddDropdown(settingKey, dbKey, label, tooltip, default, getOptions, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.String, label, default)
		local i = Settings.CreateDropdown(category, s, getOptions, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		i:AddModifyPredicate(NotInCombat)
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
		s:SetValueChangedCallback(onChanged)
		return i
	end

	local function AddSlider(settingKey, dbKey, label, tooltip, default, min, max, step, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.Number, label, default)
		local opts = Settings.CreateSliderOptions(min, max, step)
		opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		local i = Settings.CreateSlider(category, s, opts, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		i:AddModifyPredicate(NotInCombat)
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
		s:SetValueChangedCallback(onChanged)
		return i
	end

	local function AddColorSwatch(settingKey, dbKey, label, tooltip, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.String, label, "ffffffff")
		local i = Settings.CreateColorSwatch(category, s, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		i:AddModifyPredicate(NotInCombat)
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
		i:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
		s:SetValueChangedCallback(onChanged)
		return i
	end

	-- ── Text-overlay section helper ───────────────────────────────────────
	-- Registers the 7 controls common to every text overlay:
	--   enable checkbox -> anchor -> font -> size -> outline -> mono -> color
	--
	-- prefix        : db key prefix, e.g. "health", "power", "altPower", "runeCooldown"
	-- labelPrefix   : UI label prefix, e.g. "", "Power ", "Alt Power ", "Rune Cooldown "
	-- enableLabel   : label for the master enable checkbox
	-- enableTooltip : tooltip for the master enable checkbox
	-- defaultSize   : default font size (14 for text overlays, 12 for rune cooldown)
	-- parentInit    : parent initializer for the enable checkbox
	-- parentPred    : predicate for parentInit (must check full ancestor chain)

	local function AddTextSection(prefix, labelPrefix, enableLabel, enableTooltip,
	                              defaultSize, parentInit, parentPred, shownPred, shownEvent)
		local cap = prefix:sub(1, 1):upper() .. prefix:sub(2)
		local ep  = "enable" .. cap .. "Text"  -- e.g. "enableHealthText"
		local p   = prefix .. "Text"            -- e.g. "healthText"
		local K   = "PRO_"

		local enableInit = AddCheckbox(K..ep, ep, enableLabel, enableTooltip, true, parentInit, parentPred)

		local function leafPred() return parentPred() and db[ep] end

		local i1 = AddDropdown   (K..p.."Anchor",       p.."Anchor",       labelPrefix.."Anchor Point", "Where on the bar the text is anchored.",     "CENTER",     GetAnchorOptions, enableInit, leafPred)
		local i2 = AddDropdown   (K..p.."Font",         p.."Font",         labelPrefix.."Font",          "Typeface used for the text.",                FONT_DEFAULT, GetFontOptions,   enableInit, leafPred)
		local i3 = AddSlider     (K..p.."Size",         p.."Size",         labelPrefix.."Text Size",     "Text size in points (6-32).",                defaultSize,  6, 32, 1,         enableInit, leafPred)
		local i4 = AddDropdown   (K..p.."Outline",      p.."Outline",      labelPrefix.."Outline",       "Outline thickness applied to the text.",     "THICKOUTLINE", GetOutlineOptions, enableInit, leafPred)
		local i5 = AddCheckbox   (K..p.."Mono",         p.."Mono",         labelPrefix.."Monochrome",    "Render the text without anti-aliasing.",     false,                           enableInit, leafPred)
		local i6 = AddColorSwatch(K..p.."Color",        p.."Color",        labelPrefix.."Text Color",    "Color of the text.",                                                           enableInit, leafPred)

		if shownPred then
			for _, init in ipairs({enableInit, i1, i2, i3, i4, i5, i6}) do
				init:AddShownPredicate(shownPred)
				if shownEvent then
					init:AddEvaluateStateFrameEvent(shownEvent)
				end
			end
		end

		return enableInit
	end

	-- ── Button helper (combat-disabled) ─────────────────────────────────
	-- Button controls inherit SettingsListElementMixin (not SettingsControlMixin),
	-- so AddModifyPredicate has no effect on them.  We flag our initializers
	-- and install a one-time global hook on the mixin's EvaluateState to
	-- disable them during combat.

	if not SettingsButtonControlMixin._proCombatHooked then
		hooksecurefunc(SettingsButtonControlMixin, "EvaluateState", function(self)
			local init = self:GetElementData()
			if init and init._proCombatDisable and InCombatLockdown() then
				self.Button:SetEnabled(false)
				self:DisplayEnabled(false)
			end
		end)
		SettingsButtonControlMixin._proCombatHooked = true
	end

	local function AddButton(label, buttonText, onClick, tooltip)
		local safeClick = function(...)
			if InCombatLockdown() then return end
			onClick(...)
		end
		local init = CreateSettingsButtonInitializer(label, buttonText, safeClick, tooltip, true)
		init:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
		init:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
		init._proCombatDisable = true
		layout:AddInitializer(init)
	end

	-- ═════════════════════════════════════════════════════════════════════
	-- Profiles
	-- ═════════════════════════════════════════════════════════════════════

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Profiles"))

	local function GetProfileOptions()
		local c = Settings.CreateControlTextContainer()
		for _, name in ipairs(PRO.GetProfileNames()) do
			c:Add(name, name)
		end
		return c:GetData()
	end

	local profileSetting = Settings.RegisterProxySetting(category, "PRO_PROFILE",
		Settings.VarType.String, "Active Profile", "Default",
		function() return PRO.currentProfileName end,
		function(name) PRO.SwitchProfile(name) end)
	local profileInit = Settings.CreateDropdown(category, profileSetting, GetProfileOptions,
		"Select the active profile for this character.")
	profileInit:AddModifyPredicate(NotInCombat)
	profileInit:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
	profileInit:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
	PRO.profileSetting = profileSetting

	local function GetCopyOptions()
		local c = Settings.CreateControlTextContainer()
		for _, name in ipairs(PRO.GetProfileNames()) do
			if name ~= PRO.currentProfileName then
				c:Add(name, name)
			end
		end
		return c:GetData()
	end

	local copySetting = Settings.RegisterProxySetting(category, "PRO_COPY_FROM",
		Settings.VarType.String, "Copy Settings From", "",
		function() return "" end,
		function(name)
			if name ~= "" then
				PRO.CopyProfile(name)
			end
		end)
	local copyInit = Settings.CreateDropdown(category, copySetting, GetCopyOptions,
		"Immediately copies all settings from the selected profile into the active profile.")
	copyInit.getSelectionTextFunc = function()
		return "Select a profile..."
	end
	copyInit:AddModifyPredicate(NotInCombat)
	copyInit:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
	copyInit:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")

	AddButton("", "New Profile",
		function() StaticPopup_Show("PRO_NEW_PROFILE") end,
		"Create a new empty profile.")

	AddButton("", "Delete Profile",
		function()
			if PRO.currentProfileName == "Default" then
				print("|cffff6666PRO:|r The Default profile cannot be deleted.")
				return
			end
			StaticPopup_Show("PRO_DELETE_PROFILE", PRO.currentProfileName, nil, PRO.currentProfileName)
		end,
		"Delete the current profile.")

	AddButton("", "Rename Profile",
		function()
			if PRO.currentProfileName == "Default" then
				print("|cffff6666PRO:|r The Default profile cannot be renamed.")
				return
			end
			StaticPopup_Show("PRO_RENAME_PROFILE", PRO.currentProfileName, nil, PRO.currentProfileName)
		end,
		"Rename the current profile.")

	AddButton("", "Export Profile",
		function() StaticPopup_Show("PRO_EXPORT_PROFILE") end,
		"Export the current profile as a shareable string.")

	AddButton("", "Import Profile",
		function() StaticPopup_Show("PRO_IMPORT_PROFILE") end,
		"Import a profile from a shared string.")

	-- ═════════════════════════════════════════════════════════════════════
	-- Display
	-- ═════════════════════════════════════════════════════════════════════

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Display"))

	-- ── Show Display (read-only unless override is active) ───────────────

	local function ShowDisplayTooltip()
		if db.overrideDisplay then
			return "Show or hide the Personal Resource Display. Override mode is active: all characters using this profile will use this value."
		else
			return "Reflects whether the Personal Resource Display is currently shown. This is controlled by the character-specific CVar (Options > Combat > Personal Resource Display). Enable Override Display Visibility below to control this setting directly."
		end
	end

	local function CanModifyShowDisplay()
		return not InCombatLockdown() and db.overrideDisplay
	end

	local enableDisplaySetting = Settings.RegisterAddOnSetting(category, "PRO_enableDisplay", "enableDisplay", db, Settings.VarType.Boolean, "Show Display", true)
	local enableDisplayInitializer = Settings.CreateCheckbox(category, enableDisplaySetting, ShowDisplayTooltip)
	enableDisplayInitializer:AddModifyPredicate(CanModifyShowDisplay)
	enableDisplayInitializer:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
	enableDisplayInitializer:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
	-- Re-evaluate when Override changes so the checkbox grays/ungrays immediately.
	-- AddEvaluateStateCVar works for addon settings too (shared SettingsCallbackRegistry).
	enableDisplayInitializer:AddEvaluateStateCVar("PRO_overrideDisplay")
	enableDisplaySetting:SetValueChangedCallback(onChanged)
	PRO.enableDisplaySetting = enableDisplaySetting

	local function IsDisplayEnabled() return db.enableDisplay end

	-- ── Override Display (controls whether Show Display is user-editable) ──

	local overrideDisplaySetting = Settings.RegisterAddOnSetting(
		category, "PRO_overrideDisplay", "overrideDisplay", db,
		Settings.VarType.Boolean, "Override Display Visibility", false)
	local overrideDisplayInitializer = Settings.CreateCheckbox(category, overrideDisplaySetting,
		"Personal Resource Display visibility is normally controlled through a character-specific CVar. " ..
		"Enabling this option overrides that value to use a single setting, the Show Display checkbox above, for all characters.")
	overrideDisplayInitializer:AddModifyPredicate(NotInCombat)
	overrideDisplayInitializer:AddEvaluateStateFrameEvent("PLAYER_REGEN_ENABLED")
	overrideDisplayInitializer:AddEvaluateStateFrameEvent("PLAYER_REGEN_DISABLED")
	overrideDisplaySetting:SetValueChangedCallback(function(setting, value)
		-- When override is turned off, sync enableDisplay from the CVar
		-- so the grayed-out checkbox reflects the current Blizzard state
		-- rather than the addon's stale override value.
		if not value then
			local cvarEnabled = C_CVar.GetCVar(PRO.PRD_ENABLED_CVAR) == "1"
			if db.enableDisplay ~= cvarEnabled then
				db.enableDisplay = cvarEnabled
				if PRO.enableDisplaySetting then
					PRO.enableDisplaySetting:SetValue(cvarEnabled)
				end
			end
		end
		onChanged()
	end)

	local enableHealthBarInitializer = AddCheckbox(
		"PRO_enableHealthBar", "enableHealthBar",
		"Show Health Bar", "Show or hide the health bar.",
		true, enableDisplayInitializer, IsDisplayEnabled)

	local enablePowerBarInitializer = AddCheckbox(
		"PRO_enablePowerBar", "enablePowerBar",
		"Show Power Bar", "Show or hide the power bar.",
		true, enableDisplayInitializer, IsDisplayEnabled)

	local enableAltPowerBarInitializer
	if hasAltPowerBar then
		enableAltPowerBarInitializer = AddCheckbox(
			"PRO_enableAltPowerBar", "enableAltPowerBar",
			"Show Alternate Power Bar", "Show or hide the alternate power bar.",
			true, enableDisplayInitializer, IsDisplayEnabled)
		enableAltPowerBarInitializer:AddShownPredicate(SpecUsesAltPower)
		enableAltPowerBarInitializer:AddEvaluateStateFrameEvent("PLAYER_SPECIALIZATION_CHANGED")
	end

	local enableClassFrameInitializer
	if hasClassFrame then
		enableClassFrameInitializer = AddCheckbox(
			"PRO_enableClassFrame", "enableClassFrame",
			"Show Class Frame", "Show or hide the class resource frame.",
			true, enableDisplayInitializer, IsDisplayEnabled)
	end

	AddSlider(
		"PRO_displayScale", "displayScale",
		"Display Scale (%)", "Scale of the entire Personal Resource Display (50-400%).",
		100, 50, 400, 5, enableDisplayInitializer, IsDisplayEnabled)

	-- ═════════════════════════════════════════════════════════════════════
	-- Health Bar Text
	-- ═════════════════════════════════════════════════════════════════════

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Health Bar Text"))

	AddTextSection("health", "", "Show Health Value",
		"Display the current health value on the health bar.",
		14, enableHealthBarInitializer,
		function() return db.enableDisplay and db.enableHealthBar end)

	-- ═════════════════════════════════════════════════════════════════════
	-- Power Bar Text
	-- ═════════════════════════════════════════════════════════════════════

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Power Bar Text"))

	AddTextSection("power", "Power ", "Show Power Value",
		"Display the current power value on the power bar.",
		14, enablePowerBarInitializer,
		function() return db.enableDisplay and db.enablePowerBar end)

	-- ═════════════════════════════════════════════════════════════════════
	-- Alternate Power Bar Text
	-- Only for Demon Hunter (Soul Fragments), Evoker (Ebon Might), Monk (Stagger).
	-- ═════════════════════════════════════════════════════════════════════

	if hasAltPowerBar then
		local altPowerTextHeader = CreateSettingsListSectionHeaderInitializer("Alternate Power Bar Text")
		altPowerTextHeader:AddShownPredicate(SpecUsesAltPower)
		altPowerTextHeader:AddEvaluateStateFrameEvent("PLAYER_SPECIALIZATION_CHANGED")
		layout:AddInitializer(altPowerTextHeader)

		local altPowerEnableInit = AddTextSection("altPower", "Alt Power ", "Show Alternate Power Value",
			"Display the current value on the alternate power bar.",
			14, enableAltPowerBarInitializer,
			function() return db.enableDisplay and db.enableAltPowerBar end,
			SpecUsesAltPower, "PLAYER_SPECIALIZATION_CHANGED")

		local decimalsInit = AddSlider(
			"PRO_altPowerTextDecimals", "altPowerTextDecimals",
			"Alt Power Decimal Places",
			"Decimal places shown (0 = integer, 1 = one decimal, 2 = two). Evoker Ebon Might benefits from 1; DH Soul Fragments and Monk Stagger are always whole numbers.",
			1, 0, 2, 1,
			altPowerEnableInit,
			function() return db.enableDisplay and db.enableAltPowerBar and db.enableAltPowerText end)
		decimalsInit:AddShownPredicate(SpecUsesAltPower)
		decimalsInit:AddEvaluateStateFrameEvent("PLAYER_SPECIALIZATION_CHANGED")
	end

	-- ═════════════════════════════════════════════════════════════════════
	-- Class Frame  (Paladin, Rogue, DK, Mage, Warlock, Monk, Druid, Evoker)
	-- Scale + position offset.  Rune cooldown sub-section for DK only.
	-- ═════════════════════════════════════════════════════════════════════

	if hasClassFrame then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Class Frame"))

		local function IsClassFrameEnabled() return db.enableDisplay and db.enableClassFrame end

		AddSlider("PRO_classFrameScale", "classFrameScale",
			"Class Frame Scale (%)", "Scale of the class resource frame widget (50-400%).",
			100, 50, 400, 5, enableClassFrameInitializer, IsClassFrameEnabled)

		AddSlider("PRO_classFrameOffsetX", "classFrameOffsetX",
			"Class Frame X Offset", "Horizontal offset from the default position.",
			0, -50, 50, 1, enableClassFrameInitializer, IsClassFrameEnabled)

		AddSlider("PRO_classFrameOffsetY", "classFrameOffsetY",
			"Class Frame Y Offset", "Vertical offset from the default position.",
			0, -50, 50, 1, enableClassFrameInitializer, IsClassFrameEnabled)

		if hasCooldownClassFrame then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Rune Cooldown Text"))

			AddTextSection("runeCooldown", "Rune Cooldown ", "Show Rune Cooldowns",
				"Display remaining cooldown time on each Death Knight rune.",
				12, enableClassFrameInitializer, IsClassFrameEnabled)
		end
	end

	-- RegisterAddOnCategory must be called last, after all settings are added.
	Settings.RegisterAddOnCategory(category)

	return category:GetID()
end
