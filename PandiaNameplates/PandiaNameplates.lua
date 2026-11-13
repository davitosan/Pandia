-- Nameplate ToT names + Forever combo pips (Blizzard class templates).

local L = PandiaNameplatesLocale
local pool, n, t = {}, 0, 0
local MAX_CP = 5
local _, PLAYER_CLASS = UnitClass("player")
local SHOW_CP_CLASS = PLAYER_CLASS == "ROGUE" or PLAYER_CLASS == "DRUID"
local CP_TEMPLATE = PLAYER_CLASS == "DRUID" and "DruidComboPointTemplate" or "RogueComboPointTemplate"
local inCombat = false
local DB

local POSITIONS = { "TOPLEFT", "TOP", "TOPRIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local POS_LABEL = {
	TOPLEFT = function() return L.POS_TOPLEFT end,
	TOP = function() return L.POS_TOP end,
	TOPRIGHT = function() return L.POS_TOPRIGHT end,
	BOTTOMLEFT = function() return L.POS_BOTTOMLEFT end,
	BOTTOM = function() return L.POS_BOTTOM end,
	BOTTOMRIGHT = function() return L.POS_BOTTOMRIGHT end,
}

-- childPoint, barPoint, x, y, justifyH
local POS_ANCHOR = {
	TOPLEFT = { "BOTTOMLEFT", "TOPLEFT", 0, 2, "LEFT" },
	TOP = { "BOTTOM", "TOP", 0, 2, "CENTER" },
	TOPRIGHT = { "BOTTOMRIGHT", "TOPRIGHT", 0, 2, "RIGHT" },
	BOTTOMLEFT = { "TOPLEFT", "BOTTOMLEFT", 0, -1, "LEFT" },
	BOTTOM = { "TOP", "BOTTOM", 0, -1, "CENTER" },
	BOTTOMRIGHT = { "TOPRIGHT", "BOTTOMRIGHT", 0, -1, "RIGHT" },
}

local function Defaults()
	return {
		name = { enabled = true, position = "BOTTOMRIGHT", scale = 1 },
		cps = { enabled = true, position = "BOTTOMLEFT", scale = 0.55 },
	}
end

local function ClampScale(value, fallback)
	local s = tonumber(value)
	if not s then
		return fallback
	end
	if s < 0.35 then
		return 0.35
	end
	if s > 1.25 then
		return 1.25
	end
	return s
end

local function NameScale()
	return ClampScale(DB and DB.name and DB.name.scale, 1)
end

local function CPScale()
	return ClampScale(DB and DB.cps and DB.cps.scale, 0.55)
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

local function ValidPos(pos)
	return POS_ANCHOR[pos] and pos or nil
end

local function CastBar(uf)
	if not uf then
		return nil
	end
	return uf.castBar or uf.CastBar or (uf.CastBarFrame and uf.CastBarFrame.castBar) or uf.CastBarFrame
end

-- Bottom anchors share space with the nameplate cast bar; sit under the cast
-- bar while it is shown so pips/ToT text are not covered.
local function AnchorToBar(region, bar, uf, position, justifyH)
	local a = POS_ANCHOR[ValidPos(position) or "BOTTOM"]
	local rel = bar
	if type(a[2]) == "string" and a[2]:find("BOTTOM", 1, true) then
		local cast = CastBar(uf)
		if cast and cast.IsShown and cast:IsShown() then
			rel = cast
		end
	end
	region:ClearAllPoints()
	region:SetPoint(a[1], rel, a[2], a[3], a[4])
	if justifyH and region.SetJustifyH then
		region:SetJustifyH(justifyH or a[5])
	end
end

local probeBar = CreateFrame("StatusBar")
probeBar:Hide()
probeBar:SetMinMaxValues(0, MAX_CP)
local probeFS = probeBar:CreateFontString()
probeFS:Hide()

local function Secret(v)
	return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end

