-- Locale strings for Pandia Nameplates options. enUS is the fallback.

local L = {}
PandiaNameplatesLocale = L

local locale = GetLocale()

L.OPTIONS_TITLE = "Pandia Nameplates"
L.TOT_NAME = "Target-of-target name"
L.COMBO = "Combo points"
L.ENABLED = "Enabled"
L.POSITION = "Position"
L.SCALE = "Scale"
L.POS_TOPLEFT = "Top left"
L.POS_TOP = "Top"
L.POS_TOPRIGHT = "Top right"
L.POS_BOTTOMLEFT = "Bottom left"
L.POS_BOTTOM = "Bottom"
L.POS_BOTTOMRIGHT = "Bottom right"

if locale == "deDE" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "Ziel-des-Ziels-Name", "Combo-Punkte", "Aktiv", "Position", "Skalierung"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Oben links", "Oben", "Oben rechts"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Unten links", "Unten", "Unten rechts"
elseif locale == "esES" or locale == "esMX" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "Nombre del objetivo del objetivo", "Puntos de combo", "Activado", "Posición", "Escala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Arriba izquierda", "Arriba", "Arriba derecha"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Abajo izquierda", "Abajo", "Abajo derecha"
elseif locale == "frFR" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "Nom de la cible de la cible", "Points de combo", "Activé", "Position", "Échelle"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Haut gauche", "Haut", "Haut droite"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Bas gauche", "Bas", "Bas droite"
elseif locale == "itIT" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "Nome del bersaglio del bersaglio", "Punti combo", "Attivo", "Posizione", "Scala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Alto sinistra", "Alto", "Alto destra"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Basso sinistra", "Basso", "Basso destra"
elseif locale == "ptBR" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "Nome do alvo do alvo", "Pontos de combo", "Ativado", "Posição", "Escala"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Superior esquerdo", "Superior", "Superior direito"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Inferior esquerdo", "Inferior", "Inferior direito"
elseif locale == "ruRU" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "Имя цели цели", "Комбо-очки", "Включено", "Позиция", "Масштаб"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "Сверху слева", "Сверху", "Сверху справа"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "Снизу слева", "Снизу", "Снизу справа"
elseif locale == "koKR" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "대상의 대상 이름", "연계 점수", "사용", "위치", "크기"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "왼쪽 위", "위", "오른쪽 위"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "왼쪽 아래", "아래", "오른쪽 아래"
elseif locale == "zhCN" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "目标的目标名字", "连击点", "启用", "位置", "缩放"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
elseif locale == "zhTW" then
	L.TOT_NAME, L.COMBO, L.ENABLED, L.POSITION, L.SCALE = "目標的目標名字", "連擊點", "啟用", "位置", "縮放"
	L.POS_TOPLEFT, L.POS_TOP, L.POS_TOPRIGHT = "左上", "上方", "右上"
	L.POS_BOTTOMLEFT, L.POS_BOTTOM, L.POS_BOTTOMRIGHT = "左下", "下方", "右下"
end
