-- PersonalResourceOptions - RuneCooldownOverlay.lua
-- Mixin for Death Knight rune cooldown text overlays.
-- Extends TextOverlayMixin with per-rune FontStrings and OnUpdate-driven
-- cooldown display.

local _, PRO = ...

local GetRuneCooldown = GetRuneCooldown
local GetTime         = GetTime
local ceil            = math.ceil

PRO.RuneCooldownOverlayMixin = {}

--- Create FontStrings for each rune on the class frame.
--- @param prdClassFrame Frame The class resource frame with a .Runes table.
function PRO.RuneCooldownOverlayMixin:Init(prdClassFrame)
	self.runeTexts = {}
	self.eventFrame = CreateFrame("Frame")
	for i = 1, 6 do
		local rune = prdClassFrame.Runes and prdClassFrame.Runes[i]
		if rune then
			self.runeTexts[i] = rune:CreateFontString(nil, "OVERLAY")
		end
	end

	local overlay = self
	self.onUpdate = function()
		for i = 1, 6 do
			local t = overlay.runeTexts[i]
			if t then
				local start, duration, runeReady = GetRuneCooldown(i)
				if runeReady or not start then
					t:SetText("")
				else
					t:SetText(ceil(start + duration - GetTime()))
				end
			end
		end
	end
end

--- Check whether the overlay has been initialized.
--- @return boolean
function PRO.RuneCooldownOverlayMixin:IsCreated()
	return self.runeTexts and self.runeTexts[1] ~= nil
end

--- Apply rune cooldown text settings from the flat db.
--- @param db table Flat settings table.
--- @param prdClassFrame Frame The class resource frame.
function PRO.RuneCooldownOverlayMixin:Apply(db, prdClassFrame)
	if not self:IsCreated() then return end

	if not db.enableRuneCooldownText then
		self.eventFrame:SetScript("OnUpdate", nil)
		for i = 1, 6 do
			if self.runeTexts[i] then self.runeTexts[i]:Hide() end
		end
		return
	end

	local flags = PRO.BuildFontFlags(db.runeCooldownTextOutline, db.runeCooldownTextMono)
	local runeOffX, runeOffY = 0, 0
	if db.runeCooldownTextOutline == "THICKOUTLINE" then
		runeOffX, runeOffY = 0.6, -0.4
	elseif db.runeCooldownTextOutline == "OUTLINE" then
		runeOffX, runeOffY = 0.4, 0
	end
	local rColor = CreateColorFromHexString(db.runeCooldownTextColor)

	for i = 1, 6 do
		local t = self.runeTexts[i]
		if t then
			t:SetFont(db.runeCooldownTextFont, db.runeCooldownTextSize, flags)
			t:SetTextColor(rColor:GetRGBA())
			local rune = prdClassFrame.Runes and prdClassFrame.Runes[i]
			if rune then
				t:ClearAllPoints()
				t:SetPoint(db.runeCooldownTextAnchor, rune, db.runeCooldownTextAnchor, runeOffX, runeOffY)
			end
			t:Show()
		end
	end
	self.eventFrame:SetScript("OnUpdate", self.onUpdate)
end
