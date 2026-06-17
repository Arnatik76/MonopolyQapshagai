extends Node2D

# Процедурная отрисовка поля 2048×2048 в SubViewport

const CENTER     := Vector2(1024.0, 1024.0)
const R_OUTER    := 950.0   # внешний край
const R_STRIPE   := 892.0   # начало цветной полосы группы (снаружи)
const R_CELL     := 645.0   # граница: снаружи — зона клетки, внутри — зона зала
const R_INNER    := 330.0   # внутренняя граница / хаб

const CELL_COUNT := 36
const CELL_ANGLE := TAU / CELL_COUNT
const ARC_SEGS   := 16

const BORDER_COL := Color(1.0, 1.0, 1.0, 0.55)
const BORDER_W   := 2.5

const BG_BOARD   := Color(0.04, 0.04, 0.06)
const BG_CELL    := Color(0.07, 0.07, 0.09)

const GROUP_COLOR: Dictionary = {
	"YELLOW": Color(0.97, 0.86, 0.06),
	"GREEN":  Color(0.18, 0.76, 0.28),
	"WHITE":  Color(0.88, 0.88, 0.88),
	"BLUE":   Color(0.22, 0.50, 0.95),
	"PINK":   Color(0.94, 0.30, 0.72),
	"ORANGE": Color(0.97, 0.54, 0.08),
	"GRAY":   Color(0.55, 0.55, 0.60),
	"RED":    Color(0.90, 0.10, 0.10),
}

const SPECIAL_BG: Dictionary = {
	"START":      Color(0.05, 0.38, 0.05),
	"JAIL":       Color(0.18, 0.18, 0.22),
	"GO_TO_JAIL": Color(0.45, 0.04, 0.04),
	"BETS":       Color(0.06, 0.02, 0.02),
	"HOTEL":      Color(0.22, 0.11, 0.03),
}

const CARD_BG: Dictionary = {
	"CHANCE": Color(0.14, 0.11, 0.02),
	"EVENT":  Color(0.08, 0.04, 0.14),
}

var _font: Font
var _cells: Array = []
# color_group -> {min_idx, max_idx, color, name}
var _group_spans: Dictionary = {}

func _ready() -> void:
	_font = ThemeDB.fallback_font
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
	_compute_group_spans()
	queue_redraw()

func _compute_group_spans() -> void:
	_group_spans.clear()
	for cell in _cells:
		var group: String = cell.get("color_group", "NONE")
		if group == "NONE":
			continue
		var idx: int   = cell.get("index", 0)
		var casino: String = cell.get("casino", "")
		if not _group_spans.has(group):
			_group_spans[group] = {
				"min_idx": idx,
				"max_idx": idx,
				"color":   GROUP_COLOR.get(group, Color.WHITE),
				"name":    casino,
			}
		else:
			var span: Dictionary = _group_spans[group]
			if idx < (span.get("min_idx", 0) as int):
				span["min_idx"] = idx
			if idx > (span.get("max_idx", 0) as int):
				span["max_idx"] = idx
			if casino != "" and (span.get("name", "") as String) == "":
				span["name"] = casino

# ─── Главная отрисовка ─────────────────────────────────────────────────────

func _draw() -> void:
	# Тёмный фон
	draw_circle(CENTER, R_OUTER + 28.0, BG_BOARD)

	# Внутренние зоны залов (R_INNER → R_CELL)
	for group in _group_spans:
		_draw_hall_bg(_group_spans[group] as Dictionary)

	# Внешние зоны клеток (R_CELL → R_OUTER)
	for cell in _cells:
		_draw_cell_outer(cell)

	# Кольца-границы
	_draw_ring(R_OUTER, 3.5, BORDER_COL)
	_draw_ring(R_CELL, 2.0, Color(1, 1, 1, 0.30))
	_draw_ring(R_INNER, 3.0, BORDER_COL)

	# Радиальные линии между клетками
	for i in CELL_COUNT:
		var a := CELL_ANGLE * float(i) - PI / 2.0
		_radial(a, R_INNER, R_OUTER, BORDER_COL)

	# Хаб «Чёрное / Красное»
	_draw_center()

	# Названия залов
	for group in _group_spans:
		_draw_hall_name(_group_spans[group] as Dictionary)

	# Текст клеток
	for cell in _cells:
		_draw_cell_text(cell)

