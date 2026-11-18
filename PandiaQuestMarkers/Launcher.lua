-- Minimap button + optional Addon Compartment entry. Identical across Pandia addons.
local ADDON = ...
local L = _G[ADDON .. "Locale"]
local ICON = "Interface\\AddOns\\" .. ADDON .. "\\pandia-icon"

PandiaLauncher = PandiaLauncher or {}
local M = {}
PandiaLauncher[ADDON] = M

local db
local openOptions
local button
local compartmentEntry
local widgets = {}

local function MinimapDB()
	db.minimap = db.minimap or {}
	if db.minimap.show == nil then
		db.minimap.show = true
	end
	if db.minimap.compartment == nil then
		db.minimap.compartment = true
	end
	if type(db.minimap.minimapPos) ~= "number" then
		db.minimap.minimapPos = 220
	end
	return db.minimap
end

local function UpdateButtonPosition()
	if not button then
		return
	end
	local angle = math.rad(MinimapDB().minimapPos or 220)
	local radius = (Minimap:GetWidth() / 2) + 5
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function EnsureButton()
	if button then
		return button
	end
	button = CreateFrame("Button", ADDON .. "MinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetTexture(ICON)
	icon:SetPoint("CENTER", 0, 1)
	button.icon = icon

	button:SetScript("OnClick", function(_, mouse)
		if mouse == "LeftButton" and openOptions then
			openOptions()
		end
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(L.OPTIONS_TITLE)
		GameTooltip:AddLine(L.TIP_MINIMAP_BUTTON, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			cx, cy = cx / scale, cy / scale
			MinimapDB().minimapPos = math.deg(math.atan2(cy - my, cx - mx)) % 360
			UpdateButtonPosition()
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
	end)
	return button
end

local function ApplyMinimap()
	local m = MinimapDB()
	if m.show then
		EnsureButton():Show()
		UpdateButtonPosition()
	elseif button then
		button:Hide()
	end
end

local function RemoveCompartment()
	if not compartmentEntry or not AddonCompartmentFrame or not AddonCompartmentFrame.registeredAddons then
		compartmentEntry = nil
		return
	end
	local list = AddonCompartmentFrame.registeredAddons
	for i = 1, #list do
		if list[i] == compartmentEntry then
			table.remove(list, i)
			if AddonCompartmentFrame.UpdateDisplay then
				AddonCompartmentFrame:UpdateDisplay()
			end
			break
		end
	end
	compartmentEntry = nil
end

local function ApplyCompartment()
	if not AddonCompartmentFrame or not AddonCompartmentFrame.RegisterAddon then
		return
	end
	local m = MinimapDB()
	if not m.compartment then
		RemoveCompartment()
		return
	end
	if compartmentEntry then
		return
	end
	compartmentEntry = {
		text = L.OPTIONS_TITLE,
		icon = ICON,
		notCheckable = true,
		func = function()
			if openOptions then
				openOptions()
			end
		end,
	}
	AddonCompartmentFrame:RegisterAddon(compartmentEntry)
end

function M.Defaults()
	return {
		minimap = {
			show = true,
			compartment = true,
			minimapPos = 220,
		},
	}
end

function M.Setup(database, openFn)
	db = database
	openOptions = openFn
	MinimapDB()
	ApplyMinimap()
	ApplyCompartment()
end

function M.Refresh()
	if not db then
		return
	end
	local m = MinimapDB()
	if widgets.show then
		widgets.show:SetChecked(m.show and true or false)
	end
	if widgets.compartment then
		widgets.compartment:SetChecked(m.compartment and true or false)
	end
end

function M.AddOptions(parent, y)
	local section = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	section:SetPoint("TOPLEFT", 16, y)
	section:SetText(L.SECTION_LAUNCHER)
	y = y - 28

	widgets.show = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	widgets.show:SetPoint("TOPLEFT", 16, y)
	local showLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	showLabel:SetPoint("LEFT", widgets.show, "RIGHT", 4, 0)
	showLabel:SetText(string.format(L.SHOW_MINIMAP, L.OPTIONS_TITLE))
	widgets.show:SetScript("OnClick", function(self)
		MinimapDB().show = self:GetChecked() and true or false
		ApplyMinimap()
	end)
	y = y - 32

	widgets.compartment = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	widgets.compartment:SetPoint("TOPLEFT", 16, y)
	local compLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	compLabel:SetPoint("LEFT", widgets.compartment, "RIGHT", 4, 0)
	compLabel:SetText(L.SHOW_COMPARTMENT)
	widgets.compartment:SetScript("OnClick", function(self)
		MinimapDB().compartment = self:GetChecked() and true or false
		ApplyCompartment()
	end)
	y = y - 36

	local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	reset:SetSize(220, 22)
	reset:SetPoint("TOPLEFT", 16, y)
	reset:SetText(L.RESET_MINIMAP)
	reset:SetScript("OnClick", function()
		MinimapDB().minimapPos = 220
		UpdateButtonPosition()
	end)
	y = y - 36

	M.Refresh()
	return y
end
