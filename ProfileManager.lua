-- PersonalResourceOptions - ProfileManager.lua
-- Mixin for profile CRUD, migration, import/export, and data flattening.
-- Manages PersonalResourceOptionsDB and the flat db table used by Settings API.

local _, PRO = ...

local DEFAULTS          = PRO.DEFAULTS
local CLASS_SPECIFIC_KEYS = PRO.CLASS_SPECIFIC_KEYS
local IS_CLASS_SPECIFIC = PRO.IS_CLASS_SPECIFIC

PRO.ProfileManagerMixin = {}

-- ---------------------------------------------------------------------------
-- Data helpers
-- ---------------------------------------------------------------------------

--- Build a flat settings table from a profile, overlaying class-specific values.
--- @param profile table The profile sub-table from savedDB.profiles.
--- @param classID number The player's classID.
--- @return table flat The merged flat table.
function PRO.ProfileManagerMixin:FlattenProfile(profile, classID)
	local flat = {}
	for k, v in pairs(profile) do
		if k ~= "classSettings" then
			flat[k] = v
		end
	end
	local cs = profile.classSettings and profile.classSettings[classID]
	if cs then
		for _, key in ipairs(CLASS_SPECIFIC_KEYS) do
			if cs[key] ~= nil then
				flat[key] = cs[key]
			end
		end
	end
	for key, default in pairs(DEFAULTS) do
		if flat[key] == nil then
			flat[key] = default
		end
	end
	return flat
end

--- Write the flat db table back into a profile, separating class-specific keys.
--- @param db table The flat settings table.
--- @param profile table The profile sub-table from savedDB.profiles.
--- @param classID number The player's classID.
function PRO.ProfileManagerMixin:UnflattenToProfile(db, profile, classID)
	for k, v in pairs(db) do
		if not IS_CLASS_SPECIFIC[k] then
			profile[k] = v
		end
	end
	if not profile.classSettings then
		profile.classSettings = {}
	end
	if not profile.classSettings[classID] then
		profile.classSettings[classID] = {}
	end
	local cs = profile.classSettings[classID]
	for _, key in ipairs(CLASS_SPECIFIC_KEYS) do
		cs[key] = db[key]
	end
end

--- Get the character identity key (Name-NormalizedRealm).
--- @return string
function PRO.ProfileManagerMixin:GetCharacterKey()
	local name = UnitName("player")
	local realm = GetNormalizedRealmName()
	return name .. "-" .. (realm or "")
end

--- Resolve which profile name the current character should use.
--- @param savedDB table The top-level saved variable table.
--- @param charKey string The character key.
--- @return string profileName
function PRO.ProfileManagerMixin:ResolveProfileName(savedDB, charKey)
	local name = savedDB.characterProfiles and savedDB.characterProfiles[charKey]
	if name and savedDB.profiles[name] then
		return name
	end
	return "Default"
end

-- ---------------------------------------------------------------------------
-- Migration
-- ---------------------------------------------------------------------------

--- Migrate flat v1 DB to v2 profile structure.
--- @param savedDB table The top-level saved variable table.
--- @param classID number The player's classID.
function PRO.ProfileManagerMixin:MigrateToV2(savedDB, classID)
	local profile = {}
	local classSettings = {}
	for k, v in pairs(savedDB) do
		if IS_CLASS_SPECIFIC[k] then
			classSettings[k] = v
		elseif k ~= "schemaVersion" then
			profile[k] = v
		end
	end
	if next(classSettings) then
		profile.classSettings = { [classID] = classSettings }
	end
	wipe(savedDB)
	savedDB.schemaVersion = 2
	savedDB.profiles = { ["Default"] = profile }
	savedDB.characterProfiles = {}
end

--- Migrate outline booleans to string enum (v2 -> v3).
--- @param savedDB table The top-level saved variable table.
function PRO.ProfileManagerMixin:MigrateToV3(savedDB)
	local OUTLINE_PREFIXES = { "healthText", "powerText", "altPowerText", "runeCooldownText" }
	for _, profile in pairs(savedDB.profiles) do
		for _, pfx in ipairs(OUTLINE_PREFIXES) do
			local oKey, tKey = pfx .. "Outline", pfx .. "ThickOutline"
			if type(profile[oKey]) == "boolean" or type(profile[tKey]) == "boolean" then
				if profile[tKey] then
					profile[oKey] = "THICKOUTLINE"
				elseif profile[oKey] then
					profile[oKey] = "OUTLINE"
				else
					profile[oKey] = "NONE"
				end
				profile[tKey] = nil
			end
		end
		if profile.classSettings then
			for _, cs in pairs(profile.classSettings) do
				for _, pfx in ipairs(OUTLINE_PREFIXES) do
					local oKey, tKey = pfx .. "Outline", pfx .. "ThickOutline"
					if type(cs[oKey]) == "boolean" or type(cs[tKey]) == "boolean" then
						if cs[tKey] then
							cs[oKey] = "THICKOUTLINE"
						elseif cs[oKey] then
							cs[oKey] = "OUTLINE"
						else
							cs[oKey] = "NONE"
						end
						cs[tKey] = nil
					end
				end
			end
		end
	end
	savedDB.schemaVersion = 3
