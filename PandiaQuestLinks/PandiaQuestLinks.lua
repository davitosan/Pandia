-- Appends local quest status after |Hquest: links in chat.

local L = PandiaQuestLinksLocale
local DB

local STATE_ORDER = { "failed", "ready", "onQuest", "completed", "none" }
local STATE_LABEL = {
	failed = function() return L.LABEL_FAILED end,
	ready = function() return L.LABEL_READY end,
	onQuest = function() return L.LABEL_ON_QUEST end,
	completed = function() return L.LABEL_COMPLETED end,
	none = function() return L.LABEL_NONE end,
}
local STATE_DEFAULT_TEXT = {
	failed = function() return L.FAILED end,
	ready = function() return L.READY end,
	onQuest = function() return L.ON_QUEST end,
	completed = function() return L.COMPLETED end,
	none = function() return L.NONE end,
}
local STATE_DEFAULT_COLOR = {
	failed = "ff2020",
	ready = "40ff40",
	onQuest = "ffff00",
	completed = "9d9d9d",
	none = "808080",
}

local function Defaults()
	local t = {}
	for _, key in ipairs(STATE_ORDER) do
		t[key] = {
			enabled = key ~= "none",
			text = STATE_DEFAULT_TEXT[key](),
			color = STATE_DEFAULT_COLOR[key],
		}
	end
	return t
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

local function HexOK(hex)
	return type(hex) == "string" and hex:match("^%x%x%x%x%x%x$") ~= nil
end

local function HexToRGB(hex)
	hex = HexOK(hex) and hex or "ffffff"
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function RGBToHex(r, g, b)
	return string.format("%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
end

local function FormatStatus(key)
	local s = DB[key]
	if not s or not s.enabled then
		return nil
	end
	local text = s.text
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local color = HexOK(s.color) and s.color or STATE_DEFAULT_COLOR[key]
	return "|cff" .. color .. "(" .. text .. ")|r"
end

local RefreshCanvas

local function SetSwatchColor(swatch, hex)
	local r, g, b = HexToRGB(hex)
	if swatch.SetColorRGB then
		swatch:SetColorRGB(r, g, b)
	elseif swatch.GetNormalTexture and swatch:GetNormalTexture() then
		swatch:GetNormalTexture():SetVertexColor(r, g, b)
	elseif swatch.tex then
		swatch.tex:SetVertexColor(r, g, b)
	end
end

local function OpenColorPicker(key, swatch)
	local r, g, b = HexToRGB(DB[key].color)
	local function apply(nr, ng, nb)
		DB[key].color = RGBToHex(nr, ng, nb)
		SetSwatchColor(swatch, DB[key].color)
		RefreshCanvas()
	end
	if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r,
			g = g,
			b = b,
			hasOpacity = false,
			swatchFunc = function()
				apply(ColorPickerFrame:GetColorRGB())
			end,
			cancelFunc = function(prev)
				if prev then
					apply(prev.r or r, prev.g or g, prev.b or b)
				end
			end,
		})
		return
	end
	-- Legacy ColorPickerFrame
	ColorPickerFrame.func = function()
		apply(ColorPickerFrame:GetColorRGB())
	end
	ColorPickerFrame.cancelFunc = function(prev)
		if type(prev) == "table" then
			apply(prev.r, prev.g, prev.b)
		end
	end
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Show()
end

local function Annotate(questID)
	if C_QuestLog.IsOnQuest(questID) then
		if C_QuestLog.IsFailed(questID) then
			return FormatStatus("failed")
		end
		if C_QuestLog.IsComplete(questID) then
			return FormatStatus("ready")
		end
		return FormatStatus("onQuest")
	end
	if C_QuestLog.IsQuestFlaggedCompleted(questID) then
		return FormatStatus("completed")
	end
	return FormatStatus("none")
end

local function Filter(_, _, msg, ...)
	local newMsg = msg:gsub("(|Hquest:(%d+)[^|]*|h%b[]|h)(|r?)", function(link, questID, trailing)
		local status = Annotate(tonumber(questID))
		return status and (link .. trailing .. status) or (link .. trailing)
	end)
	if newMsg ~= msg then
		return false, newMsg, ...
	end
