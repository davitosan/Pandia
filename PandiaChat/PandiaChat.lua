-- Chat APIs with no Esc Options / chat-tab right-click UI.
-- Skips stock-covered settings: font size, background color/opacity.

local L = PandiaChatLocale
local DB

local OUTLINE_ORDER = { "", "THINOUTLINE", "OUTLINE", "THICKOUTLINE" }
local OUTLINE_LABEL = {
	[""] = function() return L.OUTLINE_NONE end,
	THINOUTLINE = function() return L.OUTLINE_THIN end,
	OUTLINE = function() return L.OUTLINE_NORMAL end,
	THICKOUTLINE = function() return L.OUTLINE_THICK end,
}

local SHADOW_OFFSET_MIN = -5
local SHADOW_OFFSET_MAX = 5
local TIME_VISIBLE_MIN, TIME_VISIBLE_MAX = 0, 600
local FADE_DURATION_MIN, FADE_DURATION_MAX = 0, 30
local MAX_LINES_MIN, MAX_LINES_MAX = 128, 5000
local HISTORY_CAP_MIN, HISTORY_CAP_MAX, HISTORY_CAP_DEFAULT = PandiaChatHistory.CapBounds()

local STICKY_KEYS = {
	"SAY",
	"PARTY",
	"RAID",
	"INSTANCE_CHAT",
	"GUILD",
	"OFFICER",
	"WHISPER",
	"CHANNEL",
}
local STICKY_LABEL = {
	SAY = function() return L.STICKY_SAY end,
	PARTY = function() return L.STICKY_PARTY end,
	RAID = function() return L.STICKY_RAID end,
	INSTANCE_CHAT = function() return L.STICKY_INSTANCE end,
	GUILD = function() return L.STICKY_GUILD end,
	OFFICER = function() return L.STICKY_OFFICER end,
	WHISPER = function() return L.STICKY_WHISPER end,
	CHANNEL = function() return L.STICKY_CHANNEL end,
}

local FONT_ORDER = { "", "friz", "arial", "morpheus", "skurri", "custom" }
local FONT_PATH = {
	friz = "Fonts\\FRIZQT__.TTF",
	arial = "Fonts\\ARIALN.TTF",
	morpheus = "Fonts\\MORPHEUS.TTF",
	skurri = "Fonts\\SKURRI.TTF",
}
local FONT_LABEL = {
	[""] = function() return L.FONT_DEFAULT end,
	friz = function() return "Friz Quadrata" end,
	arial = function() return "Arial Narrow" end,
	morpheus = function() return "Morpheus" end,
	skurri = function() return "Skurri" end,
	custom = function() return L.FONT_CUSTOM end,
}

-- Session: avoid SetMaxLines on login when the saved value was already applied last session.
local lastAppliedMaxLines

