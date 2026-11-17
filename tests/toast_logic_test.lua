-- Offline tests for PandiaQuestMarkersToastLogic. Run from repo root:
--   lua tests/toast_logic_test.lua

local here = arg and arg[0] or "./toast_logic_test.lua"
local dir = here:match("^(.*[/\\])") or ""
dofile(dir .. "../PandiaQuestMarkers/ToastLogic.lua")

local M = PandiaQuestMarkersToastLogic
local fails = 0

local function eq(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not eq(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function check(name, got, want)
	if eq(got, want) then
		return
	end
	fails = fails + 1
	print("FAIL " .. name .. ": got " .. tostring(got) .. " want " .. tostring(want))
end

local function checkNear(name, got, want, eps)
	eps = eps or 0.01
	if type(got) == "number" and math.abs(got - want) <= eps then
		return
	end
	fails = fails + 1
	print("FAIL " .. name .. ": got " .. tostring(got) .. " want ~" .. tostring(want))
end

-- Clamp
check("clamp low", M.ClampSlotCount(0, 4), 1)
check("clamp high", M.ClampSlotCount(9, 4), 4)
check("clamp mid", M.ClampSlotCount(2, 4), 2)

-- Width: title min wins for 1 slot; grows with slots
check("width 1 vs large min", M.ToastWidthForCount(1, 200, 90, 4), 200)
check("width 1 vs small min", M.ToastWidthForCount(1, 50, 90, 4), 122) -- 32+90
check("width 2", M.ToastWidthForCount(2, 50, 90, 4), 212) -- 32+180
check("width 4", M.ToastWidthForCount(4, 50, 90, 4), 392) -- 32+360
check("width clamp 5", M.ToastWidthForCount(5, 50, 90, 4), 392)

-- Title min
check("title min floor", M.TitleMinWidth(10, 48, 32, 200), 200)
check("title min under floor", M.TitleMinWidth(100, 48, 32, 200), 200) -- 180 < 200 → floor
check("title min above floor", M.TitleMinWidth(150, 48, 32, 200), 230)

-- Centering: single slot in wide shell is centered, not left=14
checkNear("slot left 1 in 230", M.SlotLeft(230, 1, 90), (230 - 90) / 2)
checkNear("slot left 1 in 200", M.SlotLeft(200, 1, 90), (200 - 90) / 2)
check("slot left floor", M.SlotLeft(100, 2, 90), 8) -- content 180 > shell
checkNear("slot left 3 in 302", M.SlotLeft(302, 3, 90), (302 - 270) / 2)

-- Two unallocated names must not both claim the first free icon.
local order = { 8, 7, 6 }
local blocked = {}
local first = M.ReservePeek(order, blocked)
blocked[first] = true
local second = M.ReservePeek(order, blocked)
check("peek first", first, 8)
check("peek second", second, 7)
blocked[7] = true
blocked[6] = true
check("peek exhausted", M.ReservePeek(order, blocked), nil)

-- Collect: same name stays two rows; same guid collapses; filters; sort
local kinds = M.CollectKinds({
	{ name = "Zed", guid = "g1", dead = false, marked = false, questOk = true },
	{ name = "Ann", guid = "g2", unit = "target", dead = false, marked = false, questOk = true },
	{ name = "Ann", guid = "g2", unit = "nameplate1", dead = false, marked = false, questOk = true },
	{ name = "Ann", guid = "g3", unit = "nameplate2", dead = false, marked = false, questOk = true },
	{ name = "Dead", guid = "g4", dead = true, marked = false, questOk = true },
	{ name = "Marked", guid = "g5", dead = false, marked = true, questOk = true },
	{ name = "Nope", guid = "g6", dead = false, marked = false, questOk = false },
	{ name = "Supp", guid = "g7", dead = false, marked = false, questOk = true, suppressed = true },
	{ name = "?", guid = "g8", dead = false, marked = false, questOk = true },
})
check("collect count", #kinds, 3)
check("collect sort1", kinds[1].name, "Ann")
check("collect sort2", kinds[2].guid, "g3")
check("collect sort3", kinds[3].name, "Zed")
check("collect first Ann guid", kinds[1].guid, "g2")
check("collect nameplate token", kinds[1].unit, "nameplate1")

-- Sticky refresh
local sticky = {
	{ name = "Ann", guid = "g2" },
	{ name = "Ann", guid = "g3" },
	{ name = "Zed", guid = "g1" },
}
local kept = M.RefreshSticky(sticky, {
	g2 = { name = "Ann", guid = "g2", dead = false, marked = false, questOk = true },
	-- g3 is not in the map: out of sight, so she stays. Zed is visible but marked: drop.
	g1 = { name = "Zed", guid = "g1", dead = false, marked = true, questOk = true },
})
check("sticky keep count", #kept, 2)
check("sticky keep Ann", kept[1].guid, "g2")
check("sticky hold other Ann", kept[2].guid, "g3")

-- Neither guid is in sight: hold them until the caller expires the timer.
local held = M.RefreshSticky(sticky, {})
check("sticky hold unseen", #held, 3)
check("sticky hold Zed", held[3].name, "Zed")

local merged = M.MergeKinds(held, {
	{ name = "Ann", guid = "g2", unit = "nameplate4" },
	{ name = "Bea", guid = "g4" },
})
check("merge count", #merged, 4)
check("merge Ann guid", merged[1].guid, "g2")
check("merge Ann unit", merged[1].unit, "nameplate4")
check("merge other Ann", merged[2].guid, "g3")
check("merge Bea", merged[3].name, "Bea")
check("merge Zed", merged[4].name, "Zed")

if fails > 0 then
	print(fails .. " failed")
	os.exit(1)
end
print("ok")
