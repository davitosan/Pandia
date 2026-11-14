-- Locale strings for Pandia Quest Markers. enUS is the fallback.

local L = {}
PandiaQuestMarkersLocale = L

local locale = GetLocale()

L.OPTIONS_TITLE = "Pandia Quest Markers"
L.CTX_SOLO = "Solo"
L.CTX_GROUP = "Group"
L.CTX_RAID = "Raid"
L.CTX_PVP = "PvP"
L.SOUND_ENABLE = "Sound on new mark"
L.SOUND = "Sound"
L.SOUND_CHANNEL = "Sound channel"
L.SOUND_QUEST = "Quest ping"
L.SOUND_MAP = "Map ping"
L.SOUND_RAID = "Raid warning"
L.SOUND_TELL = "Whisper"
L.SOUND_AUCTION = "Auction open"
L.CHAN_MASTER = "Master"
L.CHAN_SFX = "SFX"
L.CHAN_MUSIC = "Music"
L.CHAN_AMBIENCE = "Ambience"
L.CHAN_DIALOG = "Dialog"

if locale == "deDE" then
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Solo", "Gruppe", "Schlachtzug", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL = "Sound bei neuer Markierung", "Sound", "Soundkanal"
	L.CHAN_MASTER, L.CHAN_SFX, L.CHAN_MUSIC, L.CHAN_AMBIENCE, L.CHAN_DIALOG =
		"Master", "SFX", "Musik", "Umgebung", "Dialog"
elseif locale == "esES" or locale == "esMX" then
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Solo", "Grupo", "Banda", "JcJ"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL = "Sonido al marcar", "Sonido", "Canal"
elseif locale == "frFR" then
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Solo", "Groupe", "Raid", "JcJ"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL = "Son à nouveau marquage", "Son", "Canal"
elseif locale == "ruRU" then
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Соло", "Группа", "Рейд", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL = "Звук при метке", "Звук", "Канал"
elseif locale == "zhCN" then
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "单人", "小队", "团队", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL = "新标记时播放音效", "音效", "声道"
elseif locale == "zhTW" then
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "單人", "隊伍", "團隊", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL = "新標記時播放音效", "音效", "聲道"
elseif locale == "koKR" then
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "솔로", "파티", "공격대", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL = "새 징표 소리", "소리", "채널"
end
