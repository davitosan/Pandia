-- Chat outline and drop shadow. Stock options do not expose these FontString flags.

local L = PandiaChatLocale
local DB

local OUTLINE_ORDER = { "", "THINOUTLINE", "OUTLINE", "THICKOUTLINE" }
local OUTLINE_LABEL = {
	[""] = function() return L.OUTLINE_NONE end,
	THINOUTLINE = function() return L.OUTLINE_THIN end,
	OUTLINE = function() return L.OUTLINE_NORMAL end,
	THICKOUTLINE = function() return L.OUTLINE_THICK end,
}

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

local function OutlineIndex(flag)
	for i = 1, #OUTLINE_ORDER do
		if OUTLINE_ORDER[i] == flag then
			return i
		end
	end
	return 3
end

local function StyleFontObject(obj, flags, ox, oy, r, g, b, a)
	if not obj or type(obj.GetFont) ~= "function" then
		return
	end
	local font, size = obj:GetFont()
	if type(font) ~= "string" or not size then
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

local function ApplyChatFonts()
	if not DB then
		return
	end
	local flags = ""
	local ox, oy = 0, 0
	local r, g, b, a = 0, 0, 0, 0
	if DB.enabled then
		flags = DB.outline or ""
		if DB.shadow then
			ox = tonumber(DB.shadowX) or 0
			oy = tonumber(DB.shadowY) or 0
			r = Clamp(DB.shadowR, 0, 1)
			g = Clamp(DB.shadowG, 0, 1)
			b = Clamp(DB.shadowB, 0, 1)
			a = Clamp(DB.shadowA, 0, 1)
		end
	end
	local n = NUM_CHAT_WINDOWS or 10
	for i = 1, n do
		StyleFontObject(_G["ChatFrame" .. i], flags, ox, oy, r, g, b, a)
	end
	if DB.enabled and DB.editBox then
		StyleFontObject(ChatFontNormal, flags, ox, oy, r, g, b, a)
	elseif ChatFontNormal then
		StyleFontObject(ChatFontNormal, "", 0, 0, 0, 0, 0, 0)
	end
end

local RefreshCanvas

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
		ApplyChatFonts()
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
	-- Legacy picker: opacity slider is inverted (1 = transparent).
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

local function MakeCheck(parent, label, x, y, get, set)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", x, y)
	local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetText(label)
	check:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		ApplyChatFonts()
		if RefreshCanvas then
			RefreshCanvas()
		end
	end)
	check._get = get
	check._label = text
	return check
end

local function MakeNumberBox(parent, x, y, w, get, set)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(w, 20)
	box:SetPoint("TOPLEFT", x, y)
	box:SetAutoFocus(false)
	box:SetNumeric(false)
	local function commit(self)
		set(tonumber(self:GetText()) or 0)
		ApplyChatFonts()
		if RefreshCanvas then
			RefreshCanvas()
		end
		self:ClearFocus()
	end
	box:SetScript("OnEnterPressed", commit)
	box:SetScript("OnEditFocusLost", commit)
	box._get = get
	return box
end

local canvas
local widgets = {}

RefreshCanvas = function()
	if not canvas or not DB then
		return
	end
	widgets.enable:SetChecked(DB.enabled and true or false)
	widgets.shadow:SetChecked(DB.shadow and true or false)
	widgets.editBox:SetChecked(DB.editBox and true or false)
	widgets.outlineBtn:SetText((OUTLINE_LABEL[DB.outline] or OUTLINE_LABEL.OUTLINE)())
	widgets.shadowX:SetText(tostring(DB.shadowX or 0))
	widgets.shadowY:SetText(tostring(DB.shadowY or 0))
	widgets.shadowA:SetText(string.format("%.2f", Clamp(DB.shadowA, 0, 1)))
	SetSwatchColor(widgets.swatch, Clamp(DB.shadowR, 0, 1), Clamp(DB.shadowG, 0, 1), Clamp(DB.shadowB, 0, 1))
end

