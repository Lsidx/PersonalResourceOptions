-- PersonalResourceOptions - HealthTextOverlay.lua
-- Mixin for the health bar text overlay.
-- Extends TextOverlayMixin with UNIT_HEALTH event handling.

local _, PRO = ...

local UnitHealth        = UnitHealth
local AbbreviateNumbers = AbbreviateNumbers

PRO.HealthTextOverlayMixin = CreateFromMixins(PRO.TextOverlayMixin)

--- Create the FontString on the health bar.
--- @param healthBar Frame The health bar widget.
function PRO.HealthTextOverlayMixin:Init(healthBar)
	PRO.TextOverlayMixin.Init(self, healthBar, "OVERLAY")
	self.eventFrame:SetScript("OnEvent", function()
		self.fontString:SetText(AbbreviateNumbers(UnitHealth("player")))
	end)
end

--- Apply health text settings from the flat db.
--- @param db table Flat settings table.
--- @param healthBar Frame The health bar widget.
function PRO.HealthTextOverlayMixin:Apply(db, healthBar)
	if not self:IsCreated() then return end

	if not db.enableHealthText then
		self.eventFrame:UnregisterEvent("UNIT_HEALTH")
		self:Hide()
		return
	end

	self:ApplyFont(db.healthTextFont, db.healthTextSize,
		db.healthTextOutline, db.healthTextMono, db.healthTextColor)
	self:SetAnchor(db.healthTextAnchor, healthBar)
	self:Show()
	self.eventFrame:RegisterUnitEvent("UNIT_HEALTH", "player")
	self.fontString:SetText(AbbreviateNumbers(UnitHealth("player")))
end
