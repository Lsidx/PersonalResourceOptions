-- PersonalResourceOptions - TextOverlayMixin.lua
-- Base mixin for text overlays on Personal Resource Display bars.
-- Provides shared font, anchor, color, and show/hide logic.
-- Derived mixins: HealthTextOverlayMixin, PowerTextOverlayMixin,
--                 AltPowerTextOverlayMixin, RuneCooldownOverlayMixin

local _, PRO = ...

PRO.TextOverlayMixin = {}

--- Initialize the overlay. Creates the FontString and an invisible event frame.
--- @param parent Frame The bar frame to parent the FontString to.
--- @param layer string|nil DrawLayer (default "OVERLAY").
function PRO.TextOverlayMixin:Init(parent, layer)
	self.fontString = parent:CreateFontString(nil, layer or "OVERLAY")
	self.eventFrame = CreateFrame("Frame")
end

--- Apply font, outline, monochrome, and color to the FontString.
--- @param font string Font path.
--- @param size number Font size in points.
--- @param outline string "NONE"|"OUTLINE"|"THICKOUTLINE"
--- @param mono boolean Monochrome flag.
--- @param colorHex string 8-char ARGB hex (e.g. "ffffffff").
function PRO.TextOverlayMixin:ApplyFont(font, size, outline, mono, colorHex)
	local flags = PRO.BuildFontFlags(outline, mono)
	self.fontString:SetFont(font, size, flags)
	self.fontString:SetTextColor(CreateColorFromHexString(colorHex):GetRGBA())
end

--- Anchor the FontString to a bar.
--- @param anchor string Anchor point (e.g. "CENTER", "LEFT", "RIGHT").
--- @param bar Frame The bar frame to anchor to.
--- @param offsetX number|nil X offset (default 0).
--- @param offsetY number|nil Y offset (default 0).
function PRO.TextOverlayMixin:SetAnchor(anchor, bar, offsetX, offsetY)
	self.fontString:ClearAllPoints()
	self.fontString:SetPoint(anchor, bar, anchor, offsetX or 0, offsetY or 0)
end

--- Show the FontString.
function PRO.TextOverlayMixin:Show()
	self.fontString:Show()
end

--- Hide the FontString.
function PRO.TextOverlayMixin:Hide()
	self.fontString:Hide()
end

--- Check whether the FontString has been created.
--- @return boolean
function PRO.TextOverlayMixin:IsCreated()
	return self.fontString ~= nil
end
