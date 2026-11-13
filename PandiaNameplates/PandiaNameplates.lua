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
		name = { enabled = true, position = "BOTTOMRIGHT" },
		cps = { enabled = true, position = "BOTTOMLEFT" },
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

local function ValidPos(pos)
	return POS_ANCHOR[pos] and pos or nil
end

local function AnchorToBar(region, bar, position, justifyH)
	local a = POS_ANCHOR[ValidPos(position) or "BOTTOM"]
	region:ClearAllPoints()
	region:SetPoint(a[1], bar, a[2], a[3], a[4])
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
	local base = (uf and uf:GetFrameLevel()) or plate:GetFrameLevel() or 0
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
			AnchorToBar(f.name, bar, pos)
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
				AnchorToBar(f.cps, bar, ValidPos(DB.cps.position) or "BOTTOMLEFT")
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

-- Options (Esc > Options > AddOns) ------------------------------------------

local settingsCategory

local function PosOptions()
	local container = Settings.CreateControlTextContainer()
	for _, pos in ipairs(POSITIONS) do
		container:Add(pos, POS_LABEL[pos]())
	end
	return container:GetData()
end

local function RegisterOptions()
	local category = Settings.RegisterVerticalLayoutCategory(L.OPTIONS_TITLE)
	settingsCategory = category

	local nameEnabled = Settings.RegisterAddOnSetting(
		category, "PANDIA_NP_NAME_ENABLED", "enabled", DB.name,
		Settings.VarType.Boolean, L.TOT_NAME, true
	)
	Settings.CreateCheckbox(category, nameEnabled, L.TOT_NAME)

	local namePos = Settings.RegisterAddOnSetting(
		category, "PANDIA_NP_NAME_POS", "position", DB.name,
		Settings.VarType.String, L.TOT_NAME .. " — " .. L.POSITION, "BOTTOMRIGHT"
	)
	Settings.CreateDropdown(category, namePos, PosOptions, L.POSITION)

	if SHOW_CP_CLASS then
		local cpsEnabled = Settings.RegisterAddOnSetting(
			category, "PANDIA_NP_CPS_ENABLED", "enabled", DB.cps,
			Settings.VarType.Boolean, L.COMBO, true
		)
		Settings.CreateCheckbox(category, cpsEnabled, L.COMBO)

		local cpsPos = Settings.RegisterAddOnSetting(
			category, "PANDIA_NP_CPS_POS", "position", DB.cps,
			Settings.VarType.String, L.COMBO .. " — " .. L.POSITION, "BOTTOMLEFT"
		)
		Settings.CreateDropdown(category, cpsPos, PosOptions, L.POSITION)
	end

	Settings.RegisterAddOnCategory(category)
end

local function OpenOptions()
	if not settingsCategory then
		return
	end
	if InCombatLockdown() then
		print("|cffeda55fPandia Nameplates:|r " .. (L.OPTIONS_COMBAT or "Leave combat to open options."))
		return
	end
	Settings.OpenToCategory(settingsCategory:GetID())
end

SLASH_PANDIANP1 = "/pnplates"
SLASH_PANDIANP2 = "/pandianp"
SlashCmdList.PANDIANP = OpenOptions

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
	if name ~= "PandiaNameplates" then
		return
	end
	PandiaNameplatesDB = PandiaNameplatesDB or {}
	CopyDefaults(PandiaNameplatesDB, Defaults())
	DB = PandiaNameplatesDB
	RegisterOptions()
	loader:UnregisterEvent("ADDON_LOADED")
end)
