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
	"quest", "questComplete", "questOpen", "map", "raid", "ready", "tell", "invite",
	"auction", "alarm1", "alarm2", "alarm3", "levelUp", "loot", "fishing",
	"mail", "igOpen", "igClose", "pvp", "friend",
}
local SOUND_ID = {
	quest = SK("IG_QUEST_LOG_ABANDON_QUEST", 846),
	questComplete = SK("IG_QUEST_LIST_COMPLETE", 878),
	questOpen = SK("IG_QUEST_LOG_OPEN", 844),
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
	mail = SK("IG_BACKPACK_OPEN", 862),
	igOpen = SK("IG_MAINMENU_OPEN", 850),
	igClose = SK("IG_MAINMENU_CLOSE", 851),
	pvp = SK("IG_PVP_UPDATE", 4574),
	friend = SK("GM_CHAT_WARNING", 15273),
}
local SOUND_LABEL = {
	quest = function() return L.SOUND_QUEST end,
	questComplete = function() return L.SOUND_QUEST_COMPLETE end,
	questOpen = function() return L.SOUND_QUEST_OPEN end,
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
	mail = function() return L.SOUND_MAIL end,
	igOpen = function() return L.SOUND_MENU_OPEN end,
	igClose = function() return L.SOUND_MENU_CLOSE end,
	pvp = function() return L.SOUND_PVP end,
	friend = function() return L.SOUND_FRIEND end,
}

