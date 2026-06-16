extends Node2D

# Рисует игровое поле процедурно в SubViewport 2048×2048

const CENTER     := Vector2(1024.0, 1024.0)
const R_OUTER    := 950.0   # внешний край клеток
const R_STRIPE   :=  855.0  # цветная полоса группы (для PROPERTY)
const R_INNER    :=  330.0  # внутренний край клеток / граница центра
const R_TEXT     :=  640.0  # радиус текста названия
const CELL_COUNT := 36
const CELL_ANGLE := TAU / CELL_COUNT
const ARC_SEGS   := 14      # точность дуг

const BORDER_COL  := Color(0.08, 0.08, 0.08, 1.0)
const BORDER_W    := 3.5

# Основные цвета заливки клеток
const BG_CELL := Color(0.10, 0.28, 0.12)   # тёмно-зелёный фон

# Цвета цветовых групп (полоса)
const GROUP_COLOR: Dictionary = {
	"YELLOW": Color(0.97, 0.86, 0.06),
	"GREEN":  Color(0.18, 0.78, 0.28),
	"WHITE":  Color(0.90, 0.90, 0.90),
	"BLUE":   Color(0.22, 0.46, 0.95),
	"PINK":   Color(0.96, 0.38, 0.74),
	"ORANGE": Color(0.97, 0.54, 0.08),
	"GRAY":   Color(0.54, 0.54, 0.60),
	"RED":    Color(0.93, 0.14, 0.14),
}

# Цвета особых клеток
const SPECIAL_COLOR: Dictionary = {
	"START":      Color(0.92, 0.78, 0.08),
	"JAIL":       Color(0.44, 0.44, 0.50),
	"GO_TO_JAIL": Color(0.80, 0.10, 0.10),
	"BETS":       Color(0.10, 0.10, 0.10),
	"CHANCE":     Color(0.90, 0.76, 0.10),
	"EVENT":      Color(0.55, 0.08, 0.82),
	"HOTEL":      Color(0.32, 0.20, 0.08),
}

var _font: Font
var _font_bold: Font
var _cells: Array = []

func _ready() -> void:
	_font      = ThemeDB.fallback_font
	_font_bold = ThemeDB.fallback_font
	_load_json()

func _load_json() -> void:
	var f := FileAccess.open("res://data/board_cells.json", FileAccess.READ)
	if not f:
		push_error("BoardRenderer: board_cells.json не найден")
		return
	var js := JSON.new()
	js.parse(f.get_as_text())
	f.close()
	_cells = js.data as Array
	queue_redraw()

# ─── Главная функция отрисовки ─────────────────────────────────────────

func _draw() -> void:
	# Фон
	draw_circle(CENTER, R_OUTER + 30, Color(0.04, 0.18, 0.06))

	# Клетки
	for cell in _cells:
		_draw_cell_bg(cell)

	# Внешняя обводка
	_draw_ring(R_OUTER, 5.0, BORDER_COL)

	# Центральный хаб (Чёрное / Красное)
	_draw_center()

	# Обводка центра
	_draw_ring(R_INNER, 4.0, BORDER_COL)

	# Текст поверх всего
	for cell in _cells:
		_draw_cell_text(cell)

# ─── Фон одной клетки ──────────────────────────────────────────────────

func _draw_cell_bg(cell: Dictionary) -> void:
	var idx: int   = cell.get("index", 0)
	var ctype: String = cell.get("type", "START")
	var group: String = cell.get("color_group", "NONE")

	var a0 := CELL_ANGLE * idx - PI / 2.0
	var a1 := a0 + CELL_ANGLE

	# Основная заливка
	var fill := _cell_fill_color(ctype, group)
	draw_colored_polygon(_sector(R_INNER, R_OUTER, a0, a1), fill)

	# Цветная полоса для PROPERTY / HOTEL
	if ctype == "PROPERTY":
		var stripe: Color = GROUP_COLOR.get(group, BG_CELL)
		draw_colored_polygon(_sector(R_STRIPE, R_OUTER, a0, a1), stripe)
		_ring_arc(R_STRIPE, a0, a1, 2.0, BORDER_COL)

	elif ctype == "HOTEL":
		draw_colored_polygon(_sector(R_STRIPE, R_OUTER, a0, a1), SPECIAL_COLOR["HOTEL"])
		_ring_arc(R_STRIPE, a0, a1, 2.0, BORDER_COL)

	# Радиальные линии-границы
	_radial(a0, R_INNER, R_OUTER, BORDER_COL)
	_radial(a1, R_INNER, R_OUTER, BORDER_COL)

# ─── Текст клетки ──────────────────────────────────────────────────────

func _draw_cell_text(cell: Dictionary) -> void:
	var idx: int      = cell.get("index", 0)
	var ctype: String = cell.get("type", "START")
	var group: String = cell.get("color_group", "NONE")
	var price: int    = cell.get("price", 0)

	var a0  := CELL_ANGLE * idx - PI / 2.0
	var a1  := a0 + CELL_ANGLE
	var mid := (a0 + a1) * 0.5

	# Радиус текста: ниже если есть полоса
	var tr := R_TEXT
	if ctype in ["PROPERTY", "HOTEL"]:
		tr = (R_INNER + R_STRIPE) * 0.5

	var pos := CENTER + Vector2(cos(mid), sin(mid)) * tr

	# Вращение: тангенциально, всегда читаемо
	var rot := mid + PI / 2.0
	if sin(mid) > 0.001:
		rot = mid - PI / 2.0

	# Цвет текста
	var tcol := Color.WHITE
	if group in ["WHITE", "GRAY"]:
		tcol = Color(0.08, 0.08, 0.08)

	var lines := _cell_lines(cell)
	_draw_text_block(pos, rot, lines, tcol, 20)

	# Цена
	if price > 0:
		var extra := lines.size() * 24 + 4
		_draw_text_single(pos, rot, "%dМ" % price, Color(1.0, 0.90, 0.20), 18, extra)

