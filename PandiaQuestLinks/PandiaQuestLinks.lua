-- Appends local quest status after |Hquest: links in chat.

local function Annotate(questID)
	if C_QuestLog.IsOnQuest(questID) then
		if C_QuestLog.IsFailed(questID) then
			return "|cffff2020(Failed)|r";
		end
		if C_QuestLog.IsComplete(questID) then
			return "|cff40ff40(Ready to turn in)|r";
		end
		return "|cffffff00(You are on this quest)|r";
	end
	if C_QuestLog.IsQuestFlaggedCompleted(questID) then
		return "|cff9d9d9d(Completed)|r";
	end
	-- ponytail: no "(Not on this quest)" — add if you want the negative case
end

local function Filter(_, _, msg, ...)
	local newMsg = msg:gsub("(|Hquest:(%d+)[^|]*|h%b[]|h)(|r?)", function(link, questID, trailing)
		local status = Annotate(tonumber(questID));
		return status and (link .. trailing .. status) or (link .. trailing);
	end);
	if newMsg ~= msg then
		return false, newMsg, ...;
	end
end

for _, event in ipairs({
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
}) do
	ChatFrameUtil.AddMessageEventFilter(event, Filter);
end