local function Defaults()
	return {
		enabled = true,
		outline = "OUTLINE",
		shadow = true,
		shadowX = 1,
		shadowY = -1,
		shadowR = 0,
		shadowG = 0,
		shadowB = 0,
		shadowA = 1,
		editBox = true,
		fontId = "",
		fontCustomPath = "",
		fading = true,
		timeVisible = 120,
		fadeDuration = 3,
		clampToEdge = false,
		insertMode = "BOTTOM",
		maxLinesEnabled = false,
		maxLines = 500,
		sticky = {},
		hideButtons = false,
		historyEnabled = true,
		historyCap = HISTORY_CAP_DEFAULT,
		historyShared = false,
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

local function Clamp(n, lo, hi)
	n = tonumber(n)
	if not n then
		return lo
	end
	if n < lo then
		return lo
	elseif n > hi then
		return hi
	end
	return n
end

local function ClampOffset(n)
	return Clamp(n, SHADOW_OFFSET_MIN, SHADOW_OFFSET_MAX)
end

local function SeedSticky(dst)
	dst.sticky = dst.sticky or {}
	for i = 1, #STICKY_KEYS do
		local key = STICKY_KEYS[i]
		if dst.sticky[key] == nil then
			local info = ChatTypeInfo and ChatTypeInfo[key]
			dst.sticky[key] = info and info.sticky == 1 and true or false
		end
	end
end

local function ResolveFontPath()
	if not DB then
		return nil
	end
	local id = DB.fontId or ""
	if id == "" then
		return nil
	end
	if id == "custom" then
		local path = DB.fontCustomPath
		if type(path) == "string" and path ~= "" then
			return path
		end
		return nil
	end
	return FONT_PATH[id]
end

local function StyleFontObject(obj, fontPath, flags, ox, oy, r, g, b, a)
	if not obj or type(obj.GetFont) ~= "function" then
		return
	end
	local curFont, size = obj:GetFont()
	if not size then
		return
	end
	local font = fontPath or curFont
	if type(font) ~= "string" then
		return
	end
	obj:SetFont(font, size, flags or "")
	if obj.SetShadowColor then
		obj:SetShadowColor(r, g, b, a)
	end
	if obj.SetShadowOffset then
		obj:SetShadowOffset(ox, oy)
	end
end

local function EachChatFrame(fn)
	local n = NUM_CHAT_WINDOWS or 10
	for i = 1, n do
		local frame = _G["ChatFrame" .. i]
		if frame then
			fn(frame, i)
		end
	end
end

local function ApplySticky()
	if not DB or not DB.sticky or not ChatTypeInfo then
		return
	end
	for i = 1, #STICKY_KEYS do
		local key = STICKY_KEYS[i]
		local info = ChatTypeInfo[key]
		if info then
			info.sticky = DB.sticky[key] and 1 or 0
		end
	end
end

local function ApplyAll()
	if not DB then
		return
	end

	local flags = ""
	local ox, oy = 0, 0
	local r, g, b, a = 0, 0, 0, 0
	local fontPath = ResolveFontPath()
	if DB.enabled then
		flags = DB.outline or ""
		if DB.shadow then
			ox = ClampOffset(DB.shadowX)
			oy = ClampOffset(DB.shadowY)
			r = Clamp(DB.shadowR, 0, 1)
			g = Clamp(DB.shadowG, 0, 1)
			b = Clamp(DB.shadowB, 0, 1)
			a = Clamp(DB.shadowA, 0, 1)
		end
	end

	local timeVisible = Clamp(DB.timeVisible, TIME_VISIBLE_MIN, TIME_VISIBLE_MAX)
	local fadeDuration = Clamp(DB.fadeDuration, FADE_DURATION_MIN, FADE_DURATION_MAX)
	local insertMode = DB.insertMode == "TOP" and "TOP" or "BOTTOM"
	local maxLines = math.floor(Clamp(DB.maxLines, MAX_LINES_MIN, MAX_LINES_MAX) + 0.5)
	DB.maxLines = maxLines

	EachChatFrame(function(frame, i)
		StyleFontObject(frame, fontPath, flags, ox, oy, r, g, b, a)

		if frame.SetFading then
			frame:SetFading(DB.fading and true or false)
		end
		if frame.SetTimeVisible then
			frame:SetTimeVisible(timeVisible)
		end
		if frame.SetFadeDuration then
			frame:SetFadeDuration(fadeDuration)
		end
		if frame.SetInsertMode then
			pcall(frame.SetInsertMode, frame, insertMode)
		end

		if DB.clampToEdge then
			if frame.SetClampedToScreen then
				frame:SetClampedToScreen(true)
			end
			if frame.SetClampRectInsets then
				frame:SetClampRectInsets(0, 0, 0, 0)
			end
		end

		if DB.maxLinesEnabled and frame.SetMaxLines and lastAppliedMaxLines ~= maxLines then
			frame:SetMaxLines(maxLines)
		end

		local buttons = _G["ChatFrame" .. i .. "ButtonFrame"]
		if buttons then
			if DB.hideButtons then
				buttons:Hide()
			else
				buttons:Show()
			end
		end
	end)

	if DB.maxLinesEnabled then
		lastAppliedMaxLines = maxLines
	end

	if ChatFrameMenuButton then
		if DB.hideButtons then
			ChatFrameMenuButton:Hide()
		else
			ChatFrameMenuButton:Show()
		end
	end

	if DB.enabled and DB.editBox then
		StyleFontObject(ChatFontNormal, fontPath, flags, ox, oy, r, g, b, a)
	elseif ChatFontNormal then
		StyleFontObject(ChatFontNormal, nil, "", 0, 0, 0, 0, 0, 0)
	end

	ApplySticky()
end

local RefreshCanvas

local hasWowDropdown = false
do
	local ok, frame = pcall(CreateFrame, "DropdownButton", nil, UIParent, "WowStyle1DropdownTemplate")
	if ok and frame then
		frame:Hide()
		hasWowDropdown = true
	end
end

local function SetSwatchColor(swatch, r, g, b)
	if swatch.SetColorRGB then
		swatch:SetColorRGB(r, g, b)
	elseif swatch.GetNormalTexture and swatch:GetNormalTexture() then
		swatch:GetNormalTexture():SetVertexColor(r, g, b)
	elseif swatch.tex then
		swatch.tex:SetVertexColor(r, g, b)
	end
end

local function OpenShadowColorPicker(swatch)
	local r, g, b = Clamp(DB.shadowR, 0, 1), Clamp(DB.shadowG, 0, 1), Clamp(DB.shadowB, 0, 1)
	local a = Clamp(DB.shadowA, 0, 1)
	local function apply(nr, ng, nb, na)
		DB.shadowR, DB.shadowG, DB.shadowB = nr, ng, nb
		if na ~= nil then
			DB.shadowA = Clamp(na, 0, 1)
		end
		SetSwatchColor(swatch, DB.shadowR, DB.shadowG, DB.shadowB)
		ApplyAll()
		if RefreshCanvas then
			RefreshCanvas()
		end
	end
	if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r,
			g = g,
			b = b,
			opacity = a,
			hasOpacity = true,
			swatchFunc = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB()
				local na = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a
				apply(nr, ng, nb, na)
			end,
			opacityFunc = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB()
				local na = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a
				apply(nr, ng, nb, na)
			end,
			cancelFunc = function(prev)
				if prev then
					apply(prev.r or r, prev.g or g, prev.b or b, prev.a or prev.opacity or a)
				end
			end,
		})
		return
	end
	ColorPickerFrame.func = function()
		local nr, ng, nb = ColorPickerFrame:GetColorRGB()
		apply(nr, ng, nb)
	end
	ColorPickerFrame.opacityFunc = function()
		local nr, ng, nb = ColorPickerFrame:GetColorRGB()
		local inv = OpacitySliderFrame and OpacitySliderFrame:GetValue() or (1 - a)
		apply(nr, ng, nb, 1 - inv)
	end
	ColorPickerFrame.cancelFunc = function(prev)
		if type(prev) == "table" then
			local pa = prev.opacity ~= nil and (1 - prev.opacity) or a
			apply(prev.r or r, prev.g or g, prev.b or b, pa)
		end
	end
	ColorPickerFrame.hasOpacity = true
	ColorPickerFrame.opacity = 1 - a
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Show()
end