# ─── Зоны залов ────────────────────────────────────────────────────────────

func _draw_hall_bg(span: Dictionary) -> void:
	var min_i: int = span.get("min_idx", 0) as int
	var max_i: int = span.get("max_idx", 0) as int
	var col: Color  = span.get("color", Color.WHITE) as Color
	var a0 := CELL_ANGLE * float(min_i) - PI / 2.0
	var a1 := CELL_ANGLE * float(max_i + 1) - PI / 2.0
	draw_colored_polygon(_sector(R_INNER, R_CELL, a0, a1), col.darkened(0.42))

func _draw_hall_name(span: Dictionary) -> void:
	var min_i: int   = span.get("min_idx", 0) as int
	var max_i: int   = span.get("max_idx", 0) as int
	var name: String = span.get("name", "") as String
	if name == "":
		return
	var a0  := CELL_ANGLE * float(min_i) - PI / 2.0
	var a1  := CELL_ANGLE * float(max_i + 1) - PI / 2.0
	var mid := (a0 + a1) * 0.5
	var r   := (R_INNER + R_CELL) * 0.5   # ~487

	var pos := CENTER + Vector2(cos(mid), sin(mid)) * r
	var rot := mid + PI / 2.0
	if sin(mid) > 0.0:
		rot = mid - PI / 2.0

	draw_set_transform(pos, rot, Vector2.ONE)
	draw_string(_font, Vector2(-200.0, 14.0), name.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, 400.0, 34, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─── Внешняя зона клетки ───────────────────────────────────────────────────

func _draw_cell_outer(cell: Dictionary) -> void:
	var idx: int    = cell.get("index", 0) as int
	var ctype: String = cell.get("type", "START") as String
	var group: String = cell.get("color_group", "NONE") as String

	var a0 := CELL_ANGLE * float(idx) - PI / 2.0
	var a1 := a0 + CELL_ANGLE

	if ctype in SPECIAL_BG:
		# Особые клетки — на всю ширину (R_INNER → R_OUTER)
		var col: Color = SPECIAL_BG.get(ctype, BG_CELL) as Color
		draw_colored_polygon(_sector(R_INNER, R_OUTER, a0, a1), col)
	elif ctype in CARD_BG:
		# CHANCE / EVENT — только внешняя зона (внутри остаётся цвет зала)
		var col: Color = CARD_BG.get(ctype, BG_CELL) as Color
		draw_colored_polygon(_sector(R_CELL, R_OUTER, a0, a1), col)
	else:
		# PROPERTY / HOTEL — чёрный фон + цветная полоса снаружи
		draw_colored_polygon(_sector(R_CELL, R_OUTER, a0, a1), BG_CELL)
		if ctype == "PROPERTY":
			var stripe: Color = GROUP_COLOR.get(group, Color.WHITE) as Color
			draw_colored_polygon(_sector(R_STRIPE, R_OUTER, a0, a1), stripe)
		elif ctype == "HOTEL":
			draw_colored_polygon(_sector(R_STRIPE, R_OUTER, a0, a1), Color(0.55, 0.30, 0.08))

# ─── Текст клетки ──────────────────────────────────────────────────────────

func _draw_cell_text(cell: Dictionary) -> void:
	var idx: int      = cell.get("index", 0) as int
	var ctype: String = cell.get("type", "START") as String
	var price: int    = cell.get("price", 0) as int
	var tier: String  = cell.get("tier", "NONE") as String
	var name: String  = cell.get("name", "") as String

	var a0  := CELL_ANGLE * float(idx) - PI / 2.0
	var a1  := a0 + CELL_ANGLE
	var mid := (a0 + a1) * 0.5

	var rot := mid + PI / 2.0
	if sin(mid) > 0.001:
		rot = mid - PI / 2.0

	# Радиус основного текста
	var r_main := (R_CELL + R_STRIPE) * 0.5   # ~768
	var pos := CENTER + Vector2(cos(mid), sin(mid)) * r_main

	var lines := _cell_lines(ctype, tier, name)
	var tcol  := _cell_text_color(ctype)
	_draw_text_block(pos, rot, lines, tcol, 19)

	# Цена
	if price > 0:
		var r_price := (R_STRIPE + R_OUTER) * 0.5   # ~921
		var pos_p := CENTER + Vector2(cos(mid), sin(mid)) * r_price
		_draw_text_single(pos_p, rot, "%dМ" % price, Color(1.0, 0.88, 0.20), 16)

func _cell_lines(ctype: String, tier: String, name: String) -> Array[String]:
	match ctype:
		"START":
			var r: Array[String] = ["ВПЕРЁД!"]
			return r
		"JAIL":
			var r: Array[String] = ["ТЮРЬМА"]
			return r
		"GO_TO_JAIL":
			var r: Array[String] = ["В", "ТЮРЬМУ!"]
			return r
		"BETS":
			var r: Array[String] = ["СТАВКИ"]
			return r
		"CHANCE":
			var r: Array[String] = ["ШАНС"]
			return r
		"EVENT":
			var r: Array[String] = ["СОБЫТИЕ"]
			return r
		"HOTEL":
			var parts := name.split("№")
			var num := parts[1].strip_edges() if parts.size() > 1 else "?"
			var r: Array[String] = ["НОМЕР", "ОТЕЛЯ №" + num]
			return r
		"PROPERTY":
			match tier:
				"SILVER":
					var r: Array[String] = ["SILVER"]
					return r
				"GOLD":
					var r: Array[String] = ["GOLD"]
					return r
				"PLATINUM":
					var r: Array[String] = ["PLATINUM"]
					return r
	var r: Array[String] = [name]
	return r

func _cell_text_color(ctype: String) -> Color:
	match ctype:
		"CHANCE":     return Color(1.0, 0.90, 0.30)
		"EVENT":      return Color(0.85, 0.60, 1.0)
		"START":      return Color(0.50, 1.00, 0.50)
		"GO_TO_JAIL": return Color(1.0,  0.50, 0.50)
		"BETS":       return Color(1.0,  0.30, 0.30)
		_:            return Color.WHITE

# ─── Хаб (Чёрное / Красное) ────────────────────────────────────────────────

func _draw_center() -> void:
	var r := R_INNER - 18.0
	draw_colored_polygon(_sector(0.0, r,  PI / 2.0,  PI * 1.5), Color(0.06, 0.06, 0.06))
	draw_colored_polygon(_sector(0.0, r, -PI / 2.0,  PI / 2.0), Color(0.72, 0.04, 0.04))
	_draw_ring(r, 2.5, BORDER_COL)

	var fs := 28
	draw_set_transform(CENTER + Vector2(-76.0, -13.0), 0.0, Vector2.ONE)
	draw_string(_font, Vector2(-76.0, 0.0), "ЧЁРНОЕ",
			HORIZONTAL_ALIGNMENT_CENTER, 152.0, fs, Color.WHITE)
	draw_set_transform(CENTER + Vector2(76.0, -13.0), 0.0, Vector2.ONE)
	draw_string(_font, Vector2(-76.0, 0.0), "КРАСНОЕ",
			HORIZONTAL_ALIGNMENT_CENTER, 152.0, fs, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─── Вспомогательные ───────────────────────────────────────────────────────

func _draw_text_block(cpos: Vector2, rot: float,
		lines: Array[String], col: Color, fsize: int) -> void:
	var lh := fsize + 5
	var total := float(lines.size() * lh)
	draw_set_transform(cpos, rot, Vector2.ONE)
	for i in lines.size():
		var y := -total * 0.5 + float(i) * lh + float(lh) * 0.5
		draw_string(_font, Vector2(-110.0, y), lines[i],
				HORIZONTAL_ALIGNMENT_CENTER, 220.0, fsize, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_text_single(cpos: Vector2, rot: float,
		text: String, col: Color, fsize: int) -> void:
	draw_set_transform(cpos, rot, Vector2.ONE)
	draw_string(_font, Vector2(-60.0, 6.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, fsize, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _sector(r_in: float, r_out: float, a_from: float, a_to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(ARC_SEGS + 1):
		var a: float = lerp(a_from, a_to, float(i) / float(ARC_SEGS))
		pts.append(CENTER + Vector2(cos(a), sin(a)) * r_out)
	for i in range(ARC_SEGS + 1):
		var a: float = lerp(a_to, a_from, float(i) / float(ARC_SEGS))
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
		var a := TAU * float(i) / 64.0
		pts.append(CENTER + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, col, width, true)
