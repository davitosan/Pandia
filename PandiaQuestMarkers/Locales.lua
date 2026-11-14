-- Locale strings for Pandia Quest Markers. enUS is the fallback.

local L = {}
PandiaQuestMarkersLocale = L

local locale = GetLocale()

L.OPTIONS_TITLE = "Pandia Quest Markers"
L.SECTION_CONTEXT = "Enable marking"
L.SECTION_SOUND = "Sound"
L.CTX_SOLO = "Solo"
L.CTX_GROUP = "Group"
L.CTX_RAID = "Raid"
L.CTX_PVP = "PvP"
L.CLICK_MARK = "Click-to-mark toast (out of nameplate range)"
L.CLICK_MARK_FMT = "Click to mark %s"
L.CLICK_MARK_UNKNOWN = "quest target"
L.DEBUG = "Debug logging (chat)"
L.SOUND_ENABLE = "Play on new mark"
L.SOUND_WHEN = "Play when"
L.SOUND_WHEN_NAMEPLATE = "Nameplate shown"
L.SOUND_WHEN_MOUSEOVER = "Mouseover"
L.SOUND_WHEN_TARGET = "Target"
L.SOUND_WHEN_SOFT = "Soft target"
L.SOUND_WHEN_OBJECT = "World object"
L.SOUND_WHEN_ALL = "All triggers"
L.SOUND_WHEN_NONE = "None"
L.SOUND = "Sound"
L.SOUND_CHANNEL = "Channel"
L.SOUND_PREVIEW = "Preview"
L.SOUND_QUEST = "Quest ping"
L.SOUND_QUEST_COMPLETE = "Quest complete"
L.SOUND_QUEST_OPEN = "Quest log open"
L.SOUND_MAP = "Map ping"
L.SOUND_RAID = "Raid warning"
L.SOUND_READY = "Ready check"
L.SOUND_TELL = "Whisper"
L.SOUND_INVITE = "Group invite"
L.SOUND_AUCTION = "Auction open"
L.SOUND_ALARM1 = "Alarm 1"
L.SOUND_ALARM2 = "Alarm 2"
L.SOUND_ALARM3 = "Alarm 3"
L.SOUND_LEVELUP = "Level up"
L.SOUND_LOOT = "Loot window"
L.SOUND_FISHING = "Fishing reel"
L.SOUND_MAIL = "Bag open"
L.SOUND_MENU_OPEN = "Menu open"
L.SOUND_MENU_CLOSE = "Menu close"
L.SOUND_PVP = "PvP update"
L.SOUND_FRIEND = "Alert toast"
L.CHAN_MASTER = "Master"
L.CHAN_SFX = "SFX"
L.CHAN_MUSIC = "Music"
L.CHAN_AMBIENCE = "Ambience"
L.CHAN_DIALOG = "Dialog"

if locale == "deDE" then
	L.SECTION_CONTEXT, L.SECTION_SOUND = "Markierung aktivieren", "Sound"
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Solo", "Gruppe", "Schlachtzug", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL, L.SOUND_PREVIEW =
		"Bei neuer Markierung", "Sound", "Kanal", "Vorschau"
	L.CHAN_MASTER, L.CHAN_SFX, L.CHAN_MUSIC, L.CHAN_AMBIENCE, L.CHAN_DIALOG =
		"Master", "SFX", "Musik", "Umgebung", "Dialog"
elseif locale == "esES" or locale == "esMX" then
	L.SECTION_CONTEXT, L.SECTION_SOUND = "Activar marcado", "Sonido"
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Solo", "Grupo", "Banda", "JcJ"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL, L.SOUND_PREVIEW =
		"Al marcar nuevo", "Sonido", "Canal", "Vista previa"
elseif locale == "frFR" then
	L.SECTION_CONTEXT, L.SECTION_SOUND = "Activer le marquage", "Son"
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Solo", "Groupe", "Raid", "JcJ"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL, L.SOUND_PREVIEW =
		"À nouveau marquage", "Son", "Canal", "Aperçu"
elseif locale == "ruRU" then
	L.SECTION_CONTEXT, L.SECTION_SOUND = "Включить метки", "Звук"
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "Соло", "Группа", "Рейд", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL, L.SOUND_PREVIEW =
		"При новой метке", "Звук", "Канал", "Прослушать"
elseif locale == "zhCN" then
	L.SECTION_CONTEXT, L.SECTION_SOUND = "启用标记", "音效"
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "单人", "小队", "团队", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL, L.SOUND_PREVIEW =
		"新标记时播放", "音效", "声道", "试听"
elseif locale == "zhTW" then
	L.SECTION_CONTEXT, L.SECTION_SOUND = "啟用標記", "音效"
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "單人", "隊伍", "團隊", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL, L.SOUND_PREVIEW =
		"新標記時播放", "音效", "聲道", "試聽"
elseif locale == "koKR" then
	L.SECTION_CONTEXT, L.SECTION_SOUND = "징표 사용", "소리"
	L.CTX_SOLO, L.CTX_GROUP, L.CTX_RAID, L.CTX_PVP = "솔로", "파티", "공격대", "PvP"
	L.SOUND_ENABLE, L.SOUND, L.SOUND_CHANNEL, L.SOUND_PREVIEW =
		"새 징표 시 재생", "소리", "채널", "미리듣기"
end