local function PlainCP(unit)
	local ok, pts = pcall(GetComboPoints, "player", unit)
	if not ok or pts == nil then
		return nil
	end
	if type(pts) == "number" and not Secret(pts) then
		return pts
	end
	pcall(probeBar.SetValue, probeBar, pts)
	local okV, val = pcall(probeBar.GetValue, probeBar)
	if okV and type(val) == "number" and not Secret(val) and val >= 0 and val <= MAX_CP then
		return val
	end
	pcall(probeFS.SetText, probeFS, pts)
	local okT, text = pcall(probeFS.GetText, probeFS)
	if okT and type(text) == "string" then
		local num = tonumber(text)
		if num and not Secret(num) and num >= 0 and num <= MAX_CP then
			return num
		end
	end
	return nil
end

local function MakePip(parent)
	local d = CreateFrame("Frame", nil, parent, CP_TEMPLATE)
	d:Setup()
	d:SetActiveNoAnimation(false)
	return d
end

local function Overlay(plate)
	n = n + 1
	local f = pool[n]
	if not f then
		f = CreateFrame("Frame", nil, plate)
		f.name = f:CreateFontString(nil, "OVERLAY")
		f.name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
		f.name:SetJustifyH("RIGHT")

		if SHOW_CP_CLASS then
			f.cps = CreateFrame("Frame", nil, f)
			f.cps:SetSize(5 * 24 - 4, 20)
			f.dots = {}
			for i = 1, MAX_CP do
				local pip = MakePip(f.cps)
				pip:SetPoint("TOPLEFT", (i - 1) * 24, 0)
				f.dots[i] = pip
			end
		end
		pool[n] = f
	end

	-- Stay on the nameplate so pips sort/hide with it (not over World Map / UI).
	if f:GetParent() ~= plate then
		f:SetParent(plate)
	end
	f:SetFrameStrata(plate:GetFrameStrata())
	local uf = plate.UnitFrame
	local cast = CastBar(uf)
	local base = (cast and cast:GetFrameLevel())
		or (uf and uf:GetFrameLevel())
		or plate:GetFrameLevel()
		or 0
	f:SetFrameLevel(base + 20)
	return f
end

local function Paint(unit, plate)
	if not DB then
		return
	end
	local f = Overlay(plate)
	local uf = plate.UnitFrame
	local bar = uf and (uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)) or plate
	local shown

	if DB.name.enabled then
		local name, second = UnitFullName(unit .. "target")
		if name ~= nil then
			if second ~= nil then
				name = name .. " " .. second
			end
			local pos = ValidPos(DB.name.position) or "BOTTOMRIGHT"
			AnchorToBar(f.name, bar, uf, pos)
			f.name:SetScale(NameScale())
			f.name:SetJustifyH(POS_ANCHOR[pos][5])
			f.name:SetText(name)
			local _, class = UnitClass(unit .. "target")
			local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
			if c then
				f.name:SetTextColor(c:GetRGB())
			else
				f.name:SetTextColor(1, 1, 1)
			end
			f.name:Show()
			shown = true
		else
			f.name:Hide()
		end
	else
		f.name:Hide()
	end

	if f.cps then
		local want = DB.cps.enabled and inCombat
		if want then
			local cp = PlainCP(unit)
			if cp ~= nil then
				AnchorToBar(f.cps, bar, uf, ValidPos(DB.cps.position) or "BOTTOMLEFT")
				f.cps:SetScale(CPScale())
				for i = 1, MAX_CP do
					f.dots[i]:SetActiveNoAnimation(cp >= i)
				end
				f.cps:Show()
				shown = true
			else
				f.cps:Hide()
			end
		else
			f.cps:Hide()
		end
	end

	if shown then
		f:Show()
	else
		f:Hide()
	end
end

local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:RegisterEvent("PLAYER_ENTERING_WORLD")
combat:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
	else
		local ok, v = pcall(UnitAffectingCombat, "player")
		if ok and v ~= nil and not Secret(v) then
			inCombat = v and true or false
		end
	end
end)

CreateFrame("Frame"):SetScript("OnUpdate", function(_, dt)
	t = t + dt
	if t < 0.2 then
		return
	end
	t, n = 0, 0
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local unit = plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if type(unit) == "string" and not Secret(unit) and unit:find("^nameplate") then
			pcall(Paint, unit, plate)
		end
	end
	for i = n + 1, #pool do
		pool[i]:Hide()
	end
end)

-- Options canvas (Esc > Options > AddOns). Canvas avoids Settings control
-- taint that triggers ADDON_ACTION_FORBIDDEN on IsUserOAuthed().

local canvas
local widgets = {}

