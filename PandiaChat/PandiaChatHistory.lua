-- Persist chat history (non–Combat Log): line-capped, LibDeflate-compressed.
-- Optional guild gap-fill via C_Club while the player was logged off.

PandiaChatHistory = PandiaChatHistory or {}
local M = PandiaChatHistory

local HISTORY_VERSION = 1
local CAP_MIN, CAP_MAX = 50, 1000
local CAP_DEFAULT = 200

local LibDeflate
local buffers = {} -- [frameName] = { {t=,r=,g=,b=}, ... }
local origAddMessage = {} -- [frame] = function
local hooked = {}
local restoring = false
local getDB
local lastLogoutTime = 0
-- Unix seconds when this session started; club inject stops here so live chat is not duplicated.
local sessionStartTime = 0
local guildPending = false
-- messageId keys already injected this session (club content text is not reliable for dedupe).
local guildInjected = {}

local function DB()
	return getDB and getDB() or nil
end

local function Cap()
	local db = DB()
	local n = db and tonumber(db.historyCap) or CAP_DEFAULT
	if n < CAP_MIN then
		return CAP_MIN
	elseif n > CAP_MAX then
		return CAP_MAX
	end
	return math.floor(n + 0.5)
end

function M.CapBounds()
	return CAP_MIN, CAP_MAX, CAP_DEFAULT
end

local function IsCombatLogFrame(frame)
	if not frame then
		return true
	end
	if frame.isCombatLog then
		return true
	end
	if type(ChatFrame_IsCombatLog) == "function" then
		local ok, isCL = pcall(ChatFrame_IsCombatLog, frame)
		if ok and isCL then
			return true
		end
	end
	if frame == ChatFrame2 then
		return true
	end
	return false
end

local function FrameShowsGuild(frame)
	if not frame then
		return false
	end
	if type(ChatFrame_ContainsMessageGroup) == "function" then
		local ok, has = pcall(ChatFrame_ContainsMessageGroup, frame, "GUILD")
		if ok then
			return has and true or false
		end
	end
	if frame.messageTypeList then
		for _, chatType in pairs(frame.messageTypeList) do
			if chatType == "GUILD" then
				return true
			end
		end
	end
	-- Fallback: default General window usually shows guild.
	return frame == DEFAULT_CHAT_FRAME
end

local function TrimList(list, cap)
	while #list > cap do
		table.remove(list, 1)
	end
end

