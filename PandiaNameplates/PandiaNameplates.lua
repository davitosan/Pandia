-- Nameplate target names (class-colored) + combo points on the mob that owns them.

local pool, n, t = {}, 0, 0
local MAX_CP = 5
local _, PLAYER_CLASS = UnitClass("player")
local SHOW_CP = PLAYER_CLASS == "ROGUE" or PLAYER_CLASS == "DRUID"

local function Secret(v)
	return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end

local function Overlay()
	n = n + 1
	local f = pool[n]
	if f then
		return f
	end
	f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(1, 1)
	f:SetFrameStrata("HIGH")

	f.name = f:CreateFontString(nil, "OVERLAY")
	f.name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
	f.name:SetJustifyH("RIGHT")

	-- Same art as the target-frame ComboFrame (circular red charges).
	local PW, PH, GAP = 18, 24, 1
	f.cps = CreateFrame("Frame", nil, f)
	f.cps:SetSize(MAX_CP * (PW + GAP) - GAP, PH)
	f.dots = {}
	for i = 1, MAX_CP do
		local d = CreateFrame("StatusBar", nil, f.cps)
		d:SetSize(PW, PH)
		d:SetMinMaxValues(i - 1, i)
		d:SetPoint("LEFT", f.cps, "LEFT", (i - 1) * (PW + GAP), 0)

		local empty = d:CreateTexture(nil, "BACKGROUND")
		empty:SetAllPoints()
		empty:SetTexture("Interface\\ComboFrame\\ComboPoint")
		empty:SetTexCoord(0, 0.375, 0, 1)

		d:SetStatusBarTexture("Interface\\ComboFrame\\ComboPoint")
		local fill = d:GetStatusBarTexture()
		fill:SetTexCoord(0.375, 0.5625, 0, 1)
		-- Match target-frame glow (red charges)
		fill:SetVertexColor(1, 0.2, 0.15)

		f.dots[i] = d
	end

	pool[n] = f
	return f
end

local function Bar(plate)
	local uf = plate.UnitFrame
	return uf and (uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)) or plate
end

local function DisplayName(unit)
	local name, second = UnitFullName(unit)
	if name == nil then
		return nil
	end
	return second ~= nil and (name .. " " .. second) or name
end

local function ClassRGB(unit)
	local _, class = UnitClass(unit)
	local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
	if color then
		return color:GetRGB()
	end
	return 1, 1, 1
end

local function Paint(unit, plate)
	local f = Overlay()
	local bar = Bar(plate)

	local name = DisplayName(unit .. "target")
	f.name:ClearAllPoints()
	f.name:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -1)
	if name ~= nil then
		f.name:SetText(name)
		f.name:SetTextColor(ClassRGB(unit .. "target"))
		f.name:Show()
	else
		f.name:Hide()
	end

	if SHOW_CP then
		-- Forever: CP count is often secret — StatusBar SetValue accepts it;
		-- min/max per-dot lets the client fill without Lua comparing the value.
		local cp = GetComboPoints("player", unit)
		f.cps:ClearAllPoints()
		-- Above the bar (target-frame style readability); name stays below-right
		f.cps:SetPoint("BOTTOM", bar, "TOP", 0, 16)
		for i = 1, MAX_CP do
			f.dots[i]:SetValue(cp or 0)
		end
		if cp == nil or (not Secret(cp) and cp == 0) then
			f.cps:Hide()
		else
			f.cps:Show()
		end
	else
		f.cps:Hide()
	end

	f:Show()
end

CreateFrame("Frame"):SetScript("OnUpdate", function(_, dt)
	t = t + dt
	if t < 0.2 then
		return
	end
	t, n = 0, 0

	local plates = C_NamePlate.GetNamePlates() or {}
	local hard = {}

	for _, plate in ipairs(plates) do
		local unit = plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if type(unit) == "string" and not Secret(unit) and unit:find("^nameplate") then
			hard[#hard + 1] = unit
			pcall(Paint, unit, plate)
		end
	end

	for _, plate in ipairs(plates) do
		local unit = plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit == "softenemy" or unit == "softfriend" or unit == "softinteract" then
			local covered = false
			for i = 1, #hard do
				local same = UnitIsUnit(unit, hard[i])
				if Secret(same) or same then
					covered = true
					break
				end
			end
			if not covered then
				pcall(Paint, unit, plate)
			end
		end
	end

	for i = n + 1, #pool do
		pool[i]:Hide()
	end
end)