local function NextPos(current)
	local cur = ValidPos(current) or POSITIONS[1]
	for i, pos in ipairs(POSITIONS) do
		if pos == cur then
			return POSITIONS[i % #POSITIONS + 1]
		end
	end
	return POSITIONS[1]
end

local function RefreshCanvas()
	if not canvas or not DB then
		return
	end
	widgets.nameCheck:SetChecked(DB.name.enabled)
	widgets.namePos:SetText(POS_LABEL[ValidPos(DB.name.position) or "BOTTOMRIGHT"]())
	widgets.nameScale:SetValue(NameScale() * 100)
	widgets.nameScaleLabel:SetText(string.format("%.0f%%", NameScale() * 100))
	if widgets.cpsCheck then
		widgets.cpsCheck:SetChecked(DB.cps.enabled)
		widgets.cpsPos:SetText(POS_LABEL[ValidPos(DB.cps.position) or "BOTTOMLEFT"]())
		widgets.cpsScale:SetValue(CPScale() * 100)
		widgets.cpsScaleLabel:SetText(string.format("%.0f%%", CPScale() * 100))
	end
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

local function AddPosRow(parent, y, labelText, onClick)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 4)
	label:SetWidth(160)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(140, 22)
	btn:SetPoint("TOPLEFT", 180, y)
	btn:SetScript("OnClick", onClick)
	return btn, y - 36
end

local function AddScaleRow(parent, y, labelText, onValue)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 16, y - 2)
	label:SetWidth(160)
	label:SetJustifyH("LEFT")
	label:SetText(labelText)
	local slider = CreateFrame("Slider", nil, parent, "UISliderTemplate")
	slider:SetPoint("TOPLEFT", 180, y - 2)
	slider:SetSize(160, 16)
	slider:SetMinMaxValues(35, 125)
	slider:SetValueStep(5)
	slider:SetObeyStepOnDrag(true)
	local valueFS = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	valueFS:SetPoint("LEFT", slider, "RIGHT", 8, 0)
	valueFS:SetWidth(40)
	valueFS:SetJustifyH("LEFT")
	slider:SetScript("OnValueChanged", function(self, value, user)
		value = math.floor(value / 5 + 0.5) * 5
		valueFS:SetText(string.format("%.0f%%", value))
		if user then
			onValue(value / 100)
		end
	end)
	return slider, valueFS, y - 40
end

local function BuildCanvas()
	canvas = CreateFrame("Frame")
	canvas:Hide()
	canvas:SetScript("OnShow", RefreshCanvas)

	local y = -16
	widgets.nameCheck, y = AddCheckRow(canvas, y, L.TOT_NAME, function(self)
		DB.name.enabled = self:GetChecked() and true or false
	end)
	widgets.namePos, y = AddPosRow(canvas, y, L.TOT_POSITION, function(self)
		DB.name.position = NextPos(DB.name.position)
		self:SetText(POS_LABEL[DB.name.position]())
	end)
	widgets.nameScale, widgets.nameScaleLabel, y = AddScaleRow(canvas, y, L.TOT_SCALE, function(scale)
		DB.name.scale = scale
	end)

	if SHOW_CP_CLASS then
		y = y - 8
		widgets.cpsCheck, y = AddCheckRow(canvas, y, L.COMBO, function(self)
			DB.cps.enabled = self:GetChecked() and true or false
		end)
		widgets.cpsPos, y = AddPosRow(canvas, y, L.COMBO_POSITION, function(self)
			DB.cps.position = NextPos(DB.cps.position)
			self:SetText(POS_LABEL[DB.cps.position]())
		end)
		widgets.cpsScale, widgets.cpsScaleLabel, y = AddScaleRow(canvas, y, L.COMBO_SCALE, function(scale)
			DB.cps.scale = scale
		end)
	end

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
	if name ~= "PandiaNameplates" then
		return
	end
	PandiaNameplatesDB = PandiaNameplatesDB or {}
	CopyDefaults(PandiaNameplatesDB, Defaults())
	DB = PandiaNameplatesDB
	-- Defer so Settings registration is not on the ADDON_LOADED stack (taint).
	C_Timer.After(0, RegisterOptions)
	loader:UnregisterEvent("ADDON_LOADED")
end)
