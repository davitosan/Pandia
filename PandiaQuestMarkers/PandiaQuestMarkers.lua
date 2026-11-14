-- Raid-mark quest-related nameplate/mouseover units; optional sound on new detection.

local L = PandiaQuestMarkersLocale
local DB

-- Skull → Cross → Square → Moon → Triangle → Diamond → Circle → Star
local MARK_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }

local SOUND_KEYS = { "quest", "map", "raid", "tell", "auction" }
local SOUND_ID = {
	quest = SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST,
	map = SOUNDKIT.MAP_PING,
	raid = SOUNDKIT.RAID_WARNING,
	tell = SOUNDKIT.TELL_MESSAGE,
	auction = SOUNDKIT.AUCTION_WINDOW_OPEN,
}
local SOUND_LABEL = {
	quest = function() return L.SOUND_QUEST end,
	map = function() return L.SOUND_MAP end,
	raid = function() return L.SOUND_RAID end,
	tell = function() return L.SOUND_TELL end,
	auction = function() return L.SOUND_AUCTION end,
}

local CHANNELS = { "Master", "SFX", "Music", "Ambience", "Dialog" }
local CHANNEL_LABEL = {
	Master = function() return L.CHAN_MASTER end,
	SFX = function() return L.CHAN_SFX end,
	Music = function() return L.CHAN_MUSIC end,
	Ambience = function() return L.CHAN_AMBIENCE end,
	Dialog = function() return L.CHAN_DIALOG end,
}

-- guid -> { icon, t, unit }
local marks = {}
-- guid -> true for sound-only (gather / unmarkable) detections
local heard = {}
-- guid -> true; clear raid icon after combat (SetRaidTarget is protected in combat)
local pendingClear = {}

local function Defaults()
	return {
		solo = true,
		group = false,
		raid = false,
		pvp = false,
		sound = false,
		soundKey = "quest",
		soundChannel = "SFX",
	}
end

local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = dst[k] or {}
			CopyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function Secret(v)
	return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end

local function ContextAllowed()
	if not DB then
		return false
	end
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" or instanceType == "arena" then
		return DB.pvp and true or false
	end
	if IsInRaid() then
		return DB.raid and true or false
	end
	if IsInGroup() then
		return DB.group and true or false
	end
	return DB.solo and true or false
end

local function UnitGUIDSafe(unit)
	if type(unit) ~= "string" or unit == "" then
		return nil
	end
	local ok, guid = pcall(UnitGUID, unit)
	if not ok or guid == nil or Secret(guid) then
		return nil
	end
	return guid
end

local function IsQuestRelated(unit)
	if type(unit) ~= "string" or unit == "" then
		return false
	end
	local okExists, exists = pcall(UnitExists, unit)
	if not okExists or not exists then
		return false
	end
	local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
	if okPlayer and isPlayer and not Secret(isPlayer) and isPlayer then
		return false
	end
	if not C_QuestLog or not C_QuestLog.UnitIsRelatedToActiveQuest then
		return false
	end
	local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
	return ok and related ~= nil and not Secret(related) and related and true or false
end

-- Gather nodes / world objects usually have no HP; don't burn raid icons on them.
local function LooksMarkable(unit)
	local ok, maxH = pcall(UnitHealthMax, unit)
	if not ok or maxH == nil or Secret(maxH) then
		return true
	end
	local n = tonumber(maxH)
	return not n or n > 0
end

local function PlayDetectSound()
	if not DB or not DB.sound then
		return
	end
	local id = SOUND_ID[DB.soundKey] or SOUND_ID.quest
	local channel = DB.soundChannel or "SFX"
	pcall(PlaySound, id, channel)
end

local function ClearUnitMark(unit)
	if type(unit) ~= "string" or InCombatLockdown() then
		return false
	end
	local ok = pcall(function()
		local idx = GetRaidTargetIndex(unit)
		if idx and idx > 0 then
			SetRaidTarget(unit, 0)
		end
	end)
	return ok and true or false
end

local function ApplyMark(unit, icon)
	if InCombatLockdown() then
		return false
	end
	pcall(function()
		local cur = GetRaidTargetIndex(unit)
		if cur ~= icon then
			SetRaidTarget(unit, icon)
		end
	end)
	local ok, cur = pcall(GetRaidTargetIndex, unit)
	return ok and cur == icon
end

local function FindUnitByGUID(guid)
	if not guid then
		return nil
	end
	local function match(unit)
		return UnitGUIDSafe(unit) == guid and unit or nil
	end
	local u = match("mouseover") or match("target") or match("softenemy") or match("softfriend") or match("softinteract")
	if u then
		return u
	end
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if plates then
			for i = 1, #plates do
				local plate = plates[i]
				local token = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
				u = match(token)
				if u then
					return u
				end
			end
		end
	end
	return nil