end

-- ---------------------------------------------------------------------------
-- Initialization (called from Core.lua at ADDON_LOADED)
-- ---------------------------------------------------------------------------

--- Initialize the profile system: run migrations, resolve profile, build flat db.
--- @param savedDB table The top-level saved variable (PersonalResourceOptionsDB).
--- @param classID number The player's classID.
--- @return table db The flat settings table (identity preserved across switches).
--- @return string profileName The resolved profile name.
--- @return table profile The resolved profile sub-table.
--- @return string charKey The character key.
function PRO.ProfileManagerMixin:Initialize(savedDB, classID)
	-- Migrate flat DB (v1) to profile structure (v2)
	if not savedDB.schemaVersion or savedDB.schemaVersion < 2 then
		self:MigrateToV2(savedDB, classID)
	end

	-- Migrate outline booleans to string enum (v2 -> v3)
	if savedDB.schemaVersion < 3 then
		self:MigrateToV3(savedDB)
	end

	-- Ensure structure exists
	if not savedDB.profiles then savedDB.profiles = {} end
	if not savedDB.profiles["Default"] then savedDB.profiles["Default"] = {} end
	if not savedDB.characterProfiles then savedDB.characterProfiles = {} end

	local charKey = self:GetCharacterKey()
	local profileName = self:ResolveProfileName(savedDB, charKey)
	local profile = savedDB.profiles[profileName]

	-- Build flat db for Settings API (preserving table identity across switches)
	local db = {}
	local flat = self:FlattenProfile(profile, classID)
	for k, v in pairs(flat) do
		db[k] = v
	end

	-- Store references on PRO for cross-module access
	PRO.savedDB = savedDB
	PRO.db = db
	PRO.classID = classID
	PRO.charKey = charKey
	PRO.currentProfileName = profileName
	PRO.currentProfile = profile

	return db, profileName, profile, charKey
end

-- ---------------------------------------------------------------------------
-- Profile CRUD
-- ---------------------------------------------------------------------------

--- Switch the current character to a different profile.
--- @param name string The target profile name.
--- @param applyCallback function|nil Optional callback to call after switching.
function PRO.ProfileManagerMixin:SwitchProfile(name, applyCallback)
	if not PRO.savedDB.profiles[name] then return end
	self:UnflattenToProfile(PRO.db, PRO.currentProfile, PRO.classID)
	PRO.savedDB.characterProfiles[PRO.charKey] = name
	PRO.currentProfileName = name
	PRO.currentProfile = PRO.savedDB.profiles[name]
	wipe(PRO.db)
	local flat = self:FlattenProfile(PRO.currentProfile, PRO.classID)
	for k, v in pairs(flat) do
		PRO.db[k] = v
	end
	if applyCallback then
		applyCallback(PRO.db)
	end
end

--- Create a new profile with default values.
--- @param name string The new profile name.
--- @return boolean success
function PRO.ProfileManagerMixin:CreateProfile(name)
	if not name or name == "" or PRO.savedDB.profiles[name] then return false end
	PRO.savedDB.profiles[name] = {}
	return true
end

--- Delete a profile (Default cannot be deleted).
--- @param name string The profile to delete.
--- @return boolean success
function PRO.ProfileManagerMixin:DeleteProfile(name)
	if name == "Default" or not PRO.savedDB.profiles[name] then return false end
	PRO.savedDB.profiles[name] = nil
	for charKey, pName in pairs(PRO.savedDB.characterProfiles) do
		if pName == name then
			PRO.savedDB.characterProfiles[charKey] = nil
		end
	end
	if PRO.currentProfileName == name then
		self:SwitchProfile("Default")
	end
	return true
end

