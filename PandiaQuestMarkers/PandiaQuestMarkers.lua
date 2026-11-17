-- Quest-related nameplate icons (raid-target art). Forever protects SetRaidTarget for addons.

local L = PandiaQuestMarkersLocale
local QuestLogic = PandiaQuestMarkersQuestLogic
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
-- guid -> already played detect sound (survives icon eviction / tooltip flicker)
local sounded = {}
-- guid -> last real GetRaidTargetIndex (tracks manual set/clear)
local lastReal = {}
-- guid -> user cleared the mark; do not auto-paint until quest relation drops
local suppressed = {}
-- guid -> already emitted a debug mark line for this relation
local debugLogged = {}
-- guid -> last SEE probe signature (target/mouseover)
local debugProbe = {}

local function Defaults()
	return {
		solo = true,
		group = false,
		raid = false,
		pvp = false,
		clickMark = true,
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
		toastX = 0,
		toastY = -120,
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

local Secret = QuestLogic.Secret

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

local SafeText = QuestLogic.SafeText
local SafeNum = QuestLogic.SafeNum
local SafeBool = QuestLogic.SafeBool

local function QuestIdIsComplete(questID)
	questID = SafeNum(questID)
	if not questID or not C_QuestLog or not C_QuestLog.IsComplete then
		return nil
	end
	local ok, complete = pcall(C_QuestLog.IsComplete, questID)
	if not ok then
		return nil
	end
	return SafeBool(complete)
end

local function QuestWorkStateFromLines(lines)
	return QuestLogic.QuestWorkStateFromLines(lines, QuestIdIsComplete, DebugEnabled())
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
		local text = SafeText(lines[i].leftText)
		if text and text ~= "" then
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
	-- Hostiles: incomplete work only. Friendlies stay eligible (turn-in NPCs).
	local decided = QuestLogic.Decide(true, meta.hostile, work, workReason)
	meta.ok = decided.ok
	meta.reason = decided.reason
	meta.uncertain = decided.uncertain
	return meta
end

local function IsQuestRelated(unit)
	return QuestMarkDecision(unit).ok
end

local function ShouldKeepMark(unit)
	local d = QuestMarkDecision(unit)
	return d.ok or d.uncertain
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
	if guid and debugLogged[guid] and kind ~= "new" and kind ~= "real_unrelated" and kind ~= "skip" and kind ~= "see" then
		return
	end
	if guid and kind ~= "see" then
		debugLogged[guid] = true
	end
	meta = meta or QuestMarkDecision(unit)
	DebugPrint(
		kind == "see" and "SEE" or (kind == "skip" and "SKIP" or "MARK"),
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

-- Target/mouseover: always explain current decision once per state change (catches real marks
-- on unrelated mobs that never go through the overlay mark path).
local function DebugLogSee(unit, guid, source, decision, real)
	if not DebugEnabled() or not guid then
		return
	end
	if source ~= "target" and source ~= "mouseover" then
		return
	end
	local sig = table.concat({
		tostring(decision.ok),
		tostring(decision.related),
		tostring(decision.reason),
		tostring(decision.work),
		tostring(real or 0),
	}, "|")
	if debugProbe[guid] == sig then
		return
	end
	debugProbe[guid] = sig
	DebugLogMark(unit, guid, source, real or "-", "see", decision)
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

-- One ping per GUID until death / definitive drop (not eviction or secret tooltip flicker).
local function PlayDetectSoundOnce(guid, source)
	if not guid or sounded[guid] then
		return
	end
	if not SoundWhenEnabled(source or "nameplate") then
		return
	end
	sounded[guid] = true
	PlayConfiguredSound()
end

-- Quest world objects (no unit / nameplate): sound-only.
-- Enter via TooltipDataProcessor (when the object tooltip appears) + GetWorldCursor backup.
-- Leave clears hover so a new object can register; per-name cooldown blocks loot tooltip re-entry.
local hoverObjectName = nil
local lastObjectSoundName = nil
local lastObjectSoundTime = 0
-- ponytail: loot/despawn flickers clear+re-enter the same name; 4s is enough. Tighten if same-name packs need faster re-ping.
local OBJECT_SOUND_COOLDOWN = 4

local function ClearHoverObject()
	hoverObjectName = nil
end

local function OnQuestObjectTooltipData(data)
	if not ContextAllowed() or not DB or not data or not data.lines then
		return
	end
	local objectType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
	local dataType = data.type
	if objectType and dataType ~= nil and not Secret(dataType) and dataType ~= objectType then
		return
	end
	local work, reason, detail = QuestWorkStateFromLines(data.lines)
	if work ~= true then
		return
	end
	local name = TooltipObjectName(data.lines) or "object"
	if name == hoverObjectName then
		return
	end
	hoverObjectName = name
	local now = GetTime()
	if name == lastObjectSoundName and (now - lastObjectSoundTime) < OBJECT_SOUND_COOLDOWN then
		return
	end
	lastObjectSoundName = name
	lastObjectSoundTime = now
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

local function ConsiderWorldCursor()
	if not ContextAllowed() or not DB then
		ClearHoverObject()
		return
	end
	if not C_TooltipInfo or not C_TooltipInfo.GetWorldCursor then
		return
	end
	local okExists, exists = pcall(UnitExists, "mouseover")
	if okExists and exists then
		ClearHoverObject()
		return
	end
	local ok, data = pcall(C_TooltipInfo.GetWorldCursor)
	if not ok or not data or not data.lines then
		ClearHoverObject()
		return
	end
	local objectType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
	local dataType = data.type
	if objectType and (Secret(dataType) or dataType ~= objectType) then
		ClearHoverObject()
		return
	end
	local work = QuestWorkStateFromLines(data.lines)
	if work ~= true then
		ClearHoverObject()
		return
	end
	pcall(OnQuestObjectTooltipData, data)
end

do
	local tipType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
	if tipType and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
		TooltipDataProcessor.AddTooltipPostCall(tipType, function(tooltip, data)
			if tooltip ~= GameTooltip then
				return
			end
			-- Forever secrets object tooltip fields; never throw out of the secure tooltip path.
			pcall(OnQuestObjectTooltipData, data)
		end)
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

local function HidePlateForUnitToken(token)
	if not token or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
		return
	end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, token)
	if ok then
		HidePlateIcon(plate)
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
	sounded[guid] = nil
	lastReal[guid] = nil
	suppressed[guid] = nil
	debugLogged[guid] = nil
	debugProbe[guid] = nil
end

-- Free an icon slot without clearing sounded/heard (pack eviction thrash).
local function ReleaseIconOnly(guid)
	local info = marks[guid]
	if not info then
		return
	end
	local unit = FindUnitByGUID(guid) or info.unit
	if unit then
		HideUnitIcon(unit)
	end
	marks[guid] = nil
end

local function IconInUse(icon, exceptGuid)
	for g, info in pairs(marks) do
		if g ~= exceptGuid and info.icon == icon then
			return g
		end
	end
	return nil
end

local ToastLogic = PandiaQuestMarkersToastLogic

local function PeekIcon(guid, reserved)
	local existing = marks[guid]
	if existing then
		return existing.icon
	end
	local blocked = {}
	for i = 1, #MARK_ORDER do
		local icon = MARK_ORDER[i]
		if IconInUse(icon) or (reserved and reserved[icon]) then
			blocked[icon] = true
		end
	end
	return ToastLogic.ReservePeek(MARK_ORDER, blocked)
end

local function AssignToastIcons(list)
	local reserved = {}
	local n = 0
	for i = 1, #list do
		local kind = list[i]
		local icon = kind.guid and PeekIcon(kind.guid, reserved) or nil
		if icon then
			reserved[icon] = true
			kind.icon = icon
			n = n + 1
			list[n] = kind
		end
	end
	for i = n + 1, #list do
		list[i] = nil
	end
end

local function ClickableUnitToken(guid)
	local order = { "target", "softenemy", "softfriend", "softinteract", "mouseover" }
	for i = 1, #order do
		local unit = order[i]
		if UnitGUIDSafe(unit) == guid then
			return unit
		end
	end
	return nil
end

-- Horizontal click-to-mark toast: one slot per NPC name; stays while unmarked quest mobs exist.
-- Pre-sized visual shells (never SetSize after create) + separate secure button host.
-- Host is NOT anchored to the shell (that made shell SetSize/Show protected in combat).
local toast -- secure click host
local toastShell -- active visual chrome
local toastShells = {} -- [slotCount] = pre-sized shell
local toastWantShown = false
local toastPaused = false -- X until no eligible mobs remain
local toastStickyKinds = nil -- last shown rows; kept briefly after mouseover leaves
local toastStickyUntil = 0
local TOAST_STICKY_SEC = 15
local toastFitCount = 1
local toastPosX, toastPosY = 0, -120
local TOAST_MAX_SLOTS = 4
local TOAST_SLOT_W = 90
local TOAST_BODY_H = 50
local TOAST_HDR_H = 28 -- room under overhanging header plaque / close
local TOAST_PAD = 14
local TOAST_H = TOAST_HDR_H + TOAST_BODY_H + TOAST_PAD
local TOAST_CLOSE_W = 32 -- UIPanelCloseButton hit size
local TOAST_TITLE_PAD = 48 -- space around title text inside the plaque / before the X
-- Floor from locale title + padding + close; raised when the first shell measures the real string.
local TOAST_W_MIN = 200
local TOAST_W_MAX = 32 + TOAST_MAX_SLOTS * TOAST_SLOT_W

local function ToastWidthForCount(n)
	return ToastLogic.ToastWidthForCount(n, TOAST_W_MIN, TOAST_SLOT_W, TOAST_MAX_SLOTS)
end

local function CaptureShellPos(shell)
	if not shell then
		return
	end
	local parent = UIParent
	local scale = shell:GetEffectiveScale() / parent:GetEffectiveScale()
	local left = shell:GetLeft() or 0
	local top = shell:GetTop() or 0
	local pW = parent:GetWidth() or 1
	local pH = parent:GetHeight() or 1
	toastPosX = left * scale + (shell:GetWidth() * scale) / 2 - pW / 2
	toastPosY = top * scale - pH
	if DB then
		DB.toastX = toastPosX
		DB.toastY = toastPosY
	end
end

local function PlaceToastFrames()
	if InCombatLockdown() then
		return
	end
	local shell = toastShells[toastFitCount] or toastShell
	if not shell then
		return
	end
	shell:ClearAllPoints()
	shell:SetPoint("TOP", UIParent, "TOP", toastPosX, toastPosY)
	if toast then
		local w = ToastWidthForCount(toastFitCount)
		toast:ClearAllPoints()
		toast:SetPoint("TOP", UIParent, "TOP", toastPosX - w / 2 + TOAST_W_MAX / 2, toastPosY)
	end
end

local function LayoutToastButtons(count)
	if InCombatLockdown() or not toast or not toast.rows then
		return
	end
	local n = ToastLogic.ClampSlotCount(count or toastFitCount, TOAST_MAX_SLOTS)
	local shell = toastShells[n] or toastShell
	if not shell then
		return
	end
	-- Anchor to the visible shell so portraits stay centered in the title-min body
	-- even after the toast host was left-aligned at create time.
	local shellW = shell:GetWidth() or ToastWidthForCount(n)
	local left = ToastLogic.SlotLeft(shellW, n, TOAST_SLOT_W)
	for i = 1, TOAST_MAX_SLOTS do
		local btn = toast.rows[i]
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", shell, "TOPLEFT", left + (i - 1) * TOAST_SLOT_W, -(TOAST_HDR_H + 2))
	end
end

local function FitToastShell(count)
	if count then
		toastFitCount = ToastLogic.ClampSlotCount(count, TOAST_MAX_SLOTS)
	end
	local active = toastShells[toastFitCount]
	if not active then
		return
	end
	toastShell = active
	-- Secure click buttons are anchored to the shell, so Show/Hide is combat-protected.
	if InCombatLockdown() then
		return
	end
	for n, shell in pairs(toastShells) do
		if toastWantShown and n == toastFitCount then
			shell:Show()
		else
			shell:Hide()
		end
	end
	LayoutToastButtons(toastFitCount)
	PlaceToastFrames()
end

local function ApplyToastVisibility()
	if InCombatLockdown() then
		return
	end
	if toastWantShown then
		FitToastShell(toastFitCount)
		if toast then
			toast:Show()
		end
	else
		for _, shell in pairs(toastShells) do
			shell:Hide()
		end
		if toast then
			toast:Hide()
		end
	end
end

local function HideClickMarkToast()
	toastWantShown = false
	toastStickyKinds = nil
	toastStickyUntil = 0
	ApplyToastVisibility()
end

local function HideAllPlateIcons()
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if plates then
			for i = 1, #plates do
				HidePlateIcon(plates[i])
			end
		end
	end
	HideClickMarkToast()
end

-- Tracks the last applied context so turning marking off hides icons already on plates.
local contextOpen = false

local function ApplyContextGate()
	local allowed = ContextAllowed()
	if allowed then
		contextOpen = true
		return true
	end
	if contextOpen then
		contextOpen = false
		HideAllPlateIcons()
	end
	return false
end

local function ConfigureToastRowClick(btn, name, icon)
	if InCombatLockdown() or not btn or type(name) ~= "string" or name == "" then
		return
	end
	icon = tonumber(icon)
	if not icon then
		return
	end
	-- A newline or pipe in a name would break or extend the macro.
	name = name:gsub("[\r\n|]", "")
	if name == "" then
		return
	end
	btn:SetAttribute("type", "macro")
	btn:SetAttribute("type1", "macro")
	btn:SetAttribute("*type1", "macro")
	-- /tm !N sets that icon and does not clear it when the unit already has it.
	local macro = string.format("/targetexact %s\n/tm !%d", name, icon)
	btn:SetAttribute("macrotext", macro)
	btn:SetAttribute("macrotext1", macro)
end

local function MakeToastShell(n)
	local name = (n == 1) and "PandiaQuestMarkersToastShell" or ("PandiaQuestMarkersToastShell" .. n)
	local okShell, shellOrErr = pcall(CreateFrame, "Frame", name, UIParent, "BackdropTemplate")
	local shell = (okShell and shellOrErr) or CreateFrame("Frame", name, UIParent)
	if not shell.SetBackdrop and BackdropTemplateMixin then
		Mixin(shell, BackdropTemplateMixin)
		if shell.OnBackdropLoaded then
			shell:OnBackdropLoaded()
		end
	end
	shell:SetPoint("TOP", UIParent, "TOP", toastPosX, toastPosY)
	shell:SetFrameStrata("DIALOG")
	shell:SetMovable(true)
	shell:EnableMouse(true)
	if shell.SetBackdrop then
		shell:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		shell:SetBackdropColor(1, 1, 1, 1)
		shell:SetBackdropBorderColor(1, 1, 1, 1)
	else
		local bg = shell:CreateTexture(nil, "BACKGROUND")
		bg:SetPoint("TOPLEFT", 8, -8)
		bg:SetPoint("BOTTOMRIGHT", -8, 8)
		bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
	end

	-- Classic DialogBox header plaque (hangs on the top edge).
	local header = shell:CreateTexture(nil, "ARTWORK")
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	header:SetSize(256, 64)
	header:SetPoint("TOP", 0, 12)
	shell.header = header

	local title = shell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetJustifyH("CENTER")
	title:SetText(L.CLICK_MARK_TITLE)
	local tw = title:GetStringWidth() or 80
	-- Body min = title + padding + close (+24 edge inset) so X never overlaps the label.
	local minW = ToastLogic.TitleMinWidth(tw, TOAST_TITLE_PAD + 24, TOAST_CLOSE_W, TOAST_W_MIN)
	if minW > TOAST_W_MIN then
		TOAST_W_MIN = minW
		TOAST_W_MAX = math.max(TOAST_W_MAX, TOAST_W_MIN)
	end
	header:SetWidth(math.max(180, math.min(TOAST_W_MIN - 8, tw + TOAST_TITLE_PAD)))
	title:SetPoint("TOP", header, "TOP", 0, -14)
	shell.title = title

	shell:SetSize(ToastWidthForCount(n), TOAST_H)

	-- Drag from the plaque (easy grab; click host stays synced while moving).
	local drag = CreateFrame("Frame", nil, shell)
	drag:SetFrameLevel((shell:GetFrameLevel() or 1) + 5)
	drag:SetPoint("TOPLEFT", header, "TOPLEFT", 24, -10)
	drag:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -24, 18)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function()
		-- Secure click host cannot SetPoint in combat; moving only the shell desyncs chrome from buttons.
		if InCombatLockdown() then
			return
		end
		shell._dragging = true
		shell:StartMoving()
	end)
	drag:SetScript("OnDragStop", function()
		local wasDragging = shell._dragging
		shell._dragging = false
		shell:StopMovingOrSizing()
		if not wasDragging then
			return
		end
		if InCombatLockdown() then
			-- Snap chrome back to last saved spot; toast could not follow.
			PlaceToastFrames()
			return
		end
		CaptureShellPos(shell)
		for _, other in pairs(toastShells) do
			if other ~= shell then
				other:ClearAllPoints()
				other:SetPoint("TOP", UIParent, "TOP", toastPosX, toastPosY)
			end
		end
		PlaceToastFrames()
	end)
	shell:SetScript("OnUpdate", function(self)
		if not self._dragging or InCombatLockdown() or not toast then
			return
		end
		CaptureShellPos(self)
		local sw = ToastWidthForCount(toastFitCount)
		toast:ClearAllPoints()
		toast:SetPoint("TOP", UIParent, "TOP", toastPosX - sw / 2 + TOAST_W_MAX / 2, toastPosY)
	end)

	local close = CreateFrame("Button", nil, shell, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		toastPaused = true
		HideClickMarkToast()
	end)
	shell.close = close
	shell:Hide()
	return shell
