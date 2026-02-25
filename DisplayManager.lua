-- PersonalResourceOptions - DisplayManager.lua
-- Mixin that orchestrates overlay initialization, hook installation,
-- and the composite ApplySettings pass across all overlays.

local _, PRO = ...

PRO.DisplayManagerMixin = {}

--- Initialize all text overlays and install PRD hooks.
--- Must be called at PLAYER_LOGIN when PersonalResourceDisplayFrame exists.
--- @param db table The flat settings table.
--- @param hasAltPowerBar boolean Whether the class has an alt power bar.
--- @param hasClassFrame boolean Whether the class has a class resource frame.
function PRO.DisplayManagerMixin:Init(db, hasAltPowerBar, hasClassFrame)
	self.hasAltPowerBar = hasAltPowerBar
	self.hasClassFrame  = hasClassFrame

	local prd = PersonalResourceDisplayFrame
	if not prd then return end

	-- Create overlay instances
	self.healthOverlay      = CreateFromMixins(PRO.HealthTextOverlayMixin)
	self.powerOverlay       = CreateFromMixins(PRO.PowerTextOverlayMixin)
	self.altPowerOverlay    = CreateFromMixins(PRO.AltPowerTextOverlayMixin)
	self.runeCooldownOverlay = CreateFromMixins(PRO.RuneCooldownOverlayMixin)

	-- Initialize overlays that have valid parent bars
	local healthBar = prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar
	if healthBar then
		self.healthOverlay:Init(healthBar)
	end
	if prd.PowerBar then
		self.powerOverlay:Init(prd.PowerBar)
	end
	if prd.AlternatePowerBar then
		self.altPowerOverlay:Init(prd.AlternatePowerBar)
	end

	-- DK rune cooldown FontStrings
	if select(3, UnitClass("player")) == Constants.UICharacterClasses.DeathKnight
		and prdClassFrame and prdClassFrame.Runes then
		self.runeCooldownOverlay:Init(prdClassFrame)
	end

	-- Install PRD OnShow hook
	self:InstallHooks(prd, db)
end

--- Install HookScript handlers on the PRD and child bars.
--- @param prd Frame PersonalResourceDisplayFrame.
--- @param db table The flat settings table.
function PRO.DisplayManagerMixin:InstallHooks(prd, db)
	local mgr = self

	prd:HookScript("OnShow", function()
		if not db.enableDisplay then
			prd:Hide()
			return
		end
		if prd.HealthBarsContainer and not db.enableHealthBar then
			prd.HealthBarsContainer:Hide()
		end
		if prd.PowerBar and not db.enablePowerBar then
			prd.PowerBar:Hide()
		end
		if prd.AlternatePowerBar and (not mgr.hasAltPowerBar or not db.enableAltPowerBar) then
			prd.AlternatePowerBar:Hide()
		end
		if mgr.hasClassFrame and prdClassFrame then
			prdClassFrame:SetShown(db.enableClassFrame)
			if db.enableClassFrame then
				mgr:ApplyClassFrameLayout(db)
			end
		end
	end)

	if prd.HealthBarsContainer then
		prd.HealthBarsContainer:HookScript("OnShow", function()
			if not db.enableDisplay or not db.enableHealthBar then
				prd.HealthBarsContainer:Hide()
			end
		end)
	end
	if prd.PowerBar then
		prd.PowerBar:HookScript("OnShow", function()
			if not db.enableDisplay or not db.enablePowerBar then
				prd.PowerBar:Hide()
			end
		end)
	end
	if prd.AlternatePowerBar then
		prd.AlternatePowerBar:HookScript("OnShow", function()
			if not db.enableDisplay or not db.enableAltPowerBar then
				prd.AlternatePowerBar:Hide()
			end
		end)
	end
	if mgr.hasClassFrame and prdClassFrame then
		prdClassFrame:HookScript("OnShow", function()
			if db.enableDisplay and db.enableClassFrame then
				mgr:ApplyClassFrameLayout(db)
			end
		end)
	end
end

--- Apply scale and offset to prdClassFrame.
--- @param db table The flat settings table.
function PRO.DisplayManagerMixin:ApplyClassFrameLayout(db)
	if not prdClassFrame or not PersonalResourceDisplayFrame.ClassFrameContainer then return end
	prdClassFrame:SetScale(db.classFrameScale / 100)
	prdClassFrame:ClearAllPoints()
	prdClassFrame:SetPoint("CENTER",
		PersonalResourceDisplayFrame.ClassFrameContainer, "CENTER",
		db.classFrameOffsetX, db.classFrameOffsetY)
end

--- Master ApplySettings — delegates to each overlay's :Apply() method.
--- @param db table The flat settings table.
function PRO.DisplayManagerMixin:ApplySettings(db)
	local prd = PersonalResourceDisplayFrame
	if not prd then return end

	-- Display master toggle
	if not db.enableDisplay then
		prd:Hide()
	else
		prd:UpdateShownState()
	end

	-- Child bar visibility
	if prd.HealthBarsContainer then
		prd.HealthBarsContainer:SetShown(db.enableHealthBar)
	end
	if prd.PowerBar then
		prd.PowerBar:SetShown(db.enablePowerBar)
	end
	if prd.AlternatePowerBar then
		prd.AlternatePowerBar:SetShown(self.hasAltPowerBar and db.enableAltPowerBar)
	end
	prd:SetScale(db.displayScale / 100)

	-- Class frame
	if prdClassFrame then
		if db.enableClassFrame then
			prdClassFrame:Show()
			self:ApplyClassFrameLayout(db)
		elseif prdClassFrame:IsVisible() then
			prdClassFrame:Hide()
		end
	end

	-- Delegate to each overlay
	local healthBar = prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar
	if healthBar then
		self.healthOverlay:Apply(db, healthBar)
	end
	if prd.PowerBar then
		self.powerOverlay:Apply(db, prd.PowerBar)
	end

	self.altPowerOverlay:Apply(db, self.hasAltPowerBar)

	if self.runeCooldownOverlay:IsCreated() then
		self.runeCooldownOverlay:Apply(db, prdClassFrame)
	end
end
