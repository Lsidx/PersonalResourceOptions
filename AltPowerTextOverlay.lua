-- PersonalResourceOptions - AltPowerTextOverlay.lua
-- Mixin for the alternate power bar text overlay.
-- Extends TextOverlayMixin with OnUpdate-driven value reading.
-- Only active for DH (Soul Fragments), Evoker (Ebon Might), Monk (Stagger).

local _, PRO = ...

local AbbreviateNumbers = AbbreviateNumbers

PRO.AltPowerTextOverlayMixin = CreateFromMixins(PRO.TextOverlayMixin)

--- Create the FontString on the alternate power bar.
--- @param altPowerBar Frame The alternate power bar widget.
function PRO.AltPowerTextOverlayMixin:Init(altPowerBar)
	PRO.TextOverlayMixin.Init(self, altPowerBar, "OVERLAY")
	self.altPowerBar = altPowerBar
	self.altPowerOptions = PRO.ALT_POWER_OPTIONS[1]
end

--- Apply alternate power text settings from the flat db.
--- @param db table Flat settings table.
--- @param hasAltPowerBar boolean Whether the class has an alt power bar.
function PRO.AltPowerTextOverlayMixin:Apply(db, hasAltPowerBar)
	if not self:IsCreated() then return end

	if not hasAltPowerBar or not db.enableAltPowerText then
		self.eventFrame:SetScript("OnUpdate", nil)
		self:Hide()
		return
	end

	self:ApplyFont(db.altPowerTextFont, db.altPowerTextSize,
		db.altPowerTextOutline, db.altPowerTextMono, db.altPowerTextColor)
	self:SetAnchor(db.altPowerTextAnchor, self.altPowerBar)
	self:Show()
	self.altPowerOptions = PRO.ALT_POWER_OPTIONS[db.altPowerTextDecimals or 1]

	local overlay = self
	self.eventFrame:SetScript("OnUpdate", function()
		overlay.fontString:SetText(AbbreviateNumbers(
			overlay.altPowerBar:GetValue(), overlay.altPowerOptions))
	end)
end