local function Escape(s)
	return (tostring(s or ""):gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"))
end

local function Unescape(s)
	s = tostring(s or "")
	local out = {}
	local i = 1
	while i <= #s do
		local c = s:sub(i, i)
		if c == "\\" and i < #s then
			local n = s:sub(i + 1, i + 1)
			if n == "n" then
				out[#out + 1] = "\n"
			elseif n == "r" then
				out[#out + 1] = "\r"
			elseif n == "t" then
				out[#out + 1] = "\t"
			elseif n == "\\" then
				out[#out + 1] = "\\"
			else
				out[#out + 1] = n
			end
			i = i + 2
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
	return table.concat(out)
end

local function SerializeBuffers()
	local parts = { "V" .. HISTORY_VERSION }
	for name, list in pairs(buffers) do
		parts[#parts + 1] = "#" .. name
		for i = 1, #list do
			local e = list[i]
			parts[#parts + 1] = string.format(
				"%.4f\t%.4f\t%.4f\t%s",
				tonumber(e.r) or 1,
				tonumber(e.g) or 1,
				tonumber(e.b) or 1,
				Escape(e.t)
			)
		end
	end
	return table.concat(parts, "\n")
end

local function Deserialize(str)
	local out = {}
	local cur
	if type(str) ~= "string" or str == "" then
		return out
	end
	for line in (str .. "\n"):gmatch("(.-)\n") do
		if line:sub(1, 1) == "V" then
			-- version marker
		elseif line:sub(1, 1) == "#" then
			cur = line:sub(2)
			out[cur] = out[cur] or {}
		elseif cur and line ~= "" then
			local r, g, b, text = line:match("^([%d%.]+)\t([%d%.]+)\t([%d%.]+)\t(.*)$")
			if r and text then
				local list = out[cur]
				list[#list + 1] = {
					t = Unescape(text),
					r = tonumber(r) or 1,
					g = tonumber(g) or 1,
					b = tonumber(b) or 1,
				}
			end
		end
	end
	return out
end

local function EnsureLib()
	if LibDeflate then
		return true
	end
	if LibStub then
		local ok, lib = pcall(function()
			return LibStub:GetLibrary("LibDeflate")
		end)
		if ok and lib then
			LibDeflate = lib
			return true
		end
	end
	return false
end

local function HistoryStore()
	local db = DB()
	if not db then
		return nil
	end
	if db.historyShared then
		db.sharedHistory = db.sharedHistory or { version = HISTORY_VERSION, blob = "" }
		return db.sharedHistory
	end
	PandiaChatHistoryDB = PandiaChatHistoryDB or { version = HISTORY_VERSION, blob = "" }
	return PandiaChatHistoryDB
end

function M.Flush()
	local db = DB()
	if not db or not db.historyEnabled then
		return
	end
	if not EnsureLib() then
		return
	end
	local raw = SerializeBuffers()
	local compressed = LibDeflate:CompressDeflate(raw)
	if not compressed then
		return
	end
	local encoded = LibDeflate:EncodeForPrint(compressed)
	local store = HistoryStore()
	if store then
		store.version = HISTORY_VERSION
		store.blob = encoded or ""
	end
end

local function LoadBuffersFromStore()
	buffers = {}
	local db = DB()
	if not db or not db.historyEnabled then
		return
	end
	if not EnsureLib() then
		return
	end
	local store = HistoryStore()
	local blob = store and store.blob
	if type(blob) ~= "string" or blob == "" then
		return
	end
	local compressed = LibDeflate:DecodeForPrint(blob)
	if not compressed then
		return
	end
	local raw = LibDeflate:DecompressDeflate(compressed)
	if type(raw) ~= "string" then
		return
	end
	buffers = Deserialize(raw)
	local cap = Cap()
	for _, list in pairs(buffers) do
		TrimList(list, cap)
	end
end

local function Append(frame, text, r, g, b)
	if restoring or not text or text == "" then
		return
	end
	local db = DB()
	if not db or not db.historyEnabled then
		return
	end
	if IsCombatLogFrame(frame) then
		return
	end
	local name = frame:GetName()
	if not name then
		return
	end
	local list = buffers[name]
	if not list then
		list = {}
		buffers[name] = list
	end
	list[#list + 1] = {
		t = text,
		r = tonumber(r) or 1,
		g = tonumber(g) or 1,
		b = tonumber(b) or 1,
	}
	TrimList(list, Cap())
end

local function HookFrame(frame)
	if not frame or hooked[frame] or IsCombatLogFrame(frame) then
		return
	end
	if type(frame.AddMessage) ~= "function" then
		return
	end
	origAddMessage[frame] = frame.AddMessage
	frame.AddMessage = function(self, text, r, g, b, ...)
		Append(self, text, r, g, b)
		return origAddMessage[self](self, text, r, g, b, ...)
	end
	hooked[frame] = true
end

function M.HookAll()
	local n = NUM_CHAT_WINDOWS or 10
	for i = 1, n do
		HookFrame(_G["ChatFrame" .. i])
	end
end

local function CallOrig(frame, text, r, g, b)
	local fn = origAddMessage[frame] or (frame and frame.AddMessage)
	if fn then
		fn(frame, text, r, g, b)
	end
end

function M.Restore()
	local db = DB()
	if not db or not db.historyEnabled then
		return
	end
	restoring = true
	for name, list in pairs(buffers) do
		local frame = _G[name]
		if frame and not IsCombatLogFrame(frame) then
			HookFrame(frame)
			for i = 1, #list do
				local e = list[i]
				CallOrig(frame, e.t, e.r, e.g, e.b)
			end
		end
	end
	restoring = false
end

function M.TrimToCap()
	local cap = Cap()
	for _, list in pairs(buffers) do
		TrimList(list, cap)
	end
	M.Flush()
end

function M.Clear()
	buffers = {}
	local db = DB()
	if db then
		if db.historyShared then
			db.sharedHistory = { version = HISTORY_VERSION, blob = "" }
		else
			PandiaChatHistoryDB = { version = HISTORY_VERSION, blob = "" }
		end
	end
end

local function SafeName(author)
	if not author then
		return "?"
	end
	local n = author.name
	if type(issecretvalue) == "function" and issecretvalue(n) then
		return "?"
	end
	if type(n) == "string" and n ~= "" and not n:find("|K", 1, true) then
		return n
	end
	return "?"
end

-- Club content is a protected kstring. Forever often surfaces unreadable bodies as "Unknown".
local function SafeContent(msg)
	if not msg then
		return nil
	end
	local c = msg.content
	if type(issecretvalue) == "function" and issecretvalue(c) then
		return nil
	end
	if type(c) ~= "string" or c == "" then
		return nil
	end
	if c == "Unknown" or c:find("|K", 1, true) then
		return nil
	end
	return c
end

local function MessageIdKey(msg)
	local id = msg and msg.messageId
	if not id then
		return nil
	end
	local epoch, pos = id.epoch, id.position
	if type(epoch) ~= "number" then
		return nil
	end
	return tostring(epoch) .. ":" .. tostring(pos or 0)
end

local function GuildLineColor()
	local info = ChatTypeInfo and ChatTypeInfo.GUILD
	if info then
		return info.r or 0.25, info.g or 1, info.b or 0.25
	end
	return 0.25, 1, 0.25
end

-- Same path stock chat uses: GetChatTimestampFormat / CHAT_TIMESTAMP_FORMAT + BetterDate.
local function ClientTimestampFormat()
	if type(GetChatTimestampFormat) == "function" then
		local ok, fmt = pcall(GetChatTimestampFormat)
		if ok and type(fmt) == "string" and fmt ~= "" and fmt ~= "none" then
			return fmt
		end
	end
	if ChatFrameUtil and type(ChatFrameUtil.GetTimestampFormat) == "function" then
		local ok, fmt = pcall(ChatFrameUtil.GetTimestampFormat)
		if ok and type(fmt) == "string" and fmt ~= "" and fmt ~= "none" then
			return fmt
		end
	end
	local fmt = _G.CHAT_TIMESTAMP_FORMAT
	if type(fmt) == "string" and fmt ~= "" and fmt ~= "none" then
		return fmt
	end
	if C_CVar and C_CVar.GetCVar then
		local ok, cvar = pcall(C_CVar.GetCVar, "showTimestamps")
		if ok and type(cvar) == "string" and cvar ~= "" and cvar ~= "none" then
			return cvar
		end
	end
	return nil
end

local function FormatClientTimestamp(unixSec)
	unixSec = tonumber(unixSec)
	if not unixSec then
		return ""
	end
	local fmt = ClientTimestampFormat()
	if not fmt then
		return ""
	end
	local better = (TimeUtil and TimeUtil.BetterDate) or BetterDate
	if type(better) ~= "function" then
		return ""
	end
	local ok, stamp = pcall(better, fmt, unixSec)
	if ok and type(stamp) == "string" then
		return stamp
	end
	return ""
end

-- ClubMessageIdentifier.epoch is microseconds since the UNIX epoch.
local function MessageUnixSeconds(msg)
	local id = msg and msg.messageId
	local epoch = id and id.epoch
	if type(epoch) ~= "number" then
		return nil
	end
	return math.floor(epoch / 1e6)
end

local function FormatGuildLine(msg)
	local body = SafeContent(msg)
	if not body then
		return nil
	end
	local name = SafeName(msg.author)
	local tag = _G.GUILD or "Guild"
	local line = string.format("[%s] %s: %s", tag, name, body)
	local stamp = FormatClientTimestamp(MessageUnixSeconds(msg))
	if stamp ~= "" then
		-- Stock chat concatenates with no extra space; the format string includes spacing.
		line = stamp .. line
	end
	return line
end

local function BufferHasText(text)
	for _, list in pairs(buffers) do
		for i = 1, #list do
			if list[i].t == text then
				return true
			end
		end
	end
	return false
end

local function InjectGuildLine(msg)
	local key = MessageIdKey(msg)
	if key and guildInjected[key] then
		return
	end
	local text = FormatGuildLine(msg)
	if not text or BufferHasText(text) then
		return
	end
	if key then
		guildInjected[key] = true
	end
	local r, g, b = GuildLineColor()
	local n = NUM_CHAT_WINDOWS or 10
	for i = 1, n do
		local frame = _G["ChatFrame" .. i]
		if frame and not IsCombatLogFrame(frame) and FrameShowsGuild(frame) then
			HookFrame(frame)
			restoring = true
			CallOrig(frame, text, r, g, b)
			restoring = false
			Append(frame, text, r, g, b)
		end
	end
end

local function FindGuildStream()
	if not C_Club or not C_Club.GetGuildClubId or not C_Club.GetStreams then
		return nil
	end
	local ok, clubId = pcall(C_Club.GetGuildClubId)
	if not ok or not clubId then
		return nil
	end
	local okS, streams = pcall(C_Club.GetStreams, clubId)
	if not okS or type(streams) ~= "table" then
		return nil
	end
	local guildType = Enum and Enum.ClubStreamType and Enum.ClubStreamType.Guild
	for i = 1, #streams do
		local s = streams[i]
		if s and (s.streamType == guildType or s.streamType == 1) then
			return clubId, s.streamId
		end
	end
	if streams[1] then
		return clubId, streams[1].streamId
	end
	return nil
end

local function PullGuildMessages(clubId, streamId)
	if not C_Club.GetMessagesBefore and not C_Club.GetMessageRanges then
		return
	end
	local messages
	if C_Club.GetMessageRanges and C_Club.GetMessagesInRange then
		local okR, ranges = pcall(C_Club.GetMessageRanges, clubId, streamId)
		if okR and ranges and ranges[1] then
			local oldest = ranges[1].oldestMessageId
			local newest = ranges[1].newestMessageId
			if oldest and newest then
				local okM, msgs = pcall(C_Club.GetMessagesInRange, clubId, streamId, oldest, newest)
				if okM then
					messages = msgs
				end
			end
		end
	end
	if (not messages or #messages == 0) and C_Club.GetMessagesBefore then
		-- newest-first window of recent history
		local okB, msgs = pcall(C_Club.GetMessagesBefore, clubId, streamId, nil, Cap())
		if okB then
			messages = msgs
		end
	end
	if type(messages) ~= "table" then
		return
	end
	-- Sort oldest → newest by epoch
	local ordered = {}
	for _, msg in pairs(messages) do
		if msg and not msg.destroyed and msg.messageId then
			ordered[#ordered + 1] = msg
		end
	end
	table.sort(ordered, function(a, b)
		local ae = a.messageId.epoch or 0
		local be = b.messageId.epoch or 0
		if ae == be then
			return (a.messageId.position or 0) < (b.messageId.position or 0)
		end
		return ae < be
	end)
	-- Only the offline gap: after last logout, before this session. Live CHAT_MSG_GUILD covers the rest.
	local cutoff = lastLogoutTime > 0 and lastLogoutTime or 0
	local untilSec = sessionStartTime > 0 and sessionStartTime or time()
	for i = 1, #ordered do
		local msg = ordered[i]
		local sec = (msg.messageId.epoch or 0) / 1e6
		if sec >= cutoff and sec < untilSec then
			InjectGuildLine(msg)
		end
	end
	M.Flush()
end

function M.RequestGuildBackfill()
	local db = DB()
	if not db or not db.historyEnabled or not db.historyGuildBackfill then
		return
	end
	local clubId, streamId = FindGuildStream()
	if not clubId or not streamId then
		return
	end
	guildPending = true
	if C_Club.RequestMoreMessagesBefore then
		pcall(C_Club.RequestMoreMessagesBefore, clubId, streamId, nil, Cap())
	end
	-- Also try immediately in case history is already local.
	C_Timer.After(0.5, function()
		PullGuildMessages(clubId, streamId)
		guildPending = false
	end)
end

local guildEvents = CreateFrame("Frame")
guildEvents:RegisterEvent("CLUB_MESSAGE_HISTORY_RECEIVED")
guildEvents:SetScript("OnEvent", function(_, _, clubId, streamId)
	-- Only the login RequestMoreMessagesBefore response — not every mid-session club sync.
	if not guildPending then
		return
	end
	local db = DB()
	if not db or not db.historyGuildBackfill then
		return
	end
	local gClub, gStream = FindGuildStream()
	if clubId == gClub and streamId == gStream then
		PullGuildMessages(clubId, streamId)
	end
end)

function M.Init(dbGetter)
	getDB = dbGetter
	EnsureLib()
end

function M.OnAddonLoaded()
	local db = DB()
	if db and db.lastLogoutTime then
		lastLogoutTime = tonumber(db.lastLogoutTime) or 0
	end
	LoadBuffersFromStore()
	M.HookAll()
end

function M.OnLogin()
	sessionStartTime = time()
	guildInjected = {}
	M.HookAll()
	M.Restore()
	C_Timer.After(1, function()
		M.RequestGuildBackfill()
	end)
end

function M.OnLogout()
	local db = DB()
	if db then
		db.lastLogoutTime = time()
		lastLogoutTime = db.lastLogoutTime
	end
	M.Flush()
end

function M.OnChatWindowsUpdate()
	M.HookAll()
end