end

local function ForgetGUID(guid)
	local info = marks[guid]
	if info then
		local unit = FindUnitByGUID(guid) or info.unit
		if unit and UnitGUIDSafe(unit) == guid then
			if not ClearUnitMark(unit) then
				pendingClear[guid] = true
			end
		end
		marks[guid] = nil
	end
	heard[guid] = nil
end

local function IconInUse(icon, exceptGuid)
	for g, info in pairs(marks) do
		if g ~= exceptGuid and info.icon == icon then
			return g
		end
	end
	return nil
end

local function AllocIcon(guid)
	local existing = marks[guid]
	if existing then
		existing.t = GetTime()
		return existing.icon, false
	end
	for i = 1, #MARK_ORDER do
		local icon = MARK_ORDER[i]
		if not IconInUse(icon) then
			marks[guid] = { icon = icon, t = GetTime() }
			return icon, true
		end
	end
	-- Reuse oldest mark's icon.
	local oldestGuid, oldestT
	for g, info in pairs(marks) do
		if not oldestT or info.t < oldestT then
			oldestGuid, oldestT = g, info.t
		end
	end
	local icon = marks[oldestGuid].icon
	ForgetGUID(oldestGuid)
	marks[guid] = { icon = icon, t = GetTime() }
	return icon, true
end

local function ConsiderUnit(unit)
	if not ContextAllowed() then
		return
	end
	local guid = UnitGUIDSafe(unit)
	if not guid then
		return
	end
	if not IsQuestRelated(unit) then
		if marks[guid] or heard[guid] then
			ForgetGUID(guid)
		end
		return
	end

	-- Unmarkable gather / world objects: sound only (game can't raid-mark them).
	if not LooksMarkable(unit) then
		if marks[guid] then
			ForgetGUID(guid)
		end
		if not heard[guid] then
			heard[guid] = true
			PlayDetectSound()
		end
		return
	end

	local icon, isNew = AllocIcon(guid)
	marks[guid].unit = unit
	if isNew then
		PlayDetectSound()
	end
	-- SetRaidTarget is protected in combat; map sticks and we apply on regen.
	ApplyMark(unit, icon)
end

local function ScanVisible()
	if not DB or not ContextAllowed() then
		return
	end
	ConsiderUnit("mouseover")
	ConsiderUnit("target")
	ConsiderUnit("softenemy")
	ConsiderUnit("softfriend")
	ConsiderUnit("softinteract")
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if plates then
			for i = 1, #plates do
				local plate = plates[i]
				local token = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
				if token then
					ConsiderUnit(token)
				end
			end
		end
	end
end

local function ReapStale()
	-- Drop map entries that are no longer quest-related when we can see them.
	local drop = {}
	for guid, info in pairs(marks) do
		local unit = FindUnitByGUID(guid) or info.unit
		if unit and UnitGUIDSafe(unit) == guid and not IsQuestRelated(unit) then
			drop[#drop + 1] = guid
		end
	end
	for i = 1, #drop do
		ForgetGUID(drop[i])
	end
	for guid in pairs(heard) do
		local unit = FindUnitByGUID(guid)
		if unit and not IsQuestRelated(unit) then
			heard[guid] = nil
		end
	end
end

local function FlushAfterCombat()
	for guid in pairs(pendingClear) do
		local unit = FindUnitByGUID(guid)
		if unit then
			ClearUnitMark(unit)
		end
		pendingClear[guid] = nil
	end
	ScanVisible()
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_UPDATE")
events:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_REGEN_ENABLED" then
		FlushAfterCombat()
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		ConsiderUnit(arg1)
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		ConsiderUnit("mouseover")
	elseif event == "PLAYER_TARGET_CHANGED" then
		ConsiderUnit("target")
	elseif event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then
		return
	else
		ReapStale()
		ScanVisible()
	end
end)

local accum = 0
events:SetScript("OnUpdate", function(_, dt)
	accum = accum + dt
	if accum < 0.4 then
		return
	end
	accum = 0
	if ContextAllowed() then
		ScanVisible()
	end
end)

-- Options -------------------------------------------------------------------

local canvas
local widgets = {}

local hasWowDropdown = false
do
	local ok, frame = pcall(CreateFrame, "DropdownButton", nil, UIParent, "WowStyle1DropdownTemplate")
	if ok and frame then
		frame:Hide()
		hasWowDropdown = true
	end
end

local function HasWowDropdown()
	return hasWowDropdown
end

local function RefreshDropdown(drop)
	if not drop then
		return
	end
	if drop.GenerateMenu then
		drop:GenerateMenu()
	elseif drop.Refresh then
		drop:Refresh()
	end
end

local function RefreshCanvas()
	if not canvas or not DB then
		return
	end
	widgets.solo:SetChecked(DB.solo)
	widgets.group:SetChecked(DB.group)
	widgets.raid:SetChecked(DB.raid)
	widgets.pvp:SetChecked(DB.pvp)
	widgets.sound:SetChecked(DB.sound)
	RefreshDropdown(widgets.soundKey)
	RefreshDropdown(widgets.soundChannel)
end

local function AddCheckRow(parent, y, labelText, onClick)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 6)
	label:SetWidth(160)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", 180, y)
	check:SetScript("OnClick", onClick)
	return check, y - 36
