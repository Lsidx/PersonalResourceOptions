-- PersonalResourceOptions - PowerTextOverlay.lua
-- Mixin for the power bar text overlay.
-- Extends TextOverlayMixin with UNIT_POWER_FREQUENT / UNIT_DISPLAYPOWER event handling.

local _, PRO = ...

local UnitPower         = UnitPower
local AbbreviateNumbers = AbbreviateNumbers

PRO.PowerTextOverlayMixin = CreateFromMixins(PRO.TextOverlayMixin)

--- Create the FontString on the power bar.
--- @param powerBar Frame The power bar widget.
function PRO.PowerTextOverlayMixin:Init(powerBar)
	PRO.TextOverlayMixin.Init(self, powerBar, "OVERLAY")
	self.eventFrame:SetScript("OnEvent", function()
		self.fontString:SetText(AbbreviateNumbers(UnitPower("player")))
	end)
end

--- Apply power text settings from the flat db.
--- @param db table Flat settings table.
--- @param powerBar Frame The power bar widget.
function PRO.PowerTextOverlayMixin:Apply(db, powerBar)
	if not self:IsCreated() then return end

	if not db.enablePowerText then
		self.eventFrame:UnregisterEvent("UNIT_POWER_FREQUENT")
		self.eventFrame:UnregisterEvent("UNIT_DISPLAYPOWER")
		self:Hide()
		return
	end

	self:ApplyFont(db.powerTextFont, db.powerTextSize,
		db.powerTextOutline, db.powerTextMono, db.powerTextColor)
	self:SetAnchor(db.powerTextAnchor, powerBar)
	self:Show()
	self.eventFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	self.eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	self.fontString:SetText(AbbreviateNumbers(UnitPower("player")))
end
