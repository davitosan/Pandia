-- Quest-related nameplate icons (raid-target art). Forever protects SetRaidTarget for addons.

local L = PandiaQuestMarkersLocale
local DB

-- Skull → Cross → Square → Moon → Triangle → Diamond → Circle → Star
local MARK_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }

local function SK(name, fallback)
	local id = SOUNDKIT and SOUNDKIT[name]
	return id or fallback
end

-- Common UI alerts (Blizzard has thousands more; these preview well for detections).
local SOUND_KEYS = {
	"quest", "questComplete", "map", "raid", "ready", "tell", "invite",
	"auction", "alarm1", "alarm2", "alarm3", "levelUp", "loot", "fishing",
}
local SOUND_ID = {
	quest = SK("IG_QUEST_LOG_ABANDON_QUEST", 846),
	questComplete = SK("IG_QUEST_LIST_COMPLETE", 878),
	map = SK("MAP_PING", 3175),
	raid = SK("RAID_WARNING", 8959),
	ready = SK("READY_CHECK", 8960),
	tell = SK("TELL_MESSAGE", 3081),
	invite = SK("IG_PLAYER_INVITE", 880),
	auction = SK("AUCTION_WINDOW_OPEN", 5274),
	alarm1 = SK("ALARM_CLOCK_WARNING_1", 18871),
	alarm2 = SK("ALARM_CLOCK_WARNING_2", 12867),
	alarm3 = SK("ALARM_CLOCK_WARNING_3", 12889),
	levelUp = SK("LEVEL_UP", 888),
	loot = SK("LOOT_WINDOW_OPEN_EMPTY", 1201),
	fishing = SK("FISHING_REEL_IN", 3407),
}
local SOUND_LABEL = {
	quest = function() return L.SOUND_QUEST end,
	questComplete = function() return L.SOUND_QUEST_COMPLETE end,
	map = function() return L.SOUND_MAP end,
	raid = function() return L.SOUND_RAID end,
	ready = function() return L.SOUND_READY end,
	tell = function() return L.SOUND_TELL end,
	invite = function() return L.SOUND_INVITE end,
	auction = function() return L.SOUND_AUCTION end,
	alarm1 = function() return L.SOUND_ALARM1 end,
	alarm2 = function() return L.SOUND_ALARM2 end,
	alarm3 = function() return L.SOUND_ALARM3 end,
	levelUp = function() return L.SOUND_LEVELUP end,
	loot = function() return L.SOUND_LOOT end,
	fishing = function() return L.SOUND_FISHING end,
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
-- guid -> true for sound-only (no nameplate) detections
local heard = {}
-- guid -> last real GetRaidTargetIndex (tracks manual set/clear)
local lastReal = {}
-- guid -> user cleared the mark; do not auto-paint until quest relation drops
local suppressed = {}

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

local function PlayConfiguredSound()
	if not DB then
		return
	end
	local id = SOUND_ID[DB.soundKey] or SOUND_ID.quest
	local channel = DB.soundChannel or "SFX"
	pcall(PlaySound, id, channel)
end

local function PlayDetectSound()
	if DB and DB.sound then
		PlayConfiguredSound()
	end
end

local function RaidIconPath(icon)
	return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. tostring(icon)
end

local function PlateForUnit(unit)
	if not unit or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
		return nil
	end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if ok then
		return plate
	end
	return nil
end

local function UnitFrameParts(plate)
	local uf = plate and plate.UnitFrame
	if not uf or (uf.IsForbidden and uf:IsForbidden()) then
		return nil
	end
	local bar = uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
	local rtf = uf.RaidTargetFrame
	local icon = rtf and (rtf.RaidTargetIcon or rtf.icon)
	return uf, bar, rtf, icon
end

local function HasRealRaidTarget(unit)
	local ok, idx = pcall(GetRaidTargetIndex, unit)
	return ok and idx ~= nil and not Secret(idx) and idx > 0
end

-- Match Blizzard: RIGHT of icon to LEFT of health bar, -5.
local function EnsurePlateIcon(plate, bar)
	local f = plate.PandiaQuestMark
	local parent = bar or plate
	if not f then
		f = CreateFrame("Frame", nil, parent)
		f:SetSize(20, 20)
		f.tex = f:CreateTexture(nil, "OVERLAY")
		f.tex:SetAllPoints()
		f:Hide()
		plate.PandiaQuestMark = f
	elseif f:GetParent() ~= parent then
		f:SetParent(parent)
	end
	f:ClearAllPoints()
	if bar then
		f:SetPoint("RIGHT", bar, "LEFT", -5, 0)
	else
		f:SetPoint("RIGHT", plate, "LEFT", -5, 0)
	end
	return f
end

local function RaiseMarkLevel(frame, uf)
	if not frame then
		return
	end
	local base = (uf and uf.GetFrameLevel and uf:GetFrameLevel()) or 0
	-- Sit above combo pips / other plate overlays so X and pips can share the left slot.
	frame:SetFrameLevel(base + 40)
end

local function ShowBlizzRaidIcon(uf, rtf, iconTex, icon)
	if not iconTex then
		return false
	end
	if type(SetRaidTargetIconTexture) == "function" then
		pcall(SetRaidTargetIconTexture, iconTex, icon)
	else
		iconTex:SetTexture(RaidIconPath(icon))
	end
	iconTex:Show()
	if rtf then
		rtf:Show()
		RaiseMarkLevel(rtf, uf)
	end
	return true
end

local function ShowUnitIcon(unit, icon)
	local plate = PlateForUnit(unit)
	if not plate then
		return false
	end
	local uf, bar, rtf, blizzIcon = UnitFrameParts(plate)
	-- Prefer Blizzard's raid-target slot so we sit in the exact default spot.
	if ShowBlizzRaidIcon(uf, rtf, blizzIcon, icon) then
		if plate.PandiaQuestMark then
			plate.PandiaQuestMark:Hide()
		end
		return true
	end
	local f = EnsurePlateIcon(plate, bar)
	f.tex:SetTexture(RaidIconPath(icon))
	RaiseMarkLevel(f, uf)
	f:Show()
	return true
end

local function HideUnitIcon(unit)
	local plate = PlateForUnit(unit)
	if not plate then
		return
	end
	if plate.PandiaQuestMark then
		plate.PandiaQuestMark:Hide()
	end
	-- Don't clear Blizzard's icon if the unit has a real raid mark.
	if unit and HasRealRaidTarget(unit) then
		return
	end
	local _, _, rtf, blizzIcon = UnitFrameParts(plate)
	if blizzIcon then
		blizzIcon:Hide()
	end
	if rtf and not HasRealRaidTarget(unit) then
		-- leave frame; icon hidden is enough
	end
end

local function HidePlateIcon(plate)
	if not plate then
		return
	end
	if plate.PandiaQuestMark then
		plate.PandiaQuestMark:Hide()
	end
	local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
	if token and HasRealRaidTarget(token) then
		return
	end
	local _, _, _, blizzIcon = UnitFrameParts(plate)
	if blizzIcon then
		blizzIcon:Hide()
	end
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
		if unit then
			HideUnitIcon(unit)
		end
		marks[guid] = nil
	end
	heard[guid] = nil
	lastReal[guid] = nil
	suppressed[guid] = nil
end

local function IconInUse(icon, exceptGuid)
	for g, info in pairs(marks) do
		if g ~= exceptGuid and info.icon == icon then
			return g
		end
	end
	return nil
end

-- Priority queue: always take the first free icon in MARK_ORDER (skull → … → star).
-- Freed icons (mob killed) go back to the front of the line.
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
	-- All busy: evict lowest priority (last in order) so higher icons free up first.
	for i = #MARK_ORDER, 1, -1 do
		local icon = MARK_ORDER[i]
		local victim = IconInUse(icon)
		if victim then
			ForgetGUID(victim)
			marks[guid] = { icon = icon, t = GetTime() }
			return icon, true
		end
	end
	return MARK_ORDER[1], true
end

local function ReleaseMarkGUID(guid)
	if guid and marks[guid] then
		ForgetGUID(guid)
	end
end

local function UnitLooksDead(unit)
	if type(unit) ~= "string" then
		return false
	end
	local ok, dead = pcall(UnitIsDead, unit)
	if ok and dead then
		return true
	end
	ok, dead = pcall(UnitIsDeadOrGhost, unit)
	return ok and dead and true or false
end

local function RealMarkIndex(unit)
	if HasRealRaidTarget(unit) then
		local ok, idx = pcall(GetRaidTargetIndex, unit)
		if ok and type(idx) == "number" and idx > 0 then
			return idx
		end
	end
	return nil
end

-- Adopt manual SetRaidTarget / clear. lastReal distinguishes "never marked" from "user cleared".
local function SyncManualRaidTarget(unit)
	local guid = UnitGUIDSafe(unit)
	if not guid then
		return false
	end
	local real = RealMarkIndex(unit)
	local prev = lastReal[guid]
	if real then
		suppressed[guid] = nil
		lastReal[guid] = real
		local other = IconInUse(real, guid)
		if other then
			-- Free the pool slot; that unit will get a new auto icon on next scan if still related.
			local ou = FindUnitByGUID(other) or (marks[other] and marks[other].unit)
			marks[other] = nil
			if ou then
				HideUnitIcon(ou)
			end
		end
		if not marks[guid] then
			marks[guid] = { icon = real, t = GetTime(), unit = unit }
		else
			marks[guid].icon = real
			marks[guid].t = GetTime()
			marks[guid].unit = unit
		end
		-- Blizzard paints real marks; keep our overlay hidden.
		local plate = PlateForUnit(unit)
		if plate and plate.PandiaQuestMark then
			plate.PandiaQuestMark:Hide()
		end
		return true
	end
	if prev then
		-- Had a real mark, now none → user cleared.
		lastReal[guid] = nil
		suppressed[guid] = true
		if marks[guid] then
			HideUnitIcon(unit)
			marks[guid] = nil
		end
		return true
	end
	return false
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
		if marks[guid] or heard[guid] or suppressed[guid] or lastReal[guid] then
			ForgetGUID(guid)
		end
		return
	end

	-- Manual raid target wins (including clear → suppressed).
	if SyncManualRaidTarget(unit) and (RealMarkIndex(unit) or suppressed[guid]) then
		return
	end
	if suppressed[guid] then
		return
	end

	local plate = PlateForUnit(unit)
	if not plate then
		-- No nameplate (gather / distant): sound once, no icon slot until a plate exists.
		if not heard[guid] and not marks[guid] then
			heard[guid] = true
			PlayDetectSound()
		end
		return
	end

	local icon, isNew = AllocIcon(guid)
	marks[guid].unit = unit
	if isNew then
		heard[guid] = nil
		PlayDetectSound()
	end
	ShowUnitIcon(unit, icon)
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
	for guid in pairs(suppressed) do
		local unit = FindUnitByGUID(guid)
		if unit and not IsQuestRelated(unit) then
			ForgetGUID(guid)
		elseif not unit then
			-- keep suppression until we see them unrelated or related again post-forget
		end
	end
end

-- After Blizzard raid-target UI updates: adopt manual icons/clears, then re-paint remaining fakes.
local function SyncAllRaidTargets()
	local function touch(unit)
		if type(unit) == "string" then
			SyncManualRaidTarget(unit)
		end
	end
	touch("mouseover")
	touch("target")
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if plates then
			for i = 1, #plates do
				local plate = plates[i]
				local token = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
				touch(token)
			end
		end
	end
	for guid, info in pairs(marks) do
		if not suppressed[guid] and info.icon then
			local unit = FindUnitByGUID(guid) or info.unit
			if unit and not RealMarkIndex(unit) then
				ShowUnitIcon(unit, info.icon)
			end
		end
	end
end

if NamePlateDriverFrame and NamePlateDriverFrame.OnRaidTargetUpdate then
	hooksecurefunc(NamePlateDriverFrame, "OnRaidTargetUpdate", SyncAllRaidTargets)
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_UPDATE")
events:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("RAID_TARGET_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

-- CLEU RegisterEvent is protected in combat. InCombatLockdown() can still be
-- false during a mid-fight /reload load, and pcall does not silence FORBIDDEN —
-- so never register CLEU from the file chunk; only after leaving combat.
local cleuRegistered = false
local function EnsureCLEU()
	if cleuRegistered or InCombatLockdown() then
		return
	end
	events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	cleuRegistered = true
end

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_REGEN_ENABLED" then
		EnsureCLEU()
		return
	end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subEvent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
		if subEvent == "UNIT_DIED" then
			ReleaseMarkGUID(destGUID)
		end
		return
	end
	if event == "RAID_TARGET_UPDATE" then
		SyncAllRaidTargets()
		return
	end
	if event == "NAME_PLATE_UNIT_REMOVED" then
		-- Return icon to the priority pool when the mob dies; keep sticky if only out of range.
		if arg1 and UnitLooksDead(arg1) then
			ReleaseMarkGUID(UnitGUIDSafe(arg1))
		elseif arg1 and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
			local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, arg1)
			if ok then
				HidePlateIcon(plate)
			end
		end
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

local function AddSectionHeader(parent, y, text)
	local hdr = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", 16, y)
	hdr:SetText(text)
	return y - 28
end

local function AddLabeledCheck(parent, x, y, labelText, onClick)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", x, y)
	check:SetScript("OnClick", onClick)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetText(labelText)
	return check
end

local function AddCheckRow(parent, y, labelText, onClick)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 6)
	label:SetWidth(140)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", 160, y)
	check:SetScript("OnClick", onClick)
	return check, y - 32
