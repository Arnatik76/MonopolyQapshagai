extends Node

# Загружает данные клеток из JSON и предоставляет доступ к ним

const BOARD_RADIUS := 5.0
const CELL_COUNT := 36
const CELLS_JSON_PATH := "res://data/board_cells.json"
const CARDS_JSON_PATH := "res://data/chance_cards.json"

var cells: Array[BoardCell] = []
var chance_cards: Array[CardData] = []

func _ready() -> void:
	_load_cells()
	_load_cards()

func _load_cells() -> void:
	var file := FileAccess.open(CELLS_JSON_PATH, FileAccess.READ)
	if not file:
		push_error("BoardData: не удалось открыть %s" % CELLS_JSON_PATH)
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("BoardData: ошибка парсинга JSON: %s" % json.get_error_message())
		return

	var data: Array = json.data
	cells.clear()

	for d in data:
		var cell := BoardCell.new()
		cell.cell_index = d.get("index", 0)
		cell.name = d.get("name", "")
		cell.description = d.get("description", "")
		cell.casino = d.get("casino", "")
		cell.hall = d.get("hall", 0)
		cell.price = d.get("price", 0)
		cell.dealer_price = d.get("dealer_price", 0)
		cell.mortgage_value = d.get("mortgage_value", 0)
		cell.bet_min = d.get("bet_min", 0)
		cell.bet_max = d.get("bet_max", 0)

		# Tier
		cell.tier = _parse_tier(d.get("tier", "NONE"))

		# rent_by_count для HOTEL
		var rbc_raw: Array = d.get("rent_by_count", [])
		cell.rent_by_count.clear()
		for v in rbc_raw:
			cell.rent_by_count.append(int(v))

		# Преобразуем строки в enum
		cell.type = _parse_cell_type(d.get("type", "START"))
		cell.color_group = _parse_color_group(d.get("color_group", "NONE"))

		# Рента
		var rent_raw: Array = d.get("rent", [])
		cell.rent.clear()
		for v in rent_raw:
			cell.rent.append(int(v))

		# Вычисляем угол клетки на поле
		cell.world_angle_deg = (360.0 / CELL_COUNT) * cell.cell_index

		cells.append(cell)

	print("BoardData: загружено %d клеток" % cells.size())

func _load_cards() -> void:
	var file := FileAccess.open(CARDS_JSON_PATH, FileAccess.READ)
	if not file:
		push_error("BoardData: не удалось открыть %s" % CARDS_JSON_PATH)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("BoardData: ошибка парсинга карт: %s" % json.get_error_message())
		return
	chance_cards.clear()
	for d in (json.data as Array):
		var card := CardData.new()
		card.title = d.get("title", "")
		card.description = d.get("description", "")
		card.effect_value = d.get("effect_value", 0)
		card.card_type = CardData.CardType.CHANCE
		card.effect_type = _parse_effect_type(d.get("effect_type", "GET_MONEY"))
		chance_cards.append(card)
	print("BoardData: загружено %d карт" % chance_cards.size())

func get_cards(_card_type: CardData.CardType) -> Array[CardData]:
	# Используем одну колоду для CHANCE и EVENT
	return chance_cards

func _parse_effect_type(s: String) -> CardData.EffectType:
	match s:
		"MOVE_TO":         return CardData.EffectType.MOVE_TO
		"MOVE_BY":         return CardData.EffectType.MOVE_BY
		"GET_MONEY":       return CardData.EffectType.GET_MONEY
		"PAY_MONEY":       return CardData.EffectType.PAY_MONEY
		"PAY_EACH_PLAYER": return CardData.EffectType.PAY_EACH_PLAYER
		"GET_FROM_EACH":   return CardData.EffectType.GET_FROM_EACH
		"GO_TO_JAIL":      return CardData.EffectType.GO_TO_JAIL
		"GET_OUT_OF_JAIL": return CardData.EffectType.GET_OUT_OF_JAIL
		"SKIP_TURN":       return CardData.EffectType.SKIP_TURN
		"PAY_PER_DEALER":  return CardData.EffectType.PAY_PER_DEALER
		"CASINO_MINIGAME": return CardData.EffectType.CASINO_MINIGAME
		"PAY_PER_HOTEL":   return CardData.EffectType.PAY_PER_DEALER  # обратная совместимость
		_:                 return CardData.EffectType.GET_MONEY

func get_cell(index: int) -> BoardCell:
	if index < 0 or index >= cells.size():
		push_error("BoardData: неверный индекс клетки %d" % index)
		return null
	return cells[index]

func get_cell_world_pos(cell_index: int) -> Vector3:
	# Старт снизу (-PI/2), движение по часовой стрелке
	var angle := (TAU / CELL_COUNT) * cell_index - PI / 2
	return Vector3(cos(angle) * BOARD_RADIUS, 0.06, sin(angle) * BOARD_RADIUS)

func _parse_cell_type(s: String) -> BoardCell.CellType:
	match s:
		"START":      return BoardCell.CellType.START
		"PROPERTY":   return BoardCell.CellType.PROPERTY
		"HOTEL":      return BoardCell.CellType.HOTEL
		"CHANCE":     return BoardCell.CellType.CHANCE
		"EVENT":      return BoardCell.CellType.EVENT
		"BETS":       return BoardCell.CellType.BETS
		"JAIL":       return BoardCell.CellType.JAIL
		"GO_TO_JAIL": return BoardCell.CellType.GO_TO_JAIL
		_:
			push_warning("BoardData: неизвестный тип клетки '%s'" % s)
			return BoardCell.CellType.START

func _parse_color_group(s: String) -> BoardCell.ColorGroup:
	match s:
		"YELLOW": return BoardCell.ColorGroup.YELLOW
		"GREEN":  return BoardCell.ColorGroup.GREEN
		"WHITE":  return BoardCell.ColorGroup.WHITE
		"BLUE":   return BoardCell.ColorGroup.BLUE
		"PINK":   return BoardCell.ColorGroup.PINK
		"ORANGE": return BoardCell.ColorGroup.ORANGE
		"GRAY":   return BoardCell.ColorGroup.GRAY
		"RED":    return BoardCell.ColorGroup.RED
		_:        return BoardCell.ColorGroup.NONE

func _parse_tier(s: String) -> BoardCell.Tier:
	match s:
		"SILVER":   return BoardCell.Tier.SILVER
		"GOLD":     return BoardCell.Tier.GOLD
		"PLATINUM": return BoardCell.Tier.PLATINUM
		_:          return BoardCell.Tier.NONE