end

local function EnsureClickMarkToast()
	if toast and toastShells[1] then
		return toast
	end
	if InCombatLockdown() then
		return nil
	end

	for n = 1, TOAST_MAX_SLOTS do
		toastShells[n] = MakeToastShell(n)
	end
	toastShell = toastShells[1]

	-- Secure host: fixed max size; positioned independently of the shell.
	toast = CreateFrame("Frame", "PandiaQuestMarkersToast", UIParent)
	toast:SetSize(TOAST_W_MAX, TOAST_H)
	toast:SetFrameStrata("DIALOG")
	toast:SetFrameLevel((toastShell:GetFrameLevel() or 1) + 2)
	toast:EnableMouse(false)
	toast:Hide()
	PlaceToastFrames()

	toast.rows = {}
	for i = 1, TOAST_MAX_SLOTS do
		local btn = CreateFrame("Button", nil, toast, "SecureActionButtonTemplate")
		btn:SetSize(TOAST_SLOT_W - 4, TOAST_BODY_H)
		btn:SetPoint("TOPLEFT", 14 + (i - 1) * TOAST_SLOT_W, -(TOAST_HDR_H + 2))
		btn:SetFrameLevel((toast:GetFrameLevel() or 1) + 5)
		btn:RegisterForClicks("LeftButtonUp")
		btn:SetAttribute("type", "macro")
		btn:SetAttribute("checkselfcast", false)
		btn:SetAttribute("checkfocuscast", false)

		local hl = btn:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		hl:SetBlendMode("ADD")
		hl:SetAlpha(0.4)

		local portrait = btn:CreateTexture(nil, "ARTWORK")
		portrait:SetSize(26, 26)
		portrait:SetPoint("TOP", 0, -2)
		btn.portrait = portrait

		local ring = btn:CreateTexture(nil, "OVERLAY")
		ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		ring:SetSize(58, 58)
		ring:SetPoint("CENTER", portrait, "CENTER", 12, -12)

		local mark = btn:CreateTexture(nil, "OVERLAY")
		mark:SetSize(14, 14)
		mark:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 4, -4)
		btn.icon = mark

		local nameFS = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		nameFS:SetPoint("TOP", portrait, "BOTTOM", 0, -2)
		nameFS:SetPoint("LEFT", 2, 0)
		nameFS:SetPoint("RIGHT", -2, 0)
		nameFS:SetJustifyH("CENTER")
		nameFS:SetWordWrap(false)
		btn.nameFS = nameFS

		-- Keep shown always; combat blocks Show/Hide on secure buttons. Alpha toggles slots.
		btn:SetAlpha(0)
		btn:Show()
		toast.rows[i] = btn
	end

	LayoutToastButtons(1)
	return toast
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
			ReleaseIconOnly(victim)
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

