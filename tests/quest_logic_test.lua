-- Offline tests for PandiaQuestMarkersQuestLogic. Run from repo root:
--   lua tests/quest_logic_test.lua

local here = arg and arg[0] or "./quest_logic_test.lua"
local dir = here:match("^(.*[/\\])") or ""
dofile(dir .. "../PandiaQuestMarkers/QuestLogic.lua")

local M = PandiaQuestMarkersQuestLogic
local fails = 0
local SECRET = {}
issecretvalue = function(v)
	return v == SECRET
end

local TYPES = { QuestObjective = "obj", QuestTitle = "title" }

local function check(name, got, want)
	if got == want then
		return
	end
	fails = fails + 1
	print("FAIL " .. name .. ": got " .. tostring(got) .. " want " .. tostring(want))
end

local function work(lines, isComplete)
	local state, reason = M.QuestWorkStateFromLines(lines, isComplete, false, TYPES)
	return state, reason
end

local state, reason = work({
	{ type = "obj", completed = false, leftText = "Boars" },
}, nil)
check("incomplete completed=false", state, true)
check("incomplete reason", reason, "incomplete_objective")

state, reason = work({
	{ type = "obj", completed = true, leftText = "Boars" },
}, nil)
check("finished completed=true", state, false)
check("finished reason", reason, "objectives_finished")

state, reason = work({
	{ type = "obj", numFulfilled = 2, numRequired = 2, leftText = "Boars" },
}, nil)
check("finished counts", state, false)

state, reason = work({
	{ type = "obj", leftText = "0 / 3 Boars" },
}, nil)
check("incomplete text", state, true)

state, reason = work({
	{ type = "obj", completed = SECRET, numFulfilled = SECRET, numRequired = SECRET, leftText = SECRET },
}, nil)
check("secret state", state, nil)
check("secret reason", reason, "objectives_secret")

state, reason = work({
	{ type = "title", id = 12, leftText = "A Simple Task" },
}, function(id)
	if id == 12 then
		return false
	end
	return nil
end)
check("title incomplete", state, true)
check("title incomplete reason", reason, "quest_not_complete")

state, reason = work({
	{ type = "title", id = 12, leftText = "A Simple Task" },
}, function()
	return true
end)
check("title complete", state, false)
check("title complete reason", reason, "quest_complete")

state, reason = work({
	{ type = "other", leftText = "Hello" },
}, nil)
check("no quest lines", state, nil)
check("no quest lines reason", reason, "no_quest_tooltip_lines")

state, reason = M.QuestWorkStateFromLines(nil, nil, false, TYPES)
check("nil lines", reason, "no_tooltip_data")

local d = M.Decide(true, false, false, "quest_complete")
check("friendly turn-in ok", d.ok, true)
check("friendly turn-in reason", d.reason, "friendly_related")
check("friendly turn-in uncertain", d.uncertain, nil)

d = M.Decide(true, true, true, "incomplete_objective")
check("hostile incomplete ok", d.ok, true)
check("hostile incomplete reason", d.reason, "hostile_incomplete_objective")

d = M.Decide(true, true, false, "objectives_finished")
check("hostile finished ok", d.ok, false)
check("hostile finished reason", d.reason, "hostile_skip_objectives_finished")
check("hostile finished uncertain", d.uncertain, nil)

d = M.Decide(true, true, nil, "objectives_secret")
check("hostile secret ok", d.ok, false)
check("hostile secret uncertain", d.uncertain, true)
check("hostile secret reason", d.reason, "hostile_unknown_objectives_secret")

d = M.Decide(false, true, true, "incomplete_objective")
check("unrelated ok", d.ok, false)
check("unrelated reason", d.reason, "not_related")

d = M.Decide(true, true, true, "incomplete_objective", true)
check("tap denied ok", d.ok, false)
check("tap denied reason", d.reason, "tap_denied")
check("tap denied uncertain", d.uncertain, nil)

d = M.Decide(true, false, false, "quest_complete", true)
check("tap denied friendly ok", d.ok, false)
check("tap denied friendly reason", d.reason, "tap_denied")

if fails > 0 then
	print(fails .. " failed")
	os.exit(1)
end
print("ok")
