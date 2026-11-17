-- Pure toast layout / sticky rules (no WoW API). Shared by the addon and offline tests.
PandiaQuestMarkersToastLogic = PandiaQuestMarkersToastLogic or {}
local M = PandiaQuestMarkersToastLogic

function M.ClampSlotCount(n, maxSlots)
	n = tonumber(n) or 1
	maxSlots = tonumber(maxSlots) or 4
	if n < 1 then
		return 1
	elseif n > maxSlots then
		return maxSlots
	end
	return n
end

function M.ToastWidthForCount(n, minW, slotW, maxSlots)
	n = M.ClampSlotCount(n, maxSlots)
	minW = tonumber(minW) or 0
	slotW = tonumber(slotW) or 90
	return math.max(minW, 32 + n * slotW)
end

-- Body min = title string + padding + close, floored to at least `floor`.
function M.TitleMinWidth(titleWidth, titlePad, closeW, floor)
	titleWidth = tonumber(titleWidth) or 0
	titlePad = tonumber(titlePad) or 0
	closeW = tonumber(closeW) or 0
	floor = tonumber(floor) or 0
	local minW = math.ceil(titleWidth + titlePad + closeW)
	if minW < floor then
		return floor
	end
	return minW
end

-- Left inset so n slots are centered in shellW (same floor as LayoutToastButtons).
function M.SlotLeft(shellW, n, slotW)
	shellW = tonumber(shellW) or 0
	n = tonumber(n) or 1
	if n < 1 then
		n = 1
	end
	slotW = tonumber(slotW) or 90
	local left = (shellW - n * slotW) / 2
	if left < 8 then
		return 8
	end
	return left
end

-- First icon in order that is not blocked. nil when every icon is taken.
function M.ReservePeek(order, blocked)
	if type(order) ~= "table" or #order < 1 then
		return nil
	end
	blocked = blocked or {}
	for i = 1, #order do
		local icon = order[i]
		if not blocked[icon] then
			return icon
		end
	end
	return nil
end

local function stillNeeded(u)
	return u and not u.dead and not u.marked and u.questOk and not u.suppressed
end

local function isNameplate(unit)
	return type(unit) == "string" and unit:match("^nameplate%d") ~= nil
end

local function kindKey(kind)
	if type(kind.guid) == "string" and kind.guid ~= "" then
		return kind.guid
	end
	return kind.name
end

local function byNameThenGuid(a, b)
	if a.name == b.name then
		return (a.guid or "") < (b.guid or "")
	end
	return a.name < b.name
end

-- units: list of {name, guid, dead, marked, questOk, suppressed?, unit?}
-- One row per guid. Same name stays as separate rows so each can take the next icon.
-- A later nameplate token replaces target/mouseover for that guid.
function M.CollectKinds(units)
	local byGuid = {}
	if type(units) ~= "table" then
		return {}
	end
	for i = 1, #units do
		local u = units[i]
		if type(u) == "table" and type(u.name) == "string" and u.name ~= "" and u.name ~= "?" then
			if stillNeeded(u) and type(u.guid) == "string" and u.guid ~= "" then
				local prev = byGuid[u.guid]
				if not prev then
					byGuid[u.guid] = {
						name = u.name,
						guid = u.guid,
						unit = u.unit,
					}
				elseif isNameplate(u.unit) and not isNameplate(prev.unit) then
					prev.unit = u.unit
				end
			end
		end
	end
	local list = {}
	for _, info in pairs(byGuid) do
		list[#list + 1] = info
	end
	table.sort(list, byNameThenGuid)
	return list
end

-- kinds: sticky rows.
-- liveByGuid: guid -> snapshot of that unit if we can currently see it.
-- Missing guid stays (out of range). A seen unit that is dead, marked, done, or suppressed is dropped.
function M.RefreshSticky(kinds, liveByGuid)
	local out = {}
	if type(kinds) ~= "table" then
		return out
	end
	liveByGuid = liveByGuid or {}
	for i = 1, #kinds do
		local kind = kinds[i]
		local name = kind and kind.name
		if type(name) == "string" and name ~= "" and type(kind.guid) == "string" and kind.guid ~= "" then
			local live = liveByGuid[kind.guid]
			if live == nil then
				out[#out + 1] = {
					name = name,
					guid = kind.guid,
					unit = kind.unit,
				}
			elseif stillNeeded(live) then
				out[#out + 1] = {
					name = name,
					guid = kind.guid,
					unit = live.unit or kind.unit,
				}
			end
		end
	end
	return out
end

-- Live rows replace the same guid. Other guids in held are kept. Result is sorted by name, then guid.
function M.MergeKinds(held, live)
	local byGuid = {}
	local function add(list)
		if type(list) ~= "table" then
			return
		end
		for i = 1, #list do
			local kind = list[i]
			if type(kind) == "table" and type(kind.name) == "string" and kind.name ~= "" then
				byGuid[kindKey(kind)] = kind
			end
		end
	end
	add(held)
	add(live)
	local out = {}
	for _, kind in pairs(byGuid) do
		out[#out + 1] = kind
	end
	table.sort(out, byNameThenGuid)
	return out
end
