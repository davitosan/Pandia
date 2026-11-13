-- Locale strings for Pandia Nameplates options. enUS is the fallback.

local L = {}
PandiaNameplatesLocale = L

local locale = GetLocale()

L.OPTIONS_TITLE = "Pandia Nameplates"
L.OPTIONS_HINT = "Options > AddOns, or /pnplates"
L.OPTIONS_COMBAT = "Leave combat to open options."
L.TOT_NAME = "Target-of-target name"
L.COMBO = "Combo points"
L.ENABLED = "Enabled"
L.POSITION = "Position"
L.POS_TOPLEFT = "Top left"
L.POS_TOP = "Top"
L.POS_TOPRIGHT = "Top right"
L.POS_BOTTOMLEFT = "Bottom left"
L.POS_BOTTOM = "Bottom"
L.POS_BOTTOMRIGHT = "Bottom right"

if locale == "deDE" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  Ein/Aus + Position für ToT-Name und Combo-Punkte"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "Ziel-des-Ziels-Name", "Combo-Punkte", "Aktiv", "Position"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Oben links", "Oben", "Oben rechts"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Unten links", "Unten", "Unten rechts"
elseif locale == "esES" or locale == "esMX" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  activar + posición del nombre ToT y puntos de combo"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "Nombre del objetivo del objetivo", "Puntos de combo", "Activado", "Posición"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Arriba izquierda", "Arriba", "Arriba derecha"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Abajo izquierda", "Abajo", "Abajo derecha"
elseif locale == "frFR" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  activer + position du nom ToT et des points de combo"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "Nom de la cible de la cible", "Points de combo", "Activé", "Position"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Haut gauche", "Haut", "Haut droite"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Bas gauche", "Bas", "Bas droite"
elseif locale == "itIT" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  attiva + posizione nome ToT e punti combo"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "Nome del bersaglio del bersaglio", "Punti combo", "Attivo", "Posizione"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Alto sinistra", "Alto", "Alto destra"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Basso sinistra", "Basso", "Basso destra"
elseif locale == "ptBR" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  ativar + posição do nome ToT e pontos de combo"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "Nome do alvo do alvo", "Pontos de combo", "Ativado", "Posição"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Superior esquerdo", "Superior", "Superior direito"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Inferior esquerdo", "Inferior", "Inferior direito"
elseif locale == "ruRU" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  вкл/выкл + позиция имени ToT и комбо-очков"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "Имя цели цели", "Комбо-очки", "Включено", "Позиция"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Сверху слева", "Сверху", "Сверху справа"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Снизу слева", "Снизу", "Снизу справа"
elseif locale == "koKR" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  ToT 이름/연계 점수 표시 및 위치"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "대상의 대상 이름", "연계 점수", "사용", "위치"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "왼쪽 위", "위", "오른쪽 위"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "왼쪽 아래", "아래", "오른쪽 아래"
elseif locale == "zhCN" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  目标的目标名字与连击点的开关和位置"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "目标的目标名字", "连击点", "启用", "位置"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
elseif locale == "zhTW" then
	L.OPTIONS_HINT = "Options > AddOns, or /pnplates  —  目標的目標名字與連擊點的開關和位置"
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION = "目標的目標名字", "連擊點", "啟用", "位置"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
end