local function ToastUnitStillNeeded(token)
	if not token then
		return false
	end
	if RealMarkIndex(token) or UnitLooksDead(token) then
		return false
	end
	return QuestMarkDecision(token).ok and true or false
end

-- anyState: return the unit even when dead, marked, or no longer a quest target.
local function ResolveToastUnit(kind, anyState)
	if not kind or type(kind.name) ~= "string" then
		return nil
	end
	local byGuid = kind.guid and FindUnitByGUID(kind.guid)
	if byGuid and (anyState or ToastUnitStillNeeded(byGuid)) then
		return byGuid
	end
	local function match(unit)
		if UnitNameSafe(unit) ~= kind.name then
			return nil
		end
		if not anyState and not ToastUnitStillNeeded(unit) then
			return nil
		end
		return unit
	end
	local order = { "target", "softenemy", "softfriend", "softinteract", "mouseover" }
	for i = 1, #order do
		local u = match(order[i])
		if u then
			return u
		end
	end
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if plates then
			for i = 1, #plates do
				local plate = plates[i]
				local token = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
				local u = match(token)
				if u then
					return u
				end
			end
		end
	end
	return nil
end

local function ToastUnitSnapshot(unit)
	if type(unit) ~= "string" then
		return nil
	end
	local guid = UnitGUIDSafe(unit)
	if not guid then
		return nil
	end
	local name = UnitNameSafe(unit)
	return {
		name = name,
		guid = guid,
		unit = unit,
		dead = UnitLooksDead(unit),
		marked = RealMarkIndex(unit) and true or false,
		questOk = QuestMarkDecision(unit).ok and true or false,
		suppressed = suppressed[guid] and true or false,
	}