local function BuildCanvas()
	canvas = CreateFrame("Frame")
	canvas:Hide()
	canvas:SetScript("OnShow", RefreshCanvas)

	local y = -16
	widgets.enable = MakeCheck(canvas, L.ENABLE, 16, y, function()
		return DB.enabled
	end, function(v)
		DB.enabled = v
	end)
	y = y - 36

	local outlineLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	outlineLabel:SetPoint("TOPLEFT", 20, y - 4)
	outlineLabel:SetText(L.OUTLINE)
	local outlineBtn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	outlineBtn:SetSize(120, 22)
	outlineBtn:SetPoint("TOPLEFT", 160, y)
	outlineBtn:SetScript("OnClick", function()
		local i = OutlineIndex(DB.outline)
		DB.outline = OUTLINE_ORDER[(i % #OUTLINE_ORDER) + 1]
		ApplyChatFonts()
		RefreshCanvas()
	end)
	widgets.outlineBtn = outlineBtn
	y = y - 36

	widgets.shadow = MakeCheck(canvas, L.SHADOW, 16, y, function()
		return DB.shadow
	end, function(v)
		DB.shadow = v
	end)
	y = y - 36

	local xLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	xLabel:SetPoint("TOPLEFT", 20, y - 4)
	xLabel:SetText(L.SHADOW_X)
	widgets.shadowX = MakeNumberBox(canvas, 160, y, 60, function()
		return DB.shadowX
	end, function(v)
		DB.shadowX = v
	end)
	local yLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	yLabel:SetPoint("TOPLEFT", 240, y - 4)
	yLabel:SetText(L.SHADOW_Y)
	widgets.shadowY = MakeNumberBox(canvas, 320, y, 60, function()
		return DB.shadowY
	end, function(v)
		DB.shadowY = v
	end)
	y = y - 36

	local colorLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	colorLabel:SetPoint("TOPLEFT", 20, y - 4)
	colorLabel:SetText(L.SHADOW_COLOR)
	local swatch = CreateFrame("Button", nil, canvas, "ColorSwatchTemplate")
	if not swatch.SetColorRGB then
		swatch = CreateFrame("Button", nil, canvas)
		swatch:SetSize(24, 24)
		local tex = swatch:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		tex:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
		swatch.tex = tex
	end
	swatch:SetPoint("TOPLEFT", 160, y)
	swatch:SetScript("OnClick", function(self)
		OpenShadowColorPicker(self)
	end)
	widgets.swatch = swatch

	local aLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	aLabel:SetPoint("TOPLEFT", 210, y - 4)
	aLabel:SetText(L.SHADOW_ALPHA)
	widgets.shadowA = MakeNumberBox(canvas, 330, y, 60, function()
		return DB.shadowA
	end, function(v)
		DB.shadowA = Clamp(v, 0, 1)
	end)
	y = y - 36

	widgets.editBox = MakeCheck(canvas, L.EDIT_BOX, 16, y, function()
		return DB.editBox
	end, function(v)
		DB.editBox = v
	end)
	y = y - 42

	local reset = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	reset:SetSize(120, 22)
	reset:SetPoint("TOPLEFT", 16, y)
	reset:SetText(L.RESET)
	reset:SetScript("OnClick", function()
		wipe(PandiaChatDB)
		CopyDefaults(PandiaChatDB, Defaults())
		DB = PandiaChatDB
		ApplyChatFonts()
		RefreshCanvas()
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

function PandiaChat_OnAddonCompartmentClick()
	if InCombatLockdown() or not optionsCategory then
		return
	end
	Settings.OpenToCategory(optionsCategory:GetID())
end

local function ScheduleApply()
	C_Timer.After(0, ApplyChatFonts)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_CHAT_WINDOWS")
loader:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name ~= "PandiaChat" then
			return
		end
		PandiaChatDB = PandiaChatDB or {}
		CopyDefaults(PandiaChatDB, Defaults())
		DB = PandiaChatDB
		C_Timer.After(0, RegisterOptions)
		if type(hooksecurefunc) == "function" and type(FCF_SetChatWindowFontSize) == "function" then
			hooksecurefunc("FCF_SetChatWindowFontSize", ScheduleApply)
		end
		loader:UnregisterEvent("ADDON_LOADED")
		return
	end
	if not DB then
		return
	end
	ScheduleApply()
end)
