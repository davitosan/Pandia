-- Locale strings for Pandia Quest Links. enUS is the fallback.

local L = {}
PandiaQuestLinksLocale = L

local locale = GetLocale()

L.FAILED = "Failed"
L.READY = "Ready to turn in"
L.ON_QUEST = "You are on this quest"
L.COMPLETED = "Completed"
L.NONE = "Not on this quest"

L.OPTIONS_TITLE = "Pandia Quest Links"
L.OPTIONS_HINT = "Options > AddOns, or /pql — custom text + color per state"
L.OPTIONS_COMBAT = "Leave combat to open options."
L.COL_ENABLE = "On"
L.COL_TEXT = "Text"
L.COL_COLOR = "Color"
L.LABEL_FAILED = "Failed"
L.LABEL_READY = "Ready to turn in"
L.LABEL_ON_QUEST = "On quest"
L.LABEL_COMPLETED = "Completed"
L.LABEL_NONE = "No status"
L.RESET = "Reset defaults"

if locale == "deDE" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"Fehlgeschlagen", "Abgabebereit", "Du bist auf dieser Quest", "Abgeschlossen", "Nicht auf dieser Quest"
	L.OPTIONS_TITLE, L.OPTIONS_HINT = "Pandia Quest Links", "Options > AddOns, or /pql  —  Text + Farbe pro Status"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "An", "Text", "Farbe"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"Fehlgeschlagen", "Abgabebereit", "Auf Quest", "Abgeschlossen", "Kein Status"
	L.RESET = "Standard"
elseif locale == "esES" or locale == "esMX" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"Fallida", "Lista para entregar", "Estás en esta misión", "Completada", "No estás en esta misión"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  texto + color por estado"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "Sí", "Texto", "Color"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"Fallida", "Lista para entregar", "En misión", "Completada", "Sin estado"
	L.RESET = "Restablecer"
elseif locale == "frFR" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"Échouée", "Prête à être rendue", "Vous êtes sur cette quête", "Terminée", "Pas sur cette quête"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  texte + couleur par état"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "Oui", "Texte", "Couleur"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"Échouée", "Prête à rendre", "Sur la quête", "Terminée", "Aucun statut"
	L.RESET = "Réinitialiser"
elseif locale == "itIT" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"Fallita", "Pronta per la consegna", "Sei in questa missione", "Completata", "Non in questa missione"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  testo + colore per stato"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "Sì", "Testo", "Colore"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"Fallita", "Pronta", "In missione", "Completata", "Nessuno stato"
	L.RESET = "Predefiniti"
elseif locale == "ptBR" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"Fracassada", "Pronta para entregar", "Você está nesta missão", "Concluída", "Não está nesta missão"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  texto + cor por estado"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "Sim", "Texto", "Cor"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"Fracassada", "Pronta", "Na missão", "Concluída", "Sem status"
	L.RESET = "Redefinir"
elseif locale == "ruRU" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"Провален", "Можно сдать", "Вы выполняете это задание", "Выполнено", "Не на этом задании"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  текст + цвет для каждого статуса"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "Вкл", "Текст", "Цвет"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"Провален", "Можно сдать", "На задании", "Выполнено", "Без статуса"
	L.RESET = "Сброс"
elseif locale == "koKR" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"실패", "완료 가능", "진행 중인 퀘스트", "완료", "진행하지 않음"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  상태별 텍스트 + 색상"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "사용", "텍스트", "색상"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"실패", "완료 가능", "진행 중", "완료", "상태 없음"
	L.RESET = "초기화"
elseif locale == "zhCN" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"失败", "可交还", "正在进行此任务", "已完成", "未接此任务"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  各状态自定义文字与颜色"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "启用", "文字", "颜色"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"失败", "可交还", "进行中", "已完成", "无状态"
	L.RESET = "恢复默认"
elseif locale == "zhTW" then
	L.FAILED, L.READY, L.ON_QUEST, L.COMPLETED, L.NONE =
		"失敗", "可回報", "正在進行此任務", "已完成", "未接此任務"
	L.OPTIONS_HINT = "Options > AddOns, or /pql  —  各狀態自訂文字與顏色"
	L.COL_ENABLE, L.COL_TEXT, L.COL_COLOR = "啟用", "文字", "顏色"
	L.LABEL_FAILED, L.LABEL_READY, L.LABEL_ON_QUEST, L.LABEL_COMPLETED, L.LABEL_NONE =
		"失敗", "可回報", "進行中", "已完成", "無狀態"
	L.RESET = "恢復預設"
end