local function AfterChange()
	ApplyAll()
	if RefreshCanvas then
		RefreshCanvas()
	end
end

local function SetTip(frame, tip)
	if not frame or type(tip) ~= "string" or tip == "" then
		return
	end
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tip, nil, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function AddSectionHeader(parent, y, text)
	local hdr = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	hdr:SetPoint("TOPLEFT", 16, y)
	hdr:SetText(text)
	return y - 28
end

local function MakeCheck(parent, label, x, y, set, tip, textWidth)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", x, y)
	local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetWidth(textWidth or 360)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	check:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		AfterChange()
	end)
	SetTip(check, tip)
	return check
end

local function MakeSlider(parent, y, labelText, minV, maxV, step, get, set, tip, formatFn)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", 20, y - 2)
	label:SetWidth(140)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)
	local slider = CreateFrame("Slider", nil, parent, "UISliderTemplate")
	slider:SetPoint("TOPLEFT", 170, y - 2)
	slider:SetSize(180, 16)
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	local valueFS = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	valueFS:SetPoint("LEFT", slider, "RIGHT", 8, 0)
	valueFS:SetWidth(48)
	valueFS:SetJustifyH("LEFT")
	slider:SetScript("OnValueChanged", function(self, value, user)
		if step >= 1 then
			value = math.floor(value / step + 0.5) * step
		else
			value = math.floor(value * 100 + 0.5) / 100
		end
		valueFS:SetText(formatFn and formatFn(value) or tostring(value))
		if user then
			set(value)
			AfterChange()
		end
	end)
	slider._valueFS = valueFS
	slider._format = formatFn
	slider._get = get
	SetTip(slider, tip)
	SetTip(label, tip)
	return slider, y - 40
