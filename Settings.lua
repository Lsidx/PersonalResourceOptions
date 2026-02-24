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

	-- ── Generic control helpers (close over category / db / onChanged) ────

	local function AddCheckbox(settingKey, dbKey, label, tooltip, default, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.Boolean, label, default)
		local i = Settings.CreateCheckbox(category, s, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		s:SetValueChangedCallback(onChanged)
		return i
	end

	local function AddDropdown(settingKey, dbKey, label, tooltip, default, getOptions, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.String, label, default)
		local i = Settings.CreateDropdown(category, s, getOptions, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		s:SetValueChangedCallback(onChanged)
		return i
	end

	local function AddSlider(settingKey, dbKey, label, tooltip, default, min, max, step, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.Number, label, default)
		local opts = Settings.CreateSliderOptions(min, max, step)
		opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		local i = Settings.CreateSlider(category, s, opts, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		s:SetValueChangedCallback(onChanged)
		return i
	end

	local function AddColorSwatch(settingKey, dbKey, label, tooltip, parentInit, predicate)
		local s = Settings.RegisterAddOnSetting(category, settingKey, dbKey, db, Settings.VarType.String, label, "ffffffff")
		local i = Settings.CreateColorSwatch(category, s, tooltip)
		if parentInit then i:SetParentInitializer(parentInit, predicate) end
		s:SetValueChangedCallback(onChanged)
		return i
	end

	-- ── Text-overlay section helper ───────────────────────────────────────
	-- Registers the 8 controls common to every text overlay:
	--   enable checkbox -> anchor -> font -> size -> outline -> thick outline -> mono -> color
	--
	-- prefix        : db key prefix, e.g. "health", "power", "altPower", "runeCooldown"
	-- labelPrefix   : UI label prefix, e.g. "", "Power ", "Alt Power ", "Rune Cooldown "
	-- enableLabel   : label for the master enable checkbox
	-- enableTooltip : tooltip for the master enable checkbox
	-- defaultSize   : default font size (14 for text overlays, 12 for rune cooldown)
	-- parentInit    : parent initializer for the enable checkbox
	-- parentPred    : predicate for parentInit (must check full ancestor chain)

	local function AddTextSection(prefix, labelPrefix, enableLabel, enableTooltip,
	                              defaultSize, parentInit, parentPred)
		local cap = prefix:sub(1, 1):upper() .. prefix:sub(2)
		local ep  = "enable" .. cap .. "Text"  -- e.g. "enableHealthText"
		local p   = prefix .. "Text"            -- e.g. "healthText"
		local K   = "PRO_"

		local enableInit = AddCheckbox(K..ep, ep, enableLabel, enableTooltip, true, parentInit, parentPred)

		local function leafPred() return parentPred() and db[ep] end

		AddDropdown   (K..p.."Anchor",       p.."Anchor",       labelPrefix.."Anchor Point", "Where on the bar the text is anchored.",     "CENTER",     GetAnchorOptions, enableInit, leafPred)
		AddDropdown   (K..p.."Font",         p.."Font",         labelPrefix.."Font",          "Typeface used for the text.",                FONT_DEFAULT, GetFontOptions,   enableInit, leafPred)
		AddSlider     (K..p.."Size",         p.."Size",         labelPrefix.."Text Size",     "Text size in points (6-32).",                defaultSize,  6, 32, 1,         enableInit, leafPred)
		AddCheckbox   (K..p.."Outline",      p.."Outline",      labelPrefix.."Outline",       "Apply a thin outline to the text.",          false,                           enableInit, leafPred)
		AddCheckbox   (K..p.."ThickOutline", p.."ThickOutline", labelPrefix.."Thick Outline", "Apply a thick outline (overrides Outline).", false,                           enableInit, leafPred)
		AddCheckbox   (K..p.."Mono",         p.."Mono",         labelPrefix.."Monochrome",    "Render the text without anti-aliasing.",     false,                           enableInit, leafPred)
		AddColorSwatch(K..p.."Color",        p.."Color",        labelPrefix.."Text Color",    "Color of the text.",                                                           enableInit, leafPred)
		return enableInit
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
	Settings.CreateDropdown(category, profileSetting, GetProfileOptions,
		"Select the active profile for this character.")
	PRO.profileSetting = profileSetting

	local addSearchTags = true

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"", "New Profile",
		function() StaticPopup_Show("PRO_NEW_PROFILE") end,
		"Create a new empty profile.", addSearchTags))

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"", "Delete Profile",
		function()
			if PRO.currentProfileName == "Default" then
				print("|cffff6666PRO:|r The Default profile cannot be deleted.")
				return
			end
			StaticPopup_Show("PRO_DELETE_PROFILE", PRO.currentProfileName, nil, PRO.currentProfileName)
		end,
		"Delete the current profile.", addSearchTags))

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"", "Rename Profile",
		function()
			if PRO.currentProfileName == "Default" then
				print("|cffff6666PRO:|r The Default profile cannot be renamed.")
				return
			end
			StaticPopup_Show("PRO_RENAME_PROFILE", PRO.currentProfileName, nil, PRO.currentProfileName)
		end,
		"Rename the current profile.", addSearchTags))

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
		Settings.VarType.String, "Copy From", "",
		function() return "" end,
		function(name)
			if name ~= "" then
				PRO.CopyProfile(name)
			end
		end)
	Settings.CreateDropdown(category, copySetting, GetCopyOptions,
		"Copy all settings from another profile into the current one.")

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"", "Export Profile",
		function() StaticPopup_Show("PRO_EXPORT_PROFILE") end,
		"Export the current profile as a shareable string.", addSearchTags))

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"", "Import Profile",
		function() StaticPopup_Show("PRO_IMPORT_PROFILE") end,
		"Import a profile from a shared string.", addSearchTags))

	-- ═════════════════════════════════════════════════════════════════════
	-- Display
	-- ═════════════════════════════════════════════════════════════════════

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Display"))

	local enableDisplayInitializer = AddCheckbox(
		"PRO_enableDisplay", "enableDisplay",
		"Show Display", "Show or hide the entire Personal Resource Display.",
		true, nil, nil)

	local function IsDisplayEnabled() return db.enableDisplay end

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
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Alternate Power Bar Text"))

		local altPowerEnableInit = AddTextSection("altPower", "Alt Power ", "Show Alternate Power Value",
			"Display the current value on the alternate power bar.",
			14, enableAltPowerBarInitializer,
			function() return db.enableDisplay and db.enableAltPowerBar end)

		AddSlider(
			"PRO_altPowerTextDecimals", "altPowerTextDecimals",
			"Alt Power Decimal Places",
			"Decimal places shown (0 = integer, 1 = one decimal, 2 = two). Evoker Ebon Might benefits from 1; DH Soul Fragments and Monk Stagger are always whole numbers.",
			1, 0, 2, 1,
			altPowerEnableInit,
			function() return db.enableDisplay and db.enableAltPowerBar and db.enableAltPowerText end)
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
