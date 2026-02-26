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

--- Return pixel offsets that compensate for outline thickness.
--- Outline and thick-outline glyphs shift the visual centre of small
--- texts; these nudge values re-centre them on the parent widget.
--- @param outline string "NONE"|"OUTLINE"|"THICKOUTLINE"
--- @return number offsetX
--- @return number offsetY
function PRO.GetOutlineOffsets(outline)
	if outline == "THICKOUTLINE" then
		return 0.6, -0.4
	elseif outline == "OUTLINE" then
		return 0.4, 0
	end
	return 0, 0
end
