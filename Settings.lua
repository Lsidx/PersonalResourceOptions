-- PersonalResourceOptions - Settings.lua
-- Registers addon settings with the Blizzard Settings panel.
-- PRO.RegisterSettings is called once from Core.lua after ADDON_LOADED.

local _, PRO = ...

local CATEGORY_NAME = "Personal Resource Options"

local FONT_DEFAULT = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF"

local ANCHOR_OPTIONS = {
	{ value = "TOPLEFT",     label = "Top Left"     },
	{ value = "TOP",         label = "Top"          },
	{ value = "TOPRIGHT",    label = "Top Right"    },
	{ value = "LEFT",        label = "Left"         },
	{ value = "CENTER",      label = "Center"       },
	{ value = "RIGHT",       label = "Right"        },
	{ value = "BOTTOMLEFT",  label = "Bottom Left"  },
	{ value = "BOTTOM",      label = "Bottom"       },
	{ value = "BOTTOMRIGHT", label = "Bottom Right" },
}

local FONT_OPTIONS = {
	{ value = FONT_DEFAULT,          label = "Expressway"    },
	{ value = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata" },
	{ value = "Fonts\\ARIALN.TTF",   label = "Arial Narrow"  },
	{ value = "Fonts\\MORPHEUS.TTF", label = "Morpheus"      },
	{ value = "Fonts\\SKURRI.TTF",   label = "Skurri"        },
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