end

-- One row per distinct NPC name among unmarked, alive, quest-needed units in range.
local function CollectToastKinds()
	local units = {}
	local function consider(unit)
		local snap = ToastUnitSnapshot(unit)
		if snap then
			units[#units + 1] = snap
		end
	end
	local order = { "target", "softenemy", "softfriend", "softinteract", "mouseover" }
	for i = 1, #order do
		consider(order[i])
	end
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local plates = C_NamePlate.GetNamePlates()
		if plates then
			for i = 1, #plates do
				local plate = plates[i]
				local token = plate and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
				consider(token)
			end
		end
	end
	local list = ToastLogic.CollectKinds(units)
	AssignToastIcons(list)
	return list
end

-- Sticky only keeps a name if we can still see an unmarked, needed unit with that name.
local function RefreshStickyKinds(kinds)
	local liveByName = {}
	for i = 1, #kinds do
		local kind = kinds[i]
		local unit = ResolveToastUnit(kind, true)
		if unit then
			local snap = ToastUnitSnapshot(unit)
			if snap then
				liveByName[kind.name] = snap
			end
		end
	end
	return ToastLogic.RefreshSticky(kinds, liveByName)
end

local function UpdateActiveTargetToast()
	if not DB or not DB.clickMark or not ContextAllowed() then
		toastPaused = false
		HideClickMarkToast()
		return
	end
	local live = CollectToastKinds()
	local kinds = live
	-- Hold names that left sight until the timer. Drop names we can still see if they are done.
	if toastStickyKinds and GetTime() < toastStickyUntil then
		kinds = ToastLogic.MergeKinds(RefreshStickyKinds(toastStickyKinds), live)
	end
	if #live > 0 then
		toastStickyUntil = GetTime() + TOAST_STICKY_SEC
	end
	AssignToastIcons(kinds)
	if #kinds == 0 then
		toastPaused = false
		toastStickyKinds = nil
		toastStickyUntil = 0
		HideClickMarkToast()
		return
	end
	toastStickyKinds = kinds
	if toastPaused then
		HideClickMarkToast()
		return
	end
	local frame = EnsureClickMarkToast()
	if not frame then
		toastWantShown = true
		return
	end
	local n = #kinds
	if n > TOAST_MAX_SLOTS then
		n = TOAST_MAX_SLOTS
	end
	FitToastShell(n)
	for i = 1, TOAST_MAX_SLOTS do
		local btn = frame.rows[i]
		local kind = kinds[i]
		if kind then
			-- SetAttribute/Show are combat-protected; macros are set out of combat, visibility uses alpha.
			ConfigureToastRowClick(btn, kind.name, kind.icon)
			btn.nameFS:SetText(kind.name)
			if type(SetRaidTargetIconTexture) == "function" then
				pcall(SetRaidTargetIconTexture, btn.icon, kind.icon)
			else
				btn.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. tostring(kind.icon))
			end
			if type(SetPortraitTexture) == "function" then
				pcall(SetPortraitTexture, btn.portrait, kind.unit)
			end
			btn:SetAlpha(1)
		else
			btn:SetAlpha(0)
		end
	end
	toastWantShown = true
	ApplyToastVisibility()
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
	-- Death frees the mark then re-scans the corpse as "new" — never sound/mark dead units.
	if UnitLooksDead(unit) then
		if marks[guid] then
			ReleaseMarkGUID(guid)
		end
		return
	end
	local decision = QuestMarkDecision(unit)
	local real = RealMarkIndex(unit)
	DebugLogSee(unit, guid, source, decision, real)

	-- Real raid marks (Blizzard) can sit on unrelated mobs; log those even when we won't overlay.
	if real then
		SyncManualRaidTarget(unit)
		DebugLogMark(unit, guid, source, real, decision.ok and "real" or "real_unrelated", decision)
		if not decision.ok or suppressed[guid] then
			return
		end
		return
	end

	if not decision.ok then
		-- Tooltip secret/missing: keep heard/sounded. ForgetGUID would re-arm the detect ping.
		if decision.uncertain then
			if marks[guid] then
				marks[guid].unit = unit
				ShowUnitIcon(unit, marks[guid].icon)
				DebugLogMark(unit, guid, source, marks[guid].icon, "hold", decision)
			else
				HideUnitIcon(unit)
			end
			return
		end
		if decision.related then
			DebugLogMark(unit, guid, source, "-", "skip", decision)
		end
		-- Nameplates are recycled: prior overlay/Blizz-slot art can stick on an unrelated
		-- unit with no marks[guid] entry (looks like a raid mark, never logged as MARK).
		local plate = PlateForUnit(unit)
		local _, _, _, blizzIcon = UnitFrameParts(plate)
		local stale = plate
			and (
				(plate.PandiaQuestMark and plate.PandiaQuestMark:IsShown())
				or (blizzIcon and blizzIcon:IsShown())
			)
		if stale and DebugEnabled() and not marks[guid] then
			DebugPrint(
				"CLEAR",
				"stale_plate",
				"name=" .. UnitNameSafe(unit),
				"unit=" .. tostring(unit),
				"source=" .. tostring(source),
				"why=" .. tostring(decision.reason)
			)
		end
		HideUnitIcon(unit)
		if marks[guid] or heard[guid] or suppressed[guid] or lastReal[guid] then
			ForgetGUID(guid)
		end
		return
	end

	-- Manual clear → suppressed.
	if SyncManualRaidTarget(unit) and suppressed[guid] then
		return
	end
	if suppressed[guid] then
		return
	end

	local plate = PlateForUnit(unit)
	if not plate then
		-- No nameplate (gather / distant): sound once; toast via UpdateActiveTargetToast.
		if not heard[guid] and not marks[guid] then
			heard[guid] = true
			PlayDetectSoundOnce(guid, source)
			DebugLogMark(unit, guid, source, "-", "sound_only", decision)
		end
		return
	end

	local icon, isNew = AllocIcon(guid)
	marks[guid].unit = unit
	if isNew then
		heard[guid] = nil
		PlayDetectSoundOnce(guid, source)
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
	UpdateActiveTargetToast()
