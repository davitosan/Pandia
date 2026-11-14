-- Locale strings for Pandia Nameplates options. enUS is the fallback.

local L = {}
PandiaNameplatesLocale = L

local locale = GetLocale()

L.OPTIONS_TITLE = "Pandia Nameplates"
L.SECTION_TOT = "Target-of-target"
L.SECTION_COMBO = "Combo points"
L.TOT_NAME = "Show name"
L.TOT_POSITION = "Position"
L.TOT_SCALE = "Scale"
L.COMBO = "Show combo points"
L.COMBO_HIDE_ZERO = "Hide at 0 points"
L.COMBO_POSITION = "Position"
L.COMBO_SCALE = "Scale"
L.ENABLED = "Enabled"
L.POSITION = "Position"
L.SCALE = "Scale"
L.POS_TOPLEFT = "Top left"
L.POS_TOP = "Top"
L.POS_TOPRIGHT = "Top right"
L.POS_LEFT = "Left"
L.POS_RIGHT = "Right"
L.POS_BOTTOMLEFT = "Bottom left"
L.POS_BOTTOM = "Bottom"
L.POS_BOTTOMRIGHT = "Bottom right"

if locale == "deDE" then
	L.SECTION_TOT, L.SECTION_COMBO = "Ziel des Ziels", "Combo-Punkte"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Name anzeigen", "Position", "Skalierung"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"Combo-Punkte anzeigen", "Bei 0 Punkten ausblenden", "Position", "Skalierung"
	L.ENABLED, L.POSITION, L.SCALE = "Aktiv", "Position", "Skalierung"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Oben links", "Oben", "Oben rechts"
	L.POS_LEFT, L.POS_RIGHT = "Links", "Rechts"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Unten links", "Unten", "Unten rechts"
elseif locale == "esES" or locale == "esMX" then
	L.SECTION_TOT, L.SECTION_COMBO = "Objetivo del objetivo", "Puntos de combo"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Mostrar nombre", "Posición", "Escala"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"Mostrar puntos de combo", "Ocultar con 0 puntos", "Posición", "Escala"
	L.ENABLED, L.POSITION, L.SCALE = "Activado", "Posición", "Escala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Arriba izquierda", "Arriba", "Arriba derecha"
	L.POS_LEFT, L.POS_RIGHT = "Izquierda", "Derecha"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Abajo izquierda", "Abajo", "Abajo derecha"
elseif locale == "frFR" then
	L.SECTION_TOT, L.SECTION_COMBO = "Cible de la cible", "Points de combo"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Afficher le nom", "Position", "Échelle"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"Afficher les points de combo", "Masquer à 0 points", "Position", "Échelle"
	L.ENABLED, L.POSITION, L.SCALE = "Activé", "Position", "Échelle"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Haut gauche", "Haut", "Haut droite"
	L.POS_LEFT, L.POS_RIGHT = "Gauche", "Droite"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Bas gauche", "Bas", "Bas droite"
elseif locale == "itIT" then
	L.SECTION_TOT, L.SECTION_COMBO = "Bersaglio del bersaglio", "Punti combo"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Mostra nome", "Posizione", "Scala"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"Mostra punti combo", "Nascondi a 0 punti", "Posizione", "Scala"
	L.ENABLED, L.POSITION, L.SCALE = "Attivo", "Posizione", "Scala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Alto sinistra", "Alto", "Alto destra"
	L.POS_LEFT, L.POS_RIGHT = "Sinistra", "Destra"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Basso sinistra", "Basso", "Basso destra"
elseif locale == "ptBR" then
	L.SECTION_TOT, L.SECTION_COMBO = "Alvo do alvo", "Pontos de combo"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Mostrar nome", "Posição", "Escala"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"Mostrar pontos de combo", "Ocultar com 0 pontos", "Posição", "Escala"
	L.ENABLED, L.POSITION, L.SCALE = "Ativado", "Posição", "Escala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Superior esquerdo", "Superior", "Superior direito"
	L.POS_LEFT, L.POS_RIGHT = "Esquerda", "Direita"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Inferior esquerdo", "Inferior", "Inferior direito"
elseif locale == "ruRU" then
	L.SECTION_TOT, L.SECTION_COMBO = "Цель цели", "Комбо-очки"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Показывать имя", "Позиция", "Масштаб"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"Показывать комбо-очки", "Скрывать при 0 очках", "Позиция", "Масштаб"
	L.ENABLED, L.POSITION, L.SCALE = "Включено", "Позиция", "Масштаб"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Сверху слева", "Сверху", "Сверху справа"
	L.POS_LEFT, L.POS_RIGHT = "Слева", "Справа"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Снизу слева", "Снизу", "Снизу справа"
elseif locale == "koKR" then
	L.SECTION_TOT, L.SECTION_COMBO = "대상의 대상", "연계 점수"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "이름 표시", "위치", "크기"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"연계 점수 표시", "0점일 때 숨기기", "위치", "크기"
	L.ENABLED, L.POSITION, L.SCALE = "사용", "위치", "크기"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "왼쪽 위", "위", "오른쪽 위"
	L.POS_LEFT, L.POS_RIGHT = "왼쪽", "오른쪽"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "왼쪽 아래", "아래", "오른쪽 아래"
elseif locale == "zhCN" then
	L.SECTION_TOT, L.SECTION_COMBO = "目标的目标", "连击点"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "显示名字", "位置", "缩放"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"显示连击点", "0 点时隐藏", "位置", "缩放"
	L.ENABLED, L.POSITION, L.SCALE = "启用", "位置", "缩放"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_LEFT, L.POS_RIGHT = "左侧", "右侧"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
elseif locale == "zhTW" then
	L.SECTION_TOT, L.SECTION_COMBO = "目標的目標", "連擊點"
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "顯示名字", "位置", "縮放"
	L.COMBO, L.COMBO_HIDE_ZERO, L.COMBO_POSITION, L.COMBO_SCALE =
		"顯示連擊點", "0 點時隱藏", "位置", "縮放"
	L.ENABLED, L.POSITION, L.SCALE = "啟用", "位置", "縮放"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_LEFT, L.POS_RIGHT = "左側", "右側"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
end