# ─── Центральный хаб (Ставки Ч/К) ─────────────────────────────────────

func _draw_center() -> void:
	# Левая половина — Чёрное
	draw_colored_polygon(_sector(0, R_INNER - 15, PI / 2.0, PI * 1.5), Color(0.08, 0.08, 0.08))
	# Правая половина — Красное
	draw_colored_polygon(_sector(0, R_INNER - 15, -PI / 2.0, PI / 2.0), Color(0.78, 0.06, 0.06))

	# Надписи
	var fs := 34
	draw_set_transform(CENTER + Vector2(-160, -18), 0.0, Vector2.ONE)
	draw_string(_font_bold, Vector2(-90, 0), "ЧЁРНОЕ",
			HORIZONTAL_ALIGNMENT_CENTER, 180, fs, Color.WHITE)
	draw_set_transform(CENTER + Vector2(160, -18), 0.0, Vector2.ONE)
	draw_string(_font_bold, Vector2(-90, 0), "КРАСНОЕ",
			HORIZONTAL_ALIGNMENT_CENTER, 180, fs, Color.WHITE)

	# Декоративный бриллиант по центру
	draw_set_transform(CENTER, 0.0, Vector2.ONE)
	draw_string(_font_bold, Vector2(-20, 10), "♦", HORIZONTAL_ALIGNMENT_CENTER, 40, 36,
			Color(1.0, 0.88, 0.20))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─── Вспомогательные функции отрисовки ────────────────────────────────

func _draw_text_block(center_pos: Vector2, rot: float,
		lines: Array[String], col: Color, fsize: int) -> void:
	var lh := fsize + 6
	var total := lines.size() * lh
	draw_set_transform(center_pos, rot, Vector2.ONE)
	for i in lines.size():
		var y := -total / 2.0 + i * lh + lh * 0.5
		draw_string(_font_bold, Vector2(-120, y), lines[i],
				HORIZONTAL_ALIGNMENT_CENTER, 240, fsize, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_text_single(center_pos: Vector2, rot: float, text: String,
		col: Color, fsize: int, offset_px: int) -> void:
	draw_set_transform(center_pos, rot, Vector2.ONE)
	draw_string(_font, Vector2(-100, -offset_px / 2.0 + offset_px),
			text, HORIZONTAL_ALIGNMENT_CENTER, 200, fsize, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─── Геометрия ─────────────────────────────────────────────────────────

func _sector(r_in: float, r_out: float, a_from: float, a_to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(ARC_SEGS + 1):
		var a: float = lerp(a_from, a_to, float(i) / ARC_SEGS)
		pts.append(CENTER + Vector2(cos(a), sin(a)) * r_out)
	for i in range(ARC_SEGS + 1):
		var a: float = lerp(a_to, a_from, float(i) / ARC_SEGS)
		pts.append(CENTER + Vector2(cos(a), sin(a)) * r_in)
	return pts

func _radial(angle: float, r_in: float, r_out: float, col: Color) -> void:
	draw_line(
		CENTER + Vector2(cos(angle), sin(angle)) * r_in,
		CENTER + Vector2(cos(angle), sin(angle)) * r_out,
		col, BORDER_W)

func _draw_ring(radius: float, width: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(64):
		var a := TAU * i / 64.0
		pts.append(CENTER + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, col, width, true)

func _ring_arc(radius: float, a0: float, a1: float, width: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(ARC_SEGS + 1):
		var a: float = lerp(a0, a1, float(i) / ARC_SEGS)
		pts.append(CENTER + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, col, width, false)

# ─── Данные ────────────────────────────────────────────────────────────

func _cell_fill_color(ctype: String, group: String) -> Color:
	if ctype in SPECIAL_COLOR:
		return SPECIAL_COLOR[ctype]
	if ctype == "PROPERTY":
		return BG_CELL
	if ctype == "HOTEL":
		return BG_CELL.darkened(0.1)
	return BG_CELL

func _cell_lines(cell: Dictionary) -> Array[String]:
	var ctype: String = cell.get("type", "START")
	var name: String  = cell.get("name", "")

	match ctype:
		"START":      return ["ВПЕРЁД!"]
		"JAIL":       return ["ТЮРЬМА", "просто визит"]
		"GO_TO_JAIL": return ["В", "ТЮРЬМУ!"]
		"BETS":       return ["СТАВКИ"]
		"CHANCE":     return ["ШАНС"]
		"EVENT":      return ["СОБЫТИЕ"]

	# PROPERTY / HOTEL — разбиваем "Лото — Silver-стол"
	if " — " in name:
		var parts := name.split(" — ", false, 1)
		var casino := parts[0].to_upper()
		var tier   := parts[1] if parts.size() > 1 else ""
		var result: Array[String] = [casino, tier]
		return result

	# Запасной вариант
	var result: Array[String] = [name]
	return result