end

for _, event in ipairs({
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
}) do
	ChatFrameUtil.AddMessageEventFilter(event, Filter)
end

-- Settings canvas (Esc > Options > AddOns) ----------------------------------

local canvas
local rows = {}

function RefreshCanvas()
	if not canvas then
		return
	end
	for key, row in pairs(rows) do
		local s = DB[key]
		row.check:SetChecked(s.enabled)
		row.text:SetText(s.text or "")
		SetSwatchColor(row.swatch, s.color or STATE_DEFAULT_COLOR[key])
		row.preview:SetText(FormatStatus(key) or ("|cff808080(" .. STATE_LABEL[key]() .. ")|r"))
	end
end

local function BuildCanvas()
	canvas = CreateFrame("Frame")
	canvas:Hide()
	canvas:SetScript("OnShow", RefreshCanvas)

	local hdrY = -16
	local h1 = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	h1:SetPoint("TOPLEFT", 120, hdrY)
	h1:SetText(L.COL_ENABLE)
	local h2 = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	h2:SetPoint("TOPLEFT", 160, hdrY)
	h2:SetText(L.COL_TEXT)
	local h3 = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	h3:SetPoint("TOPLEFT", 360, hdrY)
	h3:SetText(L.COL_COLOR)

	local y = -36
	for _, key in ipairs(STATE_ORDER) do
		local row = {}
		local label = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		label:SetPoint("TOPLEFT", 16, y - 6)
		label:SetWidth(100)
		label:SetJustifyH("LEFT")
		label:SetText(STATE_LABEL[key]())

		row.check = CreateFrame("CheckButton", nil, canvas, "UICheckButtonTemplate")
		row.check:SetPoint("TOPLEFT", 118, y)
		row.check:SetScript("OnClick", function(self)
			DB[key].enabled = self:GetChecked() and true or false
			RefreshCanvas()
		end)

		row.text = CreateFrame("EditBox", nil, canvas, "InputBoxTemplate")
		row.text:SetSize(180, 20)
		row.text:SetPoint("TOPLEFT", 160, y - 2)
		row.text:SetAutoFocus(false)
		row.text:SetScript("OnEnterPressed", function(self)
			DB[key].text = self:GetText() or ""
			self:ClearFocus()
			RefreshCanvas()
		end)
		row.text:SetScript("OnEditFocusLost", function(self)
			DB[key].text = self:GetText() or ""
			RefreshCanvas()
		end)

		local swatch = CreateFrame("Button", nil, canvas, "ColorSwatchTemplate")
		if not swatch.SetColorRGB then
			swatch = CreateFrame("Button", nil, canvas)
			swatch:SetSize(24, 24)
			local tex = swatch:CreateTexture(nil, "OVERLAY")
			tex:SetAllPoints()
			tex:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
			swatch.tex = tex
		end
		swatch:SetPoint("TOPLEFT", 360, y)
		swatch:SetScript("OnClick", function(self)
			OpenColorPicker(key, self)
		end)
		row.swatch = swatch

		row.preview = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.preview:SetPoint("TOPLEFT", 400, y - 4)
		row.preview:SetWidth(160)
		row.preview:SetJustifyH("LEFT")

		rows[key] = row
		y = y - 42
	end

	local reset = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	reset:SetSize(120, 22)
	reset:SetPoint("TOPLEFT", 16, y - 8)
	reset:SetText(L.RESET)
	reset:SetScript("OnClick", function()
		wipe(PandiaQuestLinksDB)
		CopyDefaults(PandiaQuestLinksDB, Defaults())
		DB = PandiaQuestLinksDB
		RefreshCanvas()
	end)

	return canvas
end

local function RegisterOptions()
	local frame = BuildCanvas()
	local category = Settings.RegisterCanvasLayoutCategory(frame, L.OPTIONS_TITLE)
	Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
	if name ~= "PandiaQuestLinks" then
		return
	end
	PandiaQuestLinksDB = PandiaQuestLinksDB or {}
	CopyDefaults(PandiaQuestLinksDB, Defaults())
	DB = PandiaQuestLinksDB
	RegisterOptions()
	loader:UnregisterEvent("ADDON_LOADED")
end)
