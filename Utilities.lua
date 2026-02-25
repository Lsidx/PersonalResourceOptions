-- PersonalResourceOptions - Utilities.lua
-- Shared helper functions used across modules.

local _, PRO = ...

--- Build the font flags string from outline and monochrome settings.
--- @param outline string "NONE"|"OUTLINE"|"THICKOUTLINE"
--- @param mono boolean
--- @return string
function PRO.BuildFontFlags(outline, mono)
	local flags = (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or ""
	if mono then
		flags = (flags == "") and "MONOCHROME" or (flags .. ",MONOCHROME")
	end
	return flags
end
