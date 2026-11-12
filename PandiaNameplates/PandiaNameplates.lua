-- Nameplate ToT names + Forever combo pips (Blizzard class templates).

local pool, n, t = {}, 0, 0
local MAX_CP = 5
local _, PLAYER_CLASS = UnitClass("player")
local SHOW_CP = PLAYER_CLASS == "ROGUE" or PLAYER_CLASS == "DRUID"
local CP_TEMPLATE = PLAYER_CLASS == "DRUID" and "DruidComboPointTemplate" or "RogueComboPointTemplate"
local inCombat = false

local probeBar = CreateFrame("StatusBar")
probeBar:Hide()
probeBar:SetMinMaxValues(0, MAX_CP)
local probeFS = probeBar:CreateFontString()
probeFS:Hide()

local function Secret(v)
	return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end

-- Forever may secret GetComboPoints; unwrap via widget when needed.
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

local function Overlay()
	n = n + 1
	local f = pool[n]
	if f then
		return f
	end
	f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("HIGH")
	f.name = f:CreateFontString(nil, "OVERLAY")
	f.name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
	f.name:SetJustifyH("RIGHT")

	if SHOW_CP then
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
	return f
end

local function Paint(unit, plate)
	local f = Overlay()
	local uf = plate.UnitFrame
	local bar = uf and (uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)) or plate
	local shown

	local name, second = UnitFullName(unit .. "target")
	if name ~= nil then
		if second ~= nil then
			name = name .. " " .. second
		end
		f.name:ClearAllPoints()
		f.name:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -1)
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

	if f.cps then
		if inCombat then
			local cp = PlainCP(unit)
			f.cps:ClearAllPoints()
			f.cps:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -1)
			if cp ~= nil then
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
		-- Soft plates duplicate hard nameplates — skip non-nameplate* tokens.
		if type(unit) == "string" and not Secret(unit) and unit:find("^nameplate") then
			pcall(Paint, unit, plate)
		end
	end
	for i = n + 1, #pool do
		pool[i]:Hide()
	end
end)