end

local function SetContextFlag(key, checked)
	DB[key] = checked and true or false
	if ApplyContextGate() then
		ScanVisible()
	end
end

local function ReapStale()
	local drop = {}
	for guid, info in pairs(marks) do
		local unit = FindUnitByGUID(guid) or info.unit
		if unit and UnitGUIDSafe(unit) == guid and not ShouldKeepMark(unit) then
			drop[#drop + 1] = guid
		end
	end
	for i = 1, #drop do
		ForgetGUID(drop[i])
	end
	for guid in pairs(heard) do
		local unit = FindUnitByGUID(guid)
		if unit and not ShouldKeepMark(unit) then
			heard[guid] = nil
		end
	end
	for guid in pairs(suppressed) do
		local unit = FindUnitByGUID(guid)
		if unit and not IsQuestRelated(unit) and not QuestMarkDecision(unit).uncertain then
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
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
	local allowed = ApplyContextGate()
	if event == "PLAYER_REGEN_ENABLED" then
		LayoutToastButtons(toastFitCount)
		PlaceToastFrames()
		ApplyToastVisibility()
		if allowed then
			UpdateActiveTargetToast()
		end
		return
	end
	if not allowed then
		if event == "NAME_PLATE_UNIT_REMOVED" then
			local guid = arg1 and UnitGUIDSafe(arg1)
			if guid and UnitLooksDead(arg1) then
				ReleaseMarkGUID(guid)
			else
				HidePlateForUnitToken(arg1)
			end
		elseif event == "NAME_PLATE_UNIT_ADDED" then
			HidePlateForUnitToken(arg1)
		end
		return
	end
	if event == "RAID_TARGET_UPDATE" then
		SyncAllRaidTargets()
		UpdateActiveTargetToast()
		return
	end
	if event == "NAME_PLATE_UNIT_REMOVED" then
		-- Return icon to the priority pool when the mob dies; keep sticky if only out of range.
		local guid = arg1 and UnitGUIDSafe(arg1)
		if guid and UnitLooksDead(arg1) then
			ReleaseMarkGUID(guid)
		else
			HidePlateForUnitToken(arg1)
		end
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		-- Drop recycled plate art before deciding whether this unit should be marked.
		HidePlateForUnitToken(arg1)
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
	-- World-cursor object checks ride the 0.4s scan (and mouseover), not every frame.
	if not ApplyContextGate() then
		return
	end
	accum = accum + dt
	if accum < 0.4 then
		return
	end
	accum = 0
	ReleaseDeadMarks()
	ScanVisible()
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
	widgets.clickMark:SetChecked(DB.clickMark)
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

local function AddCheckRow(parent, y, labelText, onClick, labelW, controlX)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 6)
	label:SetWidth(labelW)
	label:SetWordWrap(false)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", controlX, y)
	check:SetScript("OnClick", onClick)
	return check, y - 32
