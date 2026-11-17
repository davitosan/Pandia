-- Persist chat history (non–Combat Log): line-capped, LibDeflate-compressed.

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
local sessionBreakDone = false

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

-- Visible divider after restored history and before this session's live chat.
local function InjectSessionBreak()
	if sessionBreakDone then
		return
	end
	sessionBreakDone = true
	local L = PandiaChatLocale
	local text = (L and L.SESSION_BREAK) or "———— Session ————"
	local stamp = FormatClientTimestamp(time())
	if stamp ~= "" then
		text = stamp .. text
	end
	local r, g, b = 0.55, 0.55, 0.55
	local n = NUM_CHAT_WINDOWS or 10
	for i = 1, n do
		local frame = _G["ChatFrame" .. i]
		if frame and not IsCombatLogFrame(frame) then
			HookFrame(frame)
			-- Save into history so later restores keep session boundaries.
			restoring = true
			CallOrig(frame, text, r, g, b)
			restoring = false
			Append(frame, text, r, g, b)
		end
	end
end

function M.Init(dbGetter)
	getDB = dbGetter
	EnsureLib()
end

function M.OnAddonLoaded()
	LoadBuffersFromStore()
	M.HookAll()
end

function M.OnLogin()
	sessionBreakDone = false
	M.HookAll()
	M.Restore()
	C_Timer.After(0, InjectSessionBreak)
end

function M.OnLogout()
	M.Flush()
end

function M.OnChatWindowsUpdate()
	M.HookAll()
end
