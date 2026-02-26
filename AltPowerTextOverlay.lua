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
--- @param altPowerActive boolean Whether the alt power bar is active for the current spec.
function PRO.AltPowerTextOverlayMixin:Apply(db, altPowerActive)
	if not self:IsCreated() then return end

	if not altPowerActive or not db.enableAltPowerText then
		self.eventFrame:SetScript("OnUpdate", nil)
		self:Hide()
		return
	end

	self:ApplyFont(db.altPowerTextFont, db.altPowerTextSize,
		db.altPowerTextOutline, db.altPowerTextMono, db.altPowerTextColor)
	self:SetAnchor(db.altPowerTextAnchor, self.altPowerBar, db.altPowerTextOutline)
	self:Show()
	self.altPowerOptions = PRO.ALT_POWER_OPTIONS[db.altPowerTextDecimals or 1]

	local overlay = self
	self.eventFrame:SetScript("OnUpdate", function()
		overlay.fontString:SetText(AbbreviateNumbers(
			overlay.altPowerBar:GetValue(), overlay.altPowerOptions))
	end)
end