end

local function AddChoiceDropdown(parent, y, labelText, keys, getKey, setKey, labelFn, labelW, controlX)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 4)
	label:SetWidth(labelW)
	label:SetWordWrap(false)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)

	if HasWowDropdown() then
		local drop = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
		drop:SetPoint("TOPLEFT", controlX, y)
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
	btn:SetPoint("TOPLEFT", controlX, y)
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

local function AddMultiCheckboxDropdown(parent, y, labelText, keys, labelFn, isOn, setOn, summaryFn, labelW, controlX)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 4)
	label:SetWidth(labelW)
	label:SetWordWrap(false)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)

	if HasWowDropdown() then
		local drop = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
		drop:SetPoint("TOPLEFT", controlX, y)
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
	btn:SetPoint("TOPLEFT", controlX, y)
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
	local labelW = 240
	do
		local probe = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		local widest = 0
		local texts = { L.CLICK_MARK, L.SOUND_ENABLE, L.SOUND_WHEN, L.SOUND, L.SOUND_CHANNEL, L.DEBUG }
		for i = 1, #texts do
			probe:SetText(texts[i])
			local sw = probe:GetStringWidth() or 0
			if sw > widest then
				widest = sw
			end
		end
		probe:Hide()
		if widest > 1 then
			labelW = math.ceil(widest + 8)
		end
	end
	local controlX = 16 + labelW + 12
	y = AddSectionHeader(canvas, y, L.SECTION_CONTEXT)
	widgets.solo = AddLabeledCheck(canvas, 16, y, L.CTX_SOLO, function(self)
		SetContextFlag("solo", self:GetChecked())
	end)
	widgets.group = AddLabeledCheck(canvas, 140, y, L.CTX_GROUP, function(self)
		SetContextFlag("group", self:GetChecked())
	end)
	widgets.raid = AddLabeledCheck(canvas, 264, y, L.CTX_RAID, function(self)
		SetContextFlag("raid", self:GetChecked())
	end)
	widgets.pvp = AddLabeledCheck(canvas, 388, y, L.CTX_PVP, function(self)
		SetContextFlag("pvp", self:GetChecked())
	end)
	y = y - 36
	widgets.clickMark, y = AddCheckRow(canvas, y, L.CLICK_MARK, function(self)
		DB.clickMark = self:GetChecked() and true or false
		if not DB.clickMark then
			HideClickMarkToast()
		end
	end, labelW, controlX)

	y = AddSectionHeader(canvas, y, L.SECTION_SOUND)
	widgets.sound, y = AddCheckRow(canvas, y, L.SOUND_ENABLE, function(self)
		DB.sound = self:GetChecked() and true or false
	end, labelW, controlX)
	widgets.soundWhen, y = AddMultiCheckboxDropdown(canvas, y, L.SOUND_WHEN, SOUND_WHEN_KEYS, function(key)
		return SOUND_WHEN_LABEL[key]()
	end, function(key)
		DB.soundWhen = DB.soundWhen or Defaults().soundWhen
		return DB.soundWhen[key] and true or false
	end, function(key, on)
		DB.soundWhen = DB.soundWhen or Defaults().soundWhen
		DB.soundWhen[key] = on and true or false
	end, SoundWhenSummary, labelW, controlX)

	local soundY = y
	widgets.soundKey, y = AddChoiceDropdown(canvas, y, L.SOUND, SOUND_KEYS, function()
		return SOUND_ID[DB.soundKey] and DB.soundKey or "friend"
	end, function(key)
		DB.soundKey = key
	end, function(key)
		return SOUND_LABEL[key]()
	end, labelW, controlX)
	local preview = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	preview:SetSize(90, 22)
	preview:SetPoint("TOPLEFT", controlX + 188, soundY)
	preview:SetText(L.SOUND_PREVIEW)
	preview:SetScript("OnClick", PlayConfiguredSound)
	widgets.soundPreview = preview

	widgets.soundChannel, y = AddChoiceDropdown(canvas, y, L.SOUND_CHANNEL, CHANNELS, function()
		return CHANNEL_LABEL[DB.soundChannel] and DB.soundChannel or "SFX"
	end, function(key)
		DB.soundChannel = key
	end, function(key)
		return CHANNEL_LABEL[key]()
	end, labelW, controlX)

	y = y - 8
	widgets.debug, y = AddCheckRow(canvas, y, L.DEBUG, function(self)
		DB.debug = self:GetChecked() and true or false
		if DB.debug then
			DebugPrint("debug logging enabled")
		end
	end, labelW, controlX)

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
	if type(DB.toastX) == "number" then
		toastPosX = DB.toastX
	end
	if type(DB.toastY) == "number" then
		toastPosY = DB.toastY
	end
	-- Build secure toast out of combat so later Show/Hide only toggles visibility.
	EnsureClickMarkToast()
	C_Timer.After(0, RegisterOptions)
	loader:UnregisterEvent("ADDON_LOADED")
end)
