-- Locale strings for Pandia Nameplates options. enUS is the fallback.

local L = {}
PandiaNameplatesLocale = L

local locale = GetLocale()

L.OPTIONS_TITLE = "Pandia Nameplates"
L.TOT_NAME = "Target-of-target name"
L.TOT_POSITION = "ToT position"
L.TOT_SCALE = "ToT scale"
L.COMBO = "Combo points"
L.COMBO_POSITION = "Combo position"
L.COMBO_SCALE = "Combo scale"
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
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Ziel-des-Ziels-Name", "ToT-Position", "ToT-Skalierung"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "Combo-Punkte", "Combo-Position", "Combo-Skalierung"
	L.ENABLED, L.POSITION, L.SCALE = "Aktiv", "Position", "Skalierung"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Oben links", "Oben", "Oben rechts"
	L.POS_LEFT, L.POS_RIGHT = "Links", "Rechts"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Unten links", "Unten", "Unten rechts"
elseif locale == "esES" or locale == "esMX" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Nombre del objetivo del objetivo", "Posición ToT", "Escala ToT"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "Puntos de combo", "Posición combo", "Escala combo"
	L.ENABLED, L.POSITION, L.SCALE = "Activado", "Posición", "Escala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Arriba izquierda", "Arriba", "Arriba derecha"
	L.POS_LEFT, L.POS_RIGHT = "Izquierda", "Derecha"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Abajo izquierda", "Abajo", "Abajo derecha"
elseif locale == "frFR" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Nom de la cible de la cible", "Position ToT", "Échelle ToT"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "Points de combo", "Position combo", "Échelle combo"
	L.ENABLED, L.POSITION, L.SCALE = "Activé", "Position", "Échelle"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Haut gauche", "Haut", "Haut droite"
	L.POS_LEFT, L.POS_RIGHT = "Gauche", "Droite"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Bas gauche", "Bas", "Bas droite"
elseif locale == "itIT" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Nome del bersaglio del bersaglio", "Posizione ToT", "Scala ToT"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "Punti combo", "Posizione combo", "Scala combo"
	L.ENABLED, L.POSITION, L.SCALE = "Attivo", "Posizione", "Scala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Alto sinistra", "Alto", "Alto destra"
	L.POS_LEFT, L.POS_RIGHT = "Sinistra", "Destra"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Basso sinistra", "Basso", "Basso destra"
elseif locale == "ptBR" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Nome do alvo do alvo", "Posição ToT", "Escala ToT"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "Pontos de combo", "Posição combo", "Escala combo"
	L.ENABLED, L.POSITION, L.SCALE = "Ativado", "Posição", "Escala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Superior esquerdo", "Superior", "Superior direito"
	L.POS_LEFT, L.POS_RIGHT = "Esquerda", "Direita"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Inferior esquerdo", "Inferior", "Inferior direito"
elseif locale == "ruRU" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "Имя цели цели", "Позиция ToT", "Масштаб ToT"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "Комбо-очки", "Позиция комбо", "Масштаб комбо"
	L.ENABLED, L.POSITION, L.SCALE = "Включено", "Позиция", "Масштаб"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Сверху слева", "Сверху", "Сверху справа"
	L.POS_LEFT, L.POS_RIGHT = "Слева", "Справа"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Снизу слева", "Снизу", "Снизу справа"
elseif locale == "koKR" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "대상의 대상 이름", "ToT 위치", "ToT 크기"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "연계 점수", "연계 위치", "연계 크기"
	L.ENABLED, L.POSITION, L.SCALE = "사용", "위치", "크기"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "왼쪽 위", "위", "오른쪽 위"
	L.POS_LEFT, L.POS_RIGHT = "왼쪽", "오른쪽"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "왼쪽 아래", "아래", "오른쪽 아래"
elseif locale == "zhCN" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "目标的目标名字", "ToT 位置", "ToT 缩放"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "连击点", "连击位置", "连击缩放"
	L.ENABLED, L.POSITION, L.SCALE = "启用", "位置", "缩放"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_LEFT, L.POS_RIGHT = "左侧", "右侧"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
elseif locale == "zhTW" then
	L.TOT_NAME, L.TOT_POSITION, L.TOT_SCALE = "目標的目標名字", "ToT 位置", "ToT 縮放"
	L.COMBO, L.COMBO_POSITION, L.COMBO_SCALE = "連擊點", "連擊位置", "連擊縮放"
	L.ENABLED, L.POSITION, L.SCALE = "啟用", "位置", "縮放"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_LEFT, L.POS_RIGHT = "左側", "右側"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
end
