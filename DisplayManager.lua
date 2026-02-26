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

	-- All hooks guard against InCombatLockdown() because the PRD frames
	-- are protected nameplate children; Show/Hide/SetShown would be
	-- blocked (and spread taint) if called from insecure addon code
	-- while the player is in combat.

	prd:HookScript("OnShow", function()
		if InCombatLockdown() then return end
		if prd.HealthBarsContainer and not db.enableHealthBar then
			prd.HealthBarsContainer:Hide()
		end
		if prd.PowerBar and not db.enablePowerBar then
			prd.PowerBar:Hide()
		end
		if prd.AlternatePowerBar
				and (not mgr.hasAltPowerBar or not db.enableAltPowerBar
					or not prd.AlternatePowerBar.alternatePowerRequirementsMet) then
			prd.AlternatePowerBar:Hide()
		end
		if mgr.hasClassFrame and prdClassFrame then
			if not db.enableClassFrame then
				prdClassFrame:Hide()
			elseif prdClassFrame:IsShown() then
				mgr:ApplyClassFrameLayout(db)
			end
		end
	end)

	if prd.HealthBarsContainer then
		prd.HealthBarsContainer:HookScript("OnShow", function()
			if InCombatLockdown() then return end
			if not db.enableHealthBar then
				prd.HealthBarsContainer:Hide()
			end
		end)
	end
	if prd.PowerBar then
		prd.PowerBar:HookScript("OnShow", function()
			if InCombatLockdown() then return end
			if not db.enablePowerBar then
				prd.PowerBar:Hide()
			end
		end)
	end
	if prd.AlternatePowerBar then
		prd.AlternatePowerBar:HookScript("OnShow", function()
			if InCombatLockdown() then return end
			if not db.enableAltPowerBar then
				prd.AlternatePowerBar:Hide()
			end
		end)
	end
	if mgr.hasClassFrame and prdClassFrame then
		prdClassFrame:HookScript("OnShow", function()
			if InCombatLockdown() then return end
			if not db.enableClassFrame then
				prdClassFrame:Hide()
			else
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

	-- Protected nameplate frames cannot be modified in combat.
	-- Defer the entire pass to after combat ends.
	if InCombatLockdown() then
		local f = self._regenFrame
		if not f then
			f = CreateFrame("Frame")
			self._regenFrame = f
			local mgr = self
			f:SetScript("OnEvent", function(frame)
				frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
				if frame._pendingDb then
					mgr:ApplySettings(frame._pendingDb)
					frame._pendingDb = nil
				end
			end)
		end
		f._pendingDb = db
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	-- Display master toggle — only write the CVar in override mode.
	-- In sync mode (override off), the CVar is owned by Blizzard's
	-- Combat settings, and we merely read it.
	if db.overrideDisplay then
		local wantEnabled = db.enableDisplay and "1" or "0"
		if C_CVar.GetCVar(PRO.PRD_ENABLED_CVAR) ~= wantEnabled then
			C_CVar.SetCVar(PRO.PRD_ENABLED_CVAR, wantEnabled)
		end
	end

	-- Child bar visibility
	if prd.HealthBarsContainer then
		prd.HealthBarsContainer:SetShown(db.enableHealthBar)
	end
	if prd.PowerBar then
		prd.PowerBar:SetShown(db.enablePowerBar)
	end

	-- Alternate power bar — spec-dependent (e.g. Monk Stagger is Brewmaster
	-- only). Blizzard sets alternatePowerRequirementsMet via EvaluateUnit();
	-- we only Show() when the current spec actually uses this bar.
	if prd.AlternatePowerBar then
		local specUsesAltPower = self.hasAltPowerBar
			and prd.AlternatePowerBar.alternatePowerRequirementsMet
		if specUsesAltPower and db.enableAltPowerBar then
			prd.AlternatePowerBar:Show()
		else
			prd.AlternatePowerBar:Hide()
		end
	end

	prd:SetScale(db.displayScale / 100)

	-- Class frame — spec-dependent (e.g. Monk Chi is Windwalker only).
	-- Don't force-show; Blizzard's ClassResourceBarMixin:Setup() manages
	-- spec-based visibility. We only hide when the user has disabled it,
	-- and apply layout if it's already visible on the correct spec.
	if prdClassFrame then
		if db.enableClassFrame then
			if prdClassFrame:IsShown() then
				self:ApplyClassFrameLayout(db)
			end
		else
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

	-- Pass spec-aware flag so the overlay doesn't run OnUpdate on wrong specs
	local altPowerActive = self.hasAltPowerBar
		and prd.AlternatePowerBar
		and prd.AlternatePowerBar.alternatePowerRequirementsMet
	self.altPowerOverlay:Apply(db, altPowerActive)

	if self.runeCooldownOverlay:IsCreated() then
		self.runeCooldownOverlay:Apply(db, prdClassFrame)
	end
end