-- Multi-select: when a *new* mark / object detect may play sound.
local SOUND_WHEN_KEYS = { "nameplate", "mouseover", "target", "soft", "object" }
local SOUND_WHEN_LABEL = {
	nameplate = function() return L.SOUND_WHEN_NAMEPLATE end,
	mouseover = function() return L.SOUND_WHEN_MOUSEOVER end,
	target = function() return L.SOUND_WHEN_TARGET end,
	soft = function() return L.SOUND_WHEN_SOFT end,
	object = function() return L.SOUND_WHEN_OBJECT end,
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
-- guid -> already emitted a debug mark line for this relation
local debugLogged = {}

local function Defaults()
	return {
		solo = true,
		group = false,
		raid = false,
		pvp = false,
		debug = false,
		sound = false,
		soundKey = "friend",
		soundChannel = "SFX",
		soundWhen = {
			nameplate = true,
			mouseover = true,
			target = true,
			soft = false,
			object = true,
		},
	}
end

local function DebugEnabled()
	return DB and DB.debug and true or false
end

local function DebugPrint(...)
	if not DebugEnabled() then
		return
	end
	local n = select("#", ...)
	local parts = {}
	for i = 1, n do
		parts[i] = tostring(select(i, ...))
	end
	print("|cff99ff99[PandiaQM]|r " .. table.concat(parts, " "))
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

-- true = incomplete, false = finished, nil = unknown
local function TooltipObjectiveIncomplete(line)
	if line.completed == true then
		return false
	end
	if line.completed == false then
		return true
	end
	local a, b = line.numFulfilled, line.numRequired
	if type(a) == "number" and type(b) == "number" and not Secret(a) and not Secret(b) then
		return a < b
	end
	local text = line.leftText
	if type(text) == "string" then
		local x, y = text:match("(%d+)%s*/%s*(%d+)")
		if x and y then
			return tonumber(x) < tonumber(y)
		end
	end
	return nil
end

local function QuestIdIsComplete(questID)
	if type(questID) ~= "number" or not C_QuestLog or not C_QuestLog.IsComplete then
		return nil
	end
	local ok, complete = pcall(C_QuestLog.IsComplete, questID)
	if not ok or complete == nil or Secret(complete) then
		return nil
	end
	return complete and true or false
end

-- work, reason, detail from tooltip lines (units or world objects)
local function QuestWorkStateFromLines(lines)
	if not lines then
		return nil, "no_tooltip_data", ""
	end
	local lineTypes = Enum and Enum.TooltipDataLineType
	local objType = lineTypes and lineTypes.QuestObjective
	local titleType = lineTypes and lineTypes.QuestTitle
	local sawObjective = false
	local sawIncomplete = false
	local sawKnownObjective = false
	local sawCompleteQuest = false
	local sawIncompleteQuest = false
	local bits = {}
	for i = 1, #lines do
		local line = lines[i]
		if objType and line.type == objType then
			sawObjective = true
			local state = TooltipObjectiveIncomplete(line)
			local label = type(line.leftText) == "string" and line.leftText or "?"
			if state ~= nil then
				sawKnownObjective = true
				if state then
					sawIncomplete = true
				end
			end
			bits[#bits + 1] = string.format(
				"obj[%s completed=%s %s/%s]",
				label,
				tostring(line.completed),
				tostring(line.numFulfilled),
				tostring(line.numRequired)
			)
		elseif titleType and line.type == titleType and type(line.id) == "number" then
			local complete = QuestIdIsComplete(line.id)
			local title = type(line.leftText) == "string" and line.leftText or ("#" .. tostring(line.id))
			if complete == true then
				sawCompleteQuest = true
			elseif complete == false then
				sawIncompleteQuest = true
			end
			bits[#bits + 1] = string.format("title[%s id=%s IsComplete=%s]", title, tostring(line.id), tostring(complete))
		end
	end
	local detail = table.concat(bits, "; ")
	if sawIncomplete then
		return true, "incomplete_objective", detail
	end
	if sawKnownObjective then
		return false, "objectives_finished", detail
	end
	if sawIncompleteQuest then
		return true, "quest_not_complete", detail
	end
	if sawCompleteQuest or sawObjective then
		return false, sawCompleteQuest and "quest_complete" or "objectives_unparsed", detail
	end
	return nil, "no_quest_tooltip_lines", detail
end

local function UnitQuestWorkState(unit)
	if not C_TooltipInfo or not C_TooltipInfo.GetUnit then
		return nil, "no_tooltip_api", ""
	end
	local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
	if not ok or not data or not data.lines then
		return nil, "no_tooltip_data", ""
	end
	return QuestWorkStateFromLines(data.lines)
end

local function TooltipObjectName(lines)
	if not lines then
		return nil
	end
	for i = 1, #lines do
		local text = lines[i].leftText
		if type(text) == "string" and text ~= "" and not Secret(text) then
			return text
		end
	end
	return nil
end

local function UnitIsHostile(unit)
	local ok, canAttack = pcall(UnitCanAttack, "player", unit)
	return ok and canAttack and not Secret(canAttack) and canAttack and true or false
end

-- ok, meta: whether to mark, plus debug fields
local function QuestMarkDecision(unit)
	local meta = {
		ok = false,
		related = false,
		hostile = false,
		work = nil,
		reason = "invalid",
		detail = "",
	}
	if type(unit) ~= "string" or unit == "" then
		meta.reason = "bad_unit"
		return meta
	end
	local okExists, exists = pcall(UnitExists, unit)
	if not okExists or not exists then
		meta.reason = "missing"
		return meta
	end
	local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
	if okPlayer and isPlayer and not Secret(isPlayer) and isPlayer then
		meta.reason = "player"
		return meta
	end
	if not C_QuestLog or not C_QuestLog.UnitIsRelatedToActiveQuest then
		meta.reason = "no_related_api"
		return meta
	end
	local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
	meta.related = ok and related ~= nil and not Secret(related) and related and true or false
	if not meta.related then
		meta.reason = "not_related"
		return meta
	end
	meta.hostile = UnitIsHostile(unit)
	local work, workReason, detail = UnitQuestWorkState(unit)
	meta.work = work
	meta.detail = detail or ""
	-- Hostiles stay "related" after objectives are done; only mark when tooltip shows
	-- incomplete work. Friendlies stay eligible (turn-in NPCs).
	if meta.hostile then
		meta.ok = work == true
		meta.reason = meta.ok and ("hostile_" .. workReason) or ("hostile_skip_" .. workReason)
		return meta
	end
	meta.ok = true
	meta.reason = "friendly_related"
	return meta
end

local function IsQuestRelated(unit)
	return QuestMarkDecision(unit).ok
end

local function UnitNameSafe(unit)
	local ok, name = pcall(UnitName, unit)
	if ok and type(name) == "string" and name ~= "" and not Secret(name) then
		return name
	end
	return "?"
end

local function DebugLogMark(unit, guid, source, icon, kind, meta)
	if not DebugEnabled() then
		return
	end
	if guid and debugLogged[guid] and kind ~= "new" then
		return
	end
	if guid then
		debugLogged[guid] = true
	end
	meta = meta or QuestMarkDecision(unit)
	DebugPrint(
		"MARK",
		kind,
		"name=" .. UnitNameSafe(unit),
		"unit=" .. tostring(unit),
		"icon=" .. tostring(icon),
		"source=" .. tostring(source),
		"related=" .. tostring(meta.related),
		"hostile=" .. tostring(meta.hostile),
		"work=" .. tostring(meta.work),
		"why=" .. tostring(meta.reason),
		meta.detail ~= "" and ("tooltip=" .. meta.detail) or "tooltip=(none)"
	)
end

local function PlayConfiguredSound()
	if not DB then
		return
	end
	local id = SOUND_ID[DB.soundKey] or SOUND_ID.friend
	local channel = DB.soundChannel or "SFX"
	pcall(PlaySound, id, channel)
end

local function SoundWhenEnabled(source)
	if not DB or not DB.sound then
		return false
	end
	local w = DB.soundWhen
	if type(w) ~= "table" then
		return true
	end
	return w[source] and true or false
end

local function PlayDetectSound(source)
	if SoundWhenEnabled(source or "nameplate") then
		PlayConfiguredSound()
	end
end

-- Quest world objects (no unit / nameplate): sound-only via GetWorldCursor.
-- Play once per continuous hover of a given object name. dataInstanceID rebuilds while
-- hovering, so it cannot be the dedupe key. Leave grace avoids tooltip flicker spam;
-- move off briefly to ping another same-named object nearby.
local cursorObjectName = nil
local cursorObjectClearAt = nil

local function NoteCursorObjectGone()
	if cursorObjectName and not cursorObjectClearAt then
		cursorObjectClearAt = GetTime() + 0.3
	end
end

local function ConsiderWorldCursor()
	if not ContextAllowed() or not DB then
		cursorObjectName = nil
		cursorObjectClearAt = nil
		return
	end
	if not C_TooltipInfo or not C_TooltipInfo.GetWorldCursor then
		return
	end
	if cursorObjectClearAt and GetTime() >= cursorObjectClearAt then
		cursorObjectName = nil
		cursorObjectClearAt = nil
	end
	local okExists, exists = pcall(UnitExists, "mouseover")
	if okExists and exists then
		NoteCursorObjectGone()
		return
	end
	local ok, data = pcall(C_TooltipInfo.GetWorldCursor)
	if not ok or not data or not data.lines then
		NoteCursorObjectGone()
		return
	end
	local objectType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
	if objectType and data.type ~= objectType then
		NoteCursorObjectGone()
		return
	end
	local work, reason, detail = QuestWorkStateFromLines(data.lines)
	if work ~= true then
		NoteCursorObjectGone()
		return
	end
	local name = TooltipObjectName(data.lines) or "object"
	cursorObjectClearAt = nil
	if name == cursorObjectName then
		return
	end
	cursorObjectName = name
	PlayDetectSound("object")
	if DebugEnabled() then
		DebugPrint(
			"OBJECT",
			"sound_only",
			"name=" .. name,
			"why=" .. tostring(reason),
			detail ~= "" and ("tooltip=" .. detail) or "tooltip=(none)"
		)
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
	debugLogged[guid] = nil
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

local function ConsiderUnit(unit, source)
	source = source or "nameplate"
	if not ContextAllowed() then
		return
	end
	local guid = UnitGUIDSafe(unit)
	if not guid then
		return
	end
	local decision = QuestMarkDecision(unit)
	if not decision.ok then
		if marks[guid] or heard[guid] or suppressed[guid] or lastReal[guid] then
			ForgetGUID(guid)
		end
		return
	end

	-- Manual raid target wins (including clear → suppressed).
	if SyncManualRaidTarget(unit) and (RealMarkIndex(unit) or suppressed[guid]) then
		local real = RealMarkIndex(unit)
		if real then
			DebugLogMark(unit, guid, source, real, "real", decision)
		end
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
			PlayDetectSound(source)
			DebugLogMark(unit, guid, source, "-", "sound_only", decision)
		end
		return
	end

	local icon, isNew = AllocIcon(guid)
	marks[guid].unit = unit
	if isNew then
		heard[guid] = nil
		PlayDetectSound(source)
		DebugLogMark(unit, guid, source, icon, "new", decision)
	else
		DebugLogMark(unit, guid, source, icon, "overlay", decision)
	end
	ShowUnitIcon(unit, icon)
end

local function ScanVisible()
	if not DB or not ContextAllowed() then
		return
	end
	ConsiderUnit("mouseover", "mouseover")
	ConsiderUnit("target", "target")
	ConsiderUnit("softenemy", "soft")
	ConsiderUnit("softfriend", "soft")
	ConsiderUnit("softinteract", "soft")
	ConsiderWorldCursor()
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if plates then
			for i = 1, #plates do
				local plate = plates[i]
				local token = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
				if token then
					ConsiderUnit(token, "nameplate")
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

-- Forever forbids addons registering COMBAT_LOG_EVENT_UNFILTERED; free icons on
-- dead nameplates / dead units instead.

local function ReleaseDeadMarks()
	local drop = {}
	for guid, info in pairs(marks) do
		local unit = FindUnitByGUID(guid) or info.unit
		if unit and UnitGUIDSafe(unit) == guid and UnitLooksDead(unit) then
			drop[#drop + 1] = guid
		end
	end
	for i = 1, #drop do
		ReleaseMarkGUID(drop[i])
	end
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
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "RAID_TARGET_UPDATE" then
		SyncAllRaidTargets()
		return
	end
	if event == "NAME_PLATE_UNIT_REMOVED" then
		-- Return icon to the priority pool when the mob dies; keep sticky if only out of range.
		local guid = arg1 and UnitGUIDSafe(arg1)
		if guid and UnitLooksDead(arg1) then
			ReleaseMarkGUID(guid)
		elseif arg1 and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
			local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, arg1)
			if ok then
				HidePlateIcon(plate)
			end
		end
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		ConsiderUnit(arg1, "nameplate")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		ConsiderUnit("mouseover", "mouseover")
		ConsiderWorldCursor()
	elseif event == "PLAYER_TARGET_CHANGED" then
		ConsiderUnit("target", "target")
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
		ReleaseDeadMarks()
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
	widgets.debug:SetChecked(DB.debug)
	widgets.sound:SetChecked(DB.sound)
	RefreshDropdown(widgets.soundKey)
	RefreshDropdown(widgets.soundChannel)
	RefreshDropdown(widgets.soundWhen)
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

local function SoundWhenSummary()
	DB.soundWhen = DB.soundWhen or Defaults().soundWhen
	local n = 0
	for i = 1, #SOUND_WHEN_KEYS do
		if DB.soundWhen[SOUND_WHEN_KEYS[i]] then
			n = n + 1
		end
	end
	if n == 0 then
		return L.SOUND_WHEN_NONE
	end
	if n == #SOUND_WHEN_KEYS then
		return L.SOUND_WHEN_ALL
	end
	local parts = {}
	for i = 1, #SOUND_WHEN_KEYS do
		local key = SOUND_WHEN_KEYS[i]
		if DB.soundWhen[key] then
			parts[#parts + 1] = SOUND_WHEN_LABEL[key]()
		end
	end
	return table.concat(parts, ", ")
end

local function AddMultiCheckboxDropdown(parent, y, labelText, keys, labelFn, isOn, setOn, summaryFn)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 4)
	label:SetWidth(140)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)

	if HasWowDropdown() then
		local drop = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
		drop:SetPoint("TOPLEFT", 160, y)
		drop:SetWidth(280)
		drop:SetupMenu(function(_, root)
			for i = 1, #keys do
				local key = keys[i]
				root:CreateCheckbox(labelFn(key), function()
					return isOn(key)
				end, function()
					setOn(key, not isOn(key))
					if drop.GenerateMenu then
						drop:GenerateMenu()
					end
				end)
			end
		end)
		-- Show summary on the closed control when possible.
		if drop.SetDefaultText then
			drop:SetDefaultText(summaryFn())
		end
		function drop:Refresh()
			if self.SetDefaultText then
				self:SetDefaultText(summaryFn())
			end
			if self.GenerateMenu then
				self:GenerateMenu()
			end
		end
		return drop, y - 32
	end

	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(280, 22)
	btn:SetPoint("TOPLEFT", 160, y)
	function btn:Refresh()
		self:SetText(summaryFn())
	end
	btn:SetScript("OnClick", function(self)
		local key = keys[1]
		for i = 1, #keys do
			if isOn(keys[i]) then
				key = keys[i % #keys + 1]
				break
			end
		end
		for i = 1, #keys do
			setOn(keys[i], keys[i] == key)
		end
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
	widgets.soundWhen, y = AddMultiCheckboxDropdown(canvas, y, L.SOUND_WHEN, SOUND_WHEN_KEYS, function(key)
		return SOUND_WHEN_LABEL[key]()
	end, function(key)
		DB.soundWhen = DB.soundWhen or Defaults().soundWhen
		return DB.soundWhen[key] and true or false
	end, function(key, on)
		DB.soundWhen = DB.soundWhen or Defaults().soundWhen
		DB.soundWhen[key] = on and true or false
	end, SoundWhenSummary)

	local soundY = y
	widgets.soundKey, y = AddChoiceDropdown(canvas, y, L.SOUND, SOUND_KEYS, function()
		return SOUND_ID[DB.soundKey] and DB.soundKey or "friend"
	end, function(key)
		DB.soundKey = key
	end, function(key)
		return SOUND_LABEL[key]()
	end)
	local preview = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	preview:SetSize(90, 22)
	preview:SetPoint("TOPLEFT", 350, soundY)
	preview:SetText(L.SOUND_PREVIEW)
	preview:SetScript("OnClick", PlayConfiguredSound)
	widgets.soundPreview = preview

	widgets.soundChannel, y = AddChoiceDropdown(canvas, y, L.SOUND_CHANNEL, CHANNELS, function()
		return CHANNEL_LABEL[DB.soundChannel] and DB.soundChannel or "SFX"
	end, function(key)
		DB.soundChannel = key
	end, function(key)
		return CHANNEL_LABEL[key]()
	end)

	y = y - 8
	widgets.debug, y = AddCheckRow(canvas, y, L.DEBUG, function(self)
		DB.debug = self:GetChecked() and true or false
		if DB.debug then
			DebugPrint("debug logging enabled")
		end
	end)

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