end

local function AddChoiceDropdown(parent, y, labelText, keys, getKey, setKey, labelFn)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 4)
	label:SetWidth(160)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)

	if HasWowDropdown() then
		local drop = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
		drop:SetPoint("TOPLEFT", 180, y)
		drop:SetWidth(160)
		drop:SetupMenu(function(_, root)
			for i = 1, #keys do
				local key = keys[i]
				root:CreateRadio(labelFn(key), function()
					return getKey() == key
				end, function()
					setKey(key)
				end)
			end
		end)
		return drop, y - 36
	end

	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(160, 22)
	btn:SetPoint("TOPLEFT", 180, y)
	function btn:Refresh()
		self:SetText(labelFn(getKey()))
	end
	btn:SetScript("OnClick", function(self)
		local cur = getKey()
		local nextKey = keys[1]
		for i = 1, #keys do
			if keys[i] == cur then
				nextKey = keys[i % #keys + 1]
				break
			end
		end
		setKey(nextKey)
		self:Refresh()
	end)
	btn:Refresh()
	return btn, y - 36
end

local function BuildCanvas()
	canvas = CreateFrame("Frame")
	canvas:Hide()
	canvas:SetScript("OnShow", RefreshCanvas)

	local y = -16
	widgets.solo, y = AddCheckRow(canvas, y, L.CTX_SOLO, function(self)
		DB.solo = self:GetChecked() and true or false
	end)
	widgets.group, y = AddCheckRow(canvas, y, L.CTX_GROUP, function(self)
		DB.group = self:GetChecked() and true or false
	end)
	widgets.raid, y = AddCheckRow(canvas, y, L.CTX_RAID, function(self)
		DB.raid = self:GetChecked() and true or false
	end)
	widgets.pvp, y = AddCheckRow(canvas, y, L.CTX_PVP, function(self)
		DB.pvp = self:GetChecked() and true or false
	end)

	y = y - 8
	widgets.sound, y = AddCheckRow(canvas, y, L.SOUND_ENABLE, function(self)
		DB.sound = self:GetChecked() and true or false
	end)
	widgets.soundKey, y = AddChoiceDropdown(canvas, y, L.SOUND, SOUND_KEYS, function()
		return SOUND_ID[DB.soundKey] and DB.soundKey or "quest"
	end, function(key)
		DB.soundKey = key
	end, function(key)
		return SOUND_LABEL[key]()
	end)
	widgets.soundChannel, y = AddChoiceDropdown(canvas, y, L.SOUND_CHANNEL, CHANNELS, function()
		return CHANNEL_LABEL[DB.soundChannel] and DB.soundChannel or "SFX"
	end, function(key)
		DB.soundChannel = key
	end, function(key)
		return CHANNEL_LABEL[key]()
	end)

	return canvas
end

local optionsCategory

local function RegisterOptions()
	local frame = BuildCanvas()
	local category = Settings.RegisterCanvasLayoutCategory(frame, L.OPTIONS_TITLE)
	Settings.RegisterAddOnCategory(category)
	optionsCategory = category
end

function PandiaQuestMarkers_OnAddonCompartmentClick()
	if InCombatLockdown() or not optionsCategory then
		return
	end
	Settings.OpenToCategory(optionsCategory:GetID())
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
	if name ~= "PandiaQuestMarkers" then
		return
	end
	PandiaQuestMarkersDB = PandiaQuestMarkersDB or {}
	CopyDefaults(PandiaQuestMarkersDB, Defaults())
	DB = PandiaQuestMarkersDB
	C_Timer.After(0, RegisterOptions)
	loader:UnregisterEvent("ADDON_LOADED")
end)
