-- Pure quest-tooltip / mark decisions (no WoW API). Shared by the addon and offline tests.
PandiaQuestMarkersQuestLogic = PandiaQuestMarkersQuestLogic or {}
local M = PandiaQuestMarkersQuestLogic

function M.Secret(v)
	return v ~= nil and type(issecretvalue) == "function" and issecretvalue(v)
end

function M.SafeText(v)
	if v == nil or M.Secret(v) or type(v) ~= "string" then
		return nil
	end
	return v
end

function M.SafeNum(v)
	if v == nil or M.Secret(v) or type(v) ~= "number" then
		return nil
	end
	return v
end

function M.SafeBool(v)
	if v == nil or M.Secret(v) then
		return nil
	end
	if v == true then
		return true
	end
	if v == false then
		return false
	end
	return nil
end

-- true = incomplete, false = finished, nil = unknown (incl. secret Forever fields)
function M.TooltipObjectiveIncomplete(line)
	local completed = M.SafeBool(line.completed)
	if completed == true then
		return false
	end
	if completed == false then
		return true
	end
	local a, b = M.SafeNum(line.numFulfilled), M.SafeNum(line.numRequired)
	if a and b then
		return a < b
	end
	local text = M.SafeText(line.leftText)
	if text then
		local x, y = text:match("(%d+)%s*/%s*(%d+)")
		if x and y then
			return tonumber(x) < tonumber(y)
		end
	end
	return nil
end

-- work, reason, detail from tooltip lines (units or world objects).
-- isComplete(questID) -> true/false/nil. wantDetail includes debug strings.
function M.QuestWorkStateFromLines(lines, isComplete, wantDetail, lineTypes)
	if not lines then
		return nil, "no_tooltip_data", ""
	end
	lineTypes = lineTypes or (Enum and Enum.TooltipDataLineType)
	local objType = lineTypes and lineTypes.QuestObjective
	local titleType = lineTypes and lineTypes.QuestTitle
	local sawObjective = false
	local sawIncomplete = false
	local sawKnownObjective = false
	local sawCompleteQuest = false
	local sawIncompleteQuest = false
	local bits = {}
	for i = 1, #lines do
		local line = lines[i]
		local lineType = line.type
		if M.Secret(lineType) then
			-- skip opaque rows
		elseif objType and lineType == objType then
			sawObjective = true
			local state = M.TooltipObjectiveIncomplete(line)
			local label = M.SafeText(line.leftText) or "?"
			if state ~= nil then
				sawKnownObjective = true
				if state then
					sawIncomplete = true
				end
			end
			if wantDetail then
				bits[#bits + 1] = string.format(
					"obj[%s completed=%s %s/%s]",
					label,
					tostring(M.SafeBool(line.completed)),
					tostring(M.SafeNum(line.numFulfilled) or "?"),
					tostring(M.SafeNum(line.numRequired) or "?")
				)
			end
		elseif titleType and lineType == titleType then
			local qid = M.SafeNum(line.id)
			local complete = nil
			if qid and isComplete then
				complete = M.SafeBool(isComplete(qid))
			end
			local title = M.SafeText(line.leftText) or (qid and ("#" .. tostring(qid)) or "?")
			if complete == true then
				sawCompleteQuest = true
			elseif complete == false then
				sawIncompleteQuest = true
			end
			if wantDetail then
				bits[#bits + 1] = string.format(
					"title[%s id=%s IsComplete=%s]",
					title,
					tostring(qid or "?"),
					tostring(complete)
				)
			end
		end
	end
	local detail = table.concat(bits, "; ")
	if sawIncomplete then
		return true, "incomplete_objective", detail
	end
	if sawKnownObjective then
		return false, "objectives_finished", detail
	end
	if sawIncompleteQuest then
		return true, "quest_not_complete", detail
	end
	if sawCompleteQuest then
		return false, "quest_complete", detail
	end
	-- Objective rows present but every progress field was secret/unreadable.
	if sawObjective then
		return nil, "objectives_secret", detail
	end
	return nil, "no_quest_tooltip_lines", detail
end

-- Hostile: mark only while work is incomplete. Friendly related: always ok (turn-in).
-- work nil on a hostile is uncertain (hold marks / sound; do not clear).
function M.Decide(related, hostile, work, workReason)
	local meta = {
		ok = false,
		related = related and true or false,
		hostile = hostile and true or false,
		work = work,
		reason = "not_related",
	}
	if not meta.related then
		return meta
	end
	if meta.hostile then
		if work == true then
			meta.ok = true
			meta.reason = "hostile_" .. workReason
		elseif work == false then
			meta.ok = false
			meta.reason = "hostile_skip_" .. workReason
		else
			meta.ok = false
			meta.uncertain = true
			meta.reason = "hostile_unknown_" .. tostring(workReason)
		end
		return meta
	end
	meta.ok = true
	meta.reason = "friendly_related"
	return meta
end
