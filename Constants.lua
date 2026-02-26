-- PersonalResourceOptions - Constants.lua
-- Shared constants, default values, and lookup tables.

local ADDON_NAME, PRO = ...

PRO.ADDON_NAME = ADDON_NAME
PRO.PRD_ENABLED_CVAR = "nameplateShowSelf"
PRO.FONT_DEFAULT = "Interface\\AddOns\\PersonalResourceOptions\\Assets\\EXPRESSWAY.TTF"

-- ---------------------------------------------------------------------------
-- Default settings values
-- ---------------------------------------------------------------------------

local FONT_DEFAULT = PRO.FONT_DEFAULT

PRO.DEFAULTS = {
	enableDisplay             = true,
	overrideDisplay           = false,
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
	healthTextFont            = FONT_DEFAULT,
	healthTextSize            = 14,
	healthTextOutline         = "THICKOUTLINE",
	healthTextMono            = false,
	healthTextColor           = "ffffffff",
	enablePowerText           = true,
	powerTextAnchor           = "CENTER",
	powerTextFont             = FONT_DEFAULT,
	powerTextSize             = 14,
	powerTextOutline          = "THICKOUTLINE",
	powerTextMono             = false,
	powerTextColor            = "ffffffff",
	enableAltPowerText        = true,
	altPowerTextAnchor        = "CENTER",
	altPowerTextFont          = FONT_DEFAULT,
	altPowerTextSize          = 14,
	altPowerTextOutline       = "THICKOUTLINE",
	altPowerTextMono          = false,
	altPowerTextColor         = "ffffffff",
	altPowerTextDecimals      = 1,
	enableRuneCooldownText    = true,
	runeCooldownTextAnchor    = "CENTER",
	runeCooldownTextFont      = FONT_DEFAULT,
	runeCooldownTextSize      = 12,
	runeCooldownTextOutline   = "THICKOUTLINE",
	runeCooldownTextMono      = false,
	runeCooldownTextColor     = "ffffffff",
}

-- ---------------------------------------------------------------------------
-- Class-specific settings keys (stored per classID within a profile)
-- ---------------------------------------------------------------------------

PRO.CLASS_SPECIFIC_KEYS = {
	"classFrameScale",
	"classFrameOffsetX",
	"classFrameOffsetY",
	"enableRuneCooldownText",
	"runeCooldownTextAnchor",
	"runeCooldownTextFont",
	"runeCooldownTextSize",
	"runeCooldownTextOutline",
	"runeCooldownTextMono",
	"runeCooldownTextColor",
}

PRO.IS_CLASS_SPECIFIC = {}
for _, key in ipairs(PRO.CLASS_SPECIFIC_KEYS) do
	PRO.IS_CLASS_SPECIFIC[key] = true
end

-- ---------------------------------------------------------------------------
-- Alternate power bar decimal options for AbbreviateNumbers
-- ---------------------------------------------------------------------------

PRO.ALT_POWER_OPTIONS = {
	[0] = { breakpointData = { { breakpoint = 0, abbreviation = "", abbreviationIsGlobal = false, significandDivisor = 1,    fractionDivisor = 1   } } },
	[1] = { breakpointData = { { breakpoint = 0, abbreviation = "", abbreviationIsGlobal = false, significandDivisor = 0.1,  fractionDivisor = 10  } } },
	[2] = { breakpointData = { { breakpoint = 0, abbreviation = "", abbreviationIsGlobal = false, significandDivisor = 0.01, fractionDivisor = 100 } } },
}