--- Copy all settings from a source profile into the current profile.
--- @param sourceName string The source profile name.
--- @param applyCallback function|nil Optional callback to call after copying.
--- @return boolean success
function PRO.ProfileManagerMixin:CopyProfile(sourceName, applyCallback)
	local source = PRO.savedDB.profiles[sourceName]
	if not source then return false end
	local copy = CopyTable(source)
	wipe(PRO.currentProfile)
	for k, v in pairs(copy) do
		PRO.currentProfile[k] = v
	end
	wipe(PRO.db)
	local flat = self:FlattenProfile(PRO.currentProfile, PRO.classID)
	for k, v in pairs(flat) do
		PRO.db[k] = v
	end
	if applyCallback then
		applyCallback(PRO.db)
	end
	return true
end

--- Return a sorted list of all profile names.
--- @return table names
function PRO.ProfileManagerMixin:GetProfileNames()
	local names = {}
	for name in pairs(PRO.savedDB.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

--- Export the current profile as a Base64-encoded string.
--- @return string encoded
function PRO.ProfileManagerMixin:ExportProfile()
	self:UnflattenToProfile(PRO.db, PRO.currentProfile, PRO.classID)
	local data = CopyTable(PRO.currentProfile)
	local ok, result = pcall(function()
		return C_EncodingUtil.EncodeBase64(C_EncodingUtil.SerializeCBOR(data))
	end)
	if ok then
		return result
	else
		print("|cffff6666PRO:|r Export failed: " .. tostring(result))
		return ""
	end
end

--- Validate an encoded profile string without storing it.
--- @param encoded string
--- @return table|nil data
--- @return string|nil error
function PRO.ProfileManagerMixin:ValidateImport(encoded)
	local decoded = C_EncodingUtil.DecodeBase64(encoded)
	if not decoded then return nil, "Invalid Base64 data." end
	local ok, data = pcall(C_EncodingUtil.DeserializeCBOR, decoded)
	if not ok or type(data) ~= "table" then return nil, "Invalid profile data." end
	return data
end

--- Store a validated profile table under the given name.
--- @param name string
--- @param data table
function PRO.ProfileManagerMixin:StoreImportedProfile(name, data)
	PRO.savedDB.profiles[name] = data
end

--- Generate a unique auto-name for an imported profile.
--- @return string name
function PRO.ProfileManagerMixin:GenerateImportName()
	local name = "Imported"
	local i = 1
	while PRO.savedDB.profiles[name] do
		i = i + 1
		name = "Imported " .. i
	end
	return name
end

--- Rename a profile (Default cannot be renamed).
--- @param oldName string
--- @param newName string
--- @return boolean success
function PRO.ProfileManagerMixin:RenameProfile(oldName, newName)
	if oldName == "Default" then return false end
	if not newName or newName == "" then return false end
	if PRO.savedDB.profiles[newName] then return false end
	if not PRO.savedDB.profiles[oldName] then return false end
	PRO.savedDB.profiles[newName] = PRO.savedDB.profiles[oldName]
	PRO.savedDB.profiles[oldName] = nil
	for charKey, pName in pairs(PRO.savedDB.characterProfiles) do
		if pName == oldName then
			PRO.savedDB.characterProfiles[charKey] = newName
		end
	end
	if PRO.currentProfileName == oldName then
		PRO.currentProfileName = newName
		if PRO.profileSetting then
			PRO.profileSetting:SetValue(newName)
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Instantiate the singleton profile manager
-- ---------------------------------------------------------------------------

PRO.profileManager = CreateFromMixins(PRO.ProfileManagerMixin)

-- Expose convenience wrappers on PRO for cross-module access (used by Settings.lua)
function PRO.SwitchProfile(name)
	PRO.profileManager:SwitchProfile(name, PRO.applyCallback)
end

function PRO.CreateProfile(name)
	return PRO.profileManager:CreateProfile(name)
end

function PRO.DeleteProfile(name)
	return PRO.profileManager:DeleteProfile(name)
end

function PRO.CopyProfile(sourceName)
	return PRO.profileManager:CopyProfile(sourceName, PRO.applyCallback)
end

function PRO.GetProfileNames()
	return PRO.profileManager:GetProfileNames()
end

function PRO.ExportProfile()
	return PRO.profileManager:ExportProfile()
end

function PRO.ValidateImport(encoded)
	return PRO.profileManager:ValidateImport(encoded)
end

function PRO.StoreImportedProfile(name, data)
	return PRO.profileManager:StoreImportedProfile(name, data)
end

function PRO.GenerateImportName()
	return PRO.profileManager:GenerateImportName()
end

function PRO.RenameProfile(oldName, newName)
	return PRO.profileManager:RenameProfile(oldName, newName)
end