end

local function AddChoiceDropdown(parent, y, labelText, keys, getKey, setKey, labelFn)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 4)
	label:SetWidth(140)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)

	if HasWowDropdown() then
		local drop = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
		drop:SetPoint("TOPLEFT", 160, y)
		drop:SetWidth(180)
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
		return drop, y - 32
	end

	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(180, 22)
	btn:SetPoint("TOPLEFT", 160, y)
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
	return btn, y - 32
end

local function BuildCanvas()
	canvas = CreateFrame("Frame")
	canvas:Hide()
	canvas.OnCommit = function() end
	canvas.OnDefault = function() end
	canvas.OnRefresh = RefreshCanvas
	canvas:SetScript("OnShow", RefreshCanvas)

	local y = -16
	y = AddSectionHeader(canvas, y, L.SECTION_CONTEXT)
	widgets.solo = AddLabeledCheck(canvas, 16, y, L.CTX_SOLO, function(self)
		DB.solo = self:GetChecked() and true or false
	end)
	widgets.group = AddLabeledCheck(canvas, 140, y, L.CTX_GROUP, function(self)
		DB.group = self:GetChecked() and true or false
	end)
	widgets.raid = AddLabeledCheck(canvas, 264, y, L.CTX_RAID, function(self)
		DB.raid = self:GetChecked() and true or false
	end)
	widgets.pvp = AddLabeledCheck(canvas, 388, y, L.CTX_PVP, function(self)
		DB.pvp = self:GetChecked() and true or false
	end)
	y = y - 44

	y = AddSectionHeader(canvas, y, L.SECTION_SOUND)
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
	local channelY = y
	widgets.soundChannel, y = AddChoiceDropdown(canvas, y, L.SOUND_CHANNEL, CHANNELS, function()
		return CHANNEL_LABEL[DB.soundChannel] and DB.soundChannel or "SFX"
	end, function(key)
		DB.soundChannel = key
	end, function(key)
		return CHANNEL_LABEL[key]()
	end)

	local preview = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	preview:SetSize(90, 22)
	preview:SetPoint("TOPLEFT", 350, channelY)
	preview:SetText(L.SOUND_PREVIEW)
	preview:SetScript("OnClick", PlayConfiguredSound)
	widgets.soundPreview = preview

	return canvas
end

local optionsCategory

local function RegisterOptions()
	local frame = BuildCanvas()
	local category, layout = Settings.RegisterCanvasLayoutCategory(frame, L.OPTIONS_TITLE)
	if layout and layout.AddAnchorPoint then
		layout:AddAnchorPoint("TOPLEFT", 10, -10)
		layout:AddAnchorPoint("BOTTOMRIGHT", -10, 10)
	end
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