end

local function RefreshDropdown(drop)
	if not drop then
		return
	end
	if drop.GenerateMenu then
		drop:GenerateMenu()
	elseif drop.Update then
		drop:Update()
	elseif drop.isCycle and drop.Refresh then
		drop:Refresh()
	end
end

local function MakeChoiceDropdown(parent, y, labelText, order, labels, get, set, tip)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", 20, y - 4)
	label:SetText(labelText)
	SetTip(label, tip)

	local function labelOf(id)
		local fn = labels[id]
		return fn and fn() or tostring(id)
	end

	if hasWowDropdown then
		local drop = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
		drop:SetPoint("TOPLEFT", 170, y)
		drop:SetWidth(180)
		drop:SetupMenu(function(_, root)
			for i = 1, #order do
				local id = order[i]
				root:CreateRadio(labelOf(id), function()
					return get() == id
				end, function()
					set(id)
					AfterChange()
				end)
			end
		end)
		SetTip(drop, tip)
		return drop, y - 36
	end

	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(180, 22)
	btn:SetPoint("TOPLEFT", 170, y)
	btn.isCycle = true
	function btn:Refresh()
		self:SetText(labelOf(get()))
	end
	btn:SetScript("OnClick", function(self)
		local cur = get()
		local nextId = order[1]
		for i = 1, #order do
			if order[i] == cur then
				nextId = order[i % #order + 1]
				break
			end
		end
		set(nextId)
		AfterChange()
		self:Refresh()
	end)
	btn:Refresh()
	SetTip(btn, tip)
	return btn, y - 36
end

local widgets = {}
local optionsCategory
local displayCategory

local function ResetToDefaults()
	wipe(PandiaChatDB)
	CopyDefaults(PandiaChatDB, Defaults())
	DB = PandiaChatDB
	SeedSticky(DB)
	lastAppliedMaxLines = DB.maxLinesEnabled and DB.maxLines or nil
	PandiaChatHistory.Clear()
	AfterChange()
end

local function CreateScrollCanvas()
	local frame = CreateFrame("Frame")
	frame:Hide()
	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(520, 800)
	scroll:SetScrollChild(content)
	frame:SetScript("OnShow", function()
		RefreshCanvas()
	end)
	return frame, content
end

local function FinishContent(content, y)
	content:SetHeight(math.max(400, -y + 40))
end

RefreshCanvas = function()
	if not DB then
		return
	end
	if widgets.enable then
		widgets.enable:SetChecked(DB.enabled and true or false)
		widgets.shadow:SetChecked(DB.shadow and true or false)
		widgets.editBox:SetChecked(DB.editBox and true or false)
		widgets.fading:SetChecked(DB.fading and true or false)
		widgets.clampToEdge:SetChecked(DB.clampToEdge and true or false)
		widgets.hideButtons:SetChecked(DB.hideButtons and true or false)
		RefreshDropdown(widgets.outline)
		RefreshDropdown(widgets.fontFace)
		RefreshDropdown(widgets.insertMode)

		local sx = ClampOffset(DB.shadowX)
		local sy = ClampOffset(DB.shadowY)
		DB.shadowX, DB.shadowY = sx, sy
		widgets.shadowX:SetValue(sx)
		widgets.shadowX._valueFS:SetText(tostring(sx))
		widgets.shadowY:SetValue(sy)
		widgets.shadowY._valueFS:SetText(tostring(sy))

		local tv = Clamp(DB.timeVisible, TIME_VISIBLE_MIN, TIME_VISIBLE_MAX)
		local fd = Clamp(DB.fadeDuration, FADE_DURATION_MIN, FADE_DURATION_MAX)
		DB.timeVisible, DB.fadeDuration = tv, fd
		widgets.timeVisible:SetValue(tv)
		widgets.timeVisible._valueFS:SetText(tostring(tv))
		widgets.fadeDuration:SetValue(fd)
		widgets.fadeDuration._valueFS:SetText(tostring(fd))

		SetSwatchColor(widgets.swatch, Clamp(DB.shadowR, 0, 1), Clamp(DB.shadowG, 0, 1), Clamp(DB.shadowB, 0, 1))
		if widgets.fontPath then
			widgets.fontPath:SetText(DB.fontCustomPath or "")
			if DB.fontId == "custom" then
				widgets.fontPath:Show()
				widgets.fontPathLabel:Show()
			else
				widgets.fontPath:Hide()
				widgets.fontPathLabel:Hide()
			end
		end
	end
	if widgets.maxLinesEnabled then
		widgets.maxLinesEnabled:SetChecked(DB.maxLinesEnabled and true or false)
		local ml = math.floor(Clamp(DB.maxLines, MAX_LINES_MIN, MAX_LINES_MAX) + 0.5)
		DB.maxLines = ml
		widgets.maxLines:SetValue(ml)
		widgets.maxLines._valueFS:SetText(tostring(ml))
	end
	if widgets.historyEnabled then
		widgets.historyEnabled:SetChecked(DB.historyEnabled and true or false)
		widgets.historyShared:SetChecked(DB.historyShared and true or false)
		local hc = Clamp(DB.historyCap, HISTORY_CAP_MIN, HISTORY_CAP_MAX)
		DB.historyCap = hc
		widgets.historyCap:SetValue(hc)
		widgets.historyCap._valueFS:SetText(tostring(hc))
	end
	for i = 1, #STICKY_KEYS do
		local key = STICKY_KEYS[i]
		local check = widgets.sticky and widgets.sticky[key]
		if check then
			check:SetChecked(DB.sticky[key] and true or false)
		end
	end
end

local function BuildParentCanvas()
	local frame = CreateFrame("Frame")
	frame:Hide()
	local blurb = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	blurb:SetPoint("TOPLEFT", 16, -16)
	blurb:SetWidth(480)
	blurb:SetJustifyH("LEFT")
	blurb:SetText(L.OPTIONS_BLURB)
	local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	reset:SetSize(140, 22)
	reset:SetPoint("TOPLEFT", 16, -72)
	reset:SetText(L.RESET)
	reset:SetScript("OnClick", ResetToDefaults)
	SetTip(reset, L.TIP_RESET)
	return frame
end

local function BuildDisplayCanvas()
	local frame, content = CreateScrollCanvas()
	local y = -8

	y = AddSectionHeader(content, y, L.SECTION_FONT)
	widgets.enable = MakeCheck(content, L.ENABLE, 16, y, function(v)
		DB.enabled = v
	end, L.TIP_ENABLE)
	y = y - 36

	widgets.outline, y = MakeChoiceDropdown(content, y, L.OUTLINE, OUTLINE_ORDER, OUTLINE_LABEL, function()
		return DB.outline
	end, function(v)
		DB.outline = v
	end, L.TIP_OUTLINE)

	widgets.fontFace, y = MakeChoiceDropdown(content, y, L.FONT_FACE, FONT_ORDER, FONT_LABEL, function()
		return DB.fontId or ""
	end, function(v)
		DB.fontId = v
	end, L.TIP_FONT_FACE)

	widgets.fontPathLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	widgets.fontPathLabel:SetPoint("TOPLEFT", 20, y - 4)
	widgets.fontPathLabel:SetText(L.FONT_CUSTOM_PATH)
	widgets.fontPath = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	widgets.fontPath:SetSize(280, 20)
	widgets.fontPath:SetPoint("TOPLEFT", 170, y)
	widgets.fontPath:SetAutoFocus(false)
	local function commitFontPath(self)
		DB.fontCustomPath = self:GetText() or ""
		AfterChange()
		self:ClearFocus()
	end
	widgets.fontPath:SetScript("OnEnterPressed", commitFontPath)
	widgets.fontPath:SetScript("OnEditFocusLost", commitFontPath)
	SetTip(widgets.fontPath, L.TIP_FONT_CUSTOM_PATH)
	SetTip(widgets.fontPathLabel, L.TIP_FONT_CUSTOM_PATH)
	y = y - 36

	widgets.shadow = MakeCheck(content, L.SHADOW, 16, y, function(v)
		DB.shadow = v
	end, L.TIP_SHADOW)
	y = y - 36

	widgets.shadowX, y = MakeSlider(content, y, L.SHADOW_X, SHADOW_OFFSET_MIN, SHADOW_OFFSET_MAX, 1, function()
		return DB.shadowX
	end, function(v)
		DB.shadowX = v
	end, L.TIP_SHADOW_X)
	widgets.shadowY, y = MakeSlider(content, y, L.SHADOW_Y, SHADOW_OFFSET_MIN, SHADOW_OFFSET_MAX, 1, function()
		return DB.shadowY
	end, function(v)
		DB.shadowY = v
	end, L.TIP_SHADOW_Y)

	local colorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	colorLabel:SetPoint("TOPLEFT", 20, y - 4)
	colorLabel:SetText(L.SHADOW_COLOR)
	local swatch = CreateFrame("Button", nil, content, "ColorSwatchTemplate")
	if not swatch.SetColorRGB then
		swatch = CreateFrame("Button", nil, content)
		swatch:SetSize(24, 24)
		local tex = swatch:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		tex:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
		swatch.tex = tex
	end
	swatch:SetPoint("TOPLEFT", 170, y)
	swatch:SetScript("OnClick", function(self)
		OpenShadowColorPicker(self)
	end)
	SetTip(swatch, L.TIP_SHADOW_COLOR)
	SetTip(colorLabel, L.TIP_SHADOW_COLOR)
	widgets.swatch = swatch
	y = y - 36

	widgets.editBox = MakeCheck(content, L.EDIT_BOX, 16, y, function(v)
		DB.editBox = v
	end, L.TIP_EDIT_BOX)
	y = y - 44

	y = AddSectionHeader(content, y, L.SECTION_FADE)
	widgets.fading = MakeCheck(content, L.FADING, 16, y, function(v)
		DB.fading = v
	end, L.TIP_FADING)
	y = y - 36
	widgets.timeVisible, y = MakeSlider(content, y, L.TIME_VISIBLE, TIME_VISIBLE_MIN, TIME_VISIBLE_MAX, 1, function()
		return DB.timeVisible
	end, function(v)
		DB.timeVisible = v
	end, L.TIP_TIME_VISIBLE)
	widgets.fadeDuration, y = MakeSlider(content, y, L.FADE_DURATION, FADE_DURATION_MIN, FADE_DURATION_MAX, 1, function()
		return DB.fadeDuration
	end, function(v)
		DB.fadeDuration = v
	end, L.TIP_FADE_DURATION)
	y = y - 8

	y = AddSectionHeader(content, y, L.SECTION_LAYOUT)
	widgets.clampToEdge = MakeCheck(content, L.CLAMP_EDGE, 16, y, function(v)
		DB.clampToEdge = v
	end, L.TIP_CLAMP_EDGE)
	y = y - 36
	widgets.insertMode, y = MakeChoiceDropdown(content, y, L.INSERT_MODE, { "BOTTOM", "TOP" }, {
		BOTTOM = function() return L.INSERT_BOTTOM end,
		TOP = function() return L.INSERT_TOP end,
	}, function()
		return DB.insertMode == "TOP" and "TOP" or "BOTTOM"
	end, function(v)
		DB.insertMode = v
	end, L.TIP_INSERT_MODE)
	y = y - 8

	y = AddSectionHeader(content, y, L.SECTION_SIDE_BUTTONS)
	widgets.hideButtons = MakeCheck(content, L.HIDE_BUTTONS, 16, y, function(v)
		DB.hideButtons = v
	end, L.TIP_HIDE_BUTTONS)
	y = y - 36

	FinishContent(content, y)
	return frame
end

local function BuildHistoryCanvas()
	local frame, content = CreateScrollCanvas()
	local y = -8

	y = AddSectionHeader(content, y, L.SECTION_HISTORY_LIVE)
	widgets.maxLinesEnabled = MakeCheck(content, L.MAX_LINES_ENABLE, 16, y, function(v)
		DB.maxLinesEnabled = v
		if v then
			-- Force apply so opting in actually sets max lines.
			lastAppliedMaxLines = nil
		end
	end, L.TIP_MAX_LINES_ENABLE)
	y = y - 36
	widgets.maxLines, y = MakeSlider(content, y, L.MAX_LINES, MAX_LINES_MIN, MAX_LINES_MAX, 16, function()
		return DB.maxLines
	end, function(v)
		DB.maxLines = v
		lastAppliedMaxLines = nil
	end, L.TIP_MAX_LINES)
	local warn = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	warn:SetPoint("TOPLEFT", 20, y)
	warn:SetWidth(460)
	warn:SetJustifyH("LEFT")
	warn:SetText(L.MAX_LINES_WARN)
	y = y - 44

	y = AddSectionHeader(content, y, L.SECTION_HISTORY_SAVE)
	widgets.historyEnabled = MakeCheck(content, L.HISTORY_ENABLE, 16, y, function(v)
		DB.historyEnabled = v
		if v then
			PandiaChatHistory.HookAll()
		else
			PandiaChatHistory.Flush()
		end
	end, L.TIP_HISTORY_ENABLE)
	y = y - 36
	widgets.historyCap, y = MakeSlider(content, y, L.HISTORY_CAP, HISTORY_CAP_MIN, HISTORY_CAP_MAX, 10, function()
		return DB.historyCap
	end, function(v)
		DB.historyCap = v
		PandiaChatHistory.TrimToCap()
	end, L.TIP_HISTORY_CAP)
	widgets.historyShared = MakeCheck(content, L.HISTORY_SHARED, 16, y, function(v)
		PandiaChatHistory.Flush()
		DB.historyShared = v
		PandiaChatHistory.OnAddonLoaded()
	end, L.TIP_HISTORY_SHARED)
	y = y - 36
	local clearHist = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	clearHist:SetSize(160, 22)
	clearHist:SetPoint("TOPLEFT", 16, y)
	clearHist:SetText(L.HISTORY_CLEAR)
	clearHist:SetScript("OnClick", function()
		PandiaChatHistory.Clear()
	end)
	SetTip(clearHist, L.TIP_HISTORY_CLEAR)
	y = y - 42

	FinishContent(content, y)
	return frame
end

local function BuildStickyCanvas()
	local frame, content = CreateScrollCanvas()
	local y = -8
	y = AddSectionHeader(content, y, L.SECTION_STICKY)
	widgets.sticky = {}
	local tip = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	tip:SetPoint("TOPLEFT", 20, y)
	tip:SetWidth(460)
	tip:SetJustifyH("LEFT")
	tip:SetText(L.TIP_STICKY)
	y = y - 36
	local startY = y
	for i = 1, #STICKY_KEYS do
		local key = STICKY_KEYS[i]
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local x = 16 + col * 240
		local rowY = startY - row * 32
		widgets.sticky[key] = MakeCheck(content, STICKY_LABEL[key](), x, rowY, function(v)
			DB.sticky[key] = v
		end, L.TIP_STICKY, 180)
	end
	y = startY - math.ceil(#STICKY_KEYS / 2) * 32 - 8
	FinishContent(content, y)
	return frame
end

local function RegisterOptions()
	local parent = Settings.RegisterCanvasLayoutCategory(BuildParentCanvas(), L.OPTIONS_TITLE)
	Settings.RegisterAddOnCategory(parent)
	displayCategory = Settings.RegisterCanvasLayoutSubcategory(parent, BuildDisplayCanvas(), L.CATEGORY_DISPLAY)
	Settings.RegisterCanvasLayoutSubcategory(parent, BuildHistoryCanvas(), L.CATEGORY_HISTORY)
	Settings.RegisterCanvasLayoutSubcategory(parent, BuildStickyCanvas(), L.CATEGORY_STICKY)
	optionsCategory = parent
end

function PandiaChat_OnAddonCompartmentClick()
	if InCombatLockdown() or not displayCategory then
		return
	end
	Settings.OpenToCategory(displayCategory:GetID())
end

local function ScheduleApply()
	C_Timer.After(0, ApplyAll)
end

PandiaChatHistory.Init(function()
	return DB
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:RegisterEvent("UPDATE_CHAT_WINDOWS")
loader:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name ~= "PandiaChat" then
			return
		end
		PandiaChatDB = PandiaChatDB or {}
		CopyDefaults(PandiaChatDB, Defaults())
		DB = PandiaChatDB
		DB.shadowX = ClampOffset(DB.shadowX)
		DB.shadowY = ClampOffset(DB.shadowY)
		DB.timeVisible = Clamp(DB.timeVisible, TIME_VISIBLE_MIN, TIME_VISIBLE_MAX)
		DB.fadeDuration = Clamp(DB.fadeDuration, FADE_DURATION_MIN, FADE_DURATION_MAX)
		DB.maxLines = math.floor(Clamp(DB.maxLines, MAX_LINES_MIN, MAX_LINES_MAX) + 0.5)
		DB.historyCap = Clamp(DB.historyCap, HISTORY_CAP_MIN, HISTORY_CAP_MAX)
		SeedSticky(DB)
		-- Do not wipe chat history on every login when override is already on.
		if DB.maxLinesEnabled then
			lastAppliedMaxLines = DB.maxLines
		end
		PandiaChatHistory.OnAddonLoaded()
		C_Timer.After(0, RegisterOptions)
		if type(hooksecurefunc) == "function" and type(FCF_SetChatWindowFontSize) == "function" then
			hooksecurefunc("FCF_SetChatWindowFontSize", ScheduleApply)
		end
		loader:UnregisterEvent("ADDON_LOADED")
		return
	end
	if event == "PLAYER_LOGOUT" then
		PandiaChatHistory.OnLogout()
		return
	end
	if not DB then
		return
	end
	if event == "PLAYER_LOGIN" then
		ScheduleApply()
		PandiaChatHistory.OnLogin()
		return
	end
	if event == "UPDATE_CHAT_WINDOWS" then
		PandiaChatHistory.OnChatWindowsUpdate()
	end
	ScheduleApply()
end)
