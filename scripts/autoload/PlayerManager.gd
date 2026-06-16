extends Node

# Управляет массивом игроков и очерёдностью ходов

var players: Array[PlayerData] = []
var current_player_index: int = 0
var player_count: int = 0

# Цвета фишек по умолчанию
const DEFAULT_COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.2),   # красный
	Color(0.2, 0.5, 0.9),   # синий
	Color(0.2, 0.8, 0.3),   # зелёный
	Color(0.9, 0.8, 0.1),   # жёлтый
	Color(0.8, 0.3, 0.9),   # фиолетовый
	Color(0.9, 0.5, 0.1),   # оранжевый
]

const DEFAULT_NAMES: Array[String] = [
	"Игрок 1", "Игрок 2", "Игрок 3",
	"Игрок 4", "Игрок 5", "Игрок 6",
]

func setup_players(count: int, names: Array[String] = [], colors: Array[Color] = []) -> void:
	players.clear()
	player_count = clamp(count, 2, 6)

	for i in player_count:
		var p := PlayerData.new()
		p.player_index = i
		p.name = names[i] if i < names.size() else DEFAULT_NAMES[i]
		p.token_color = colors[i] if i < colors.size() else DEFAULT_COLORS[i]
		p.balance = 1500
		p.cell_position = 0
		players.append(p)

	current_player_index = 0
	print("PlayerManager: создано %d игроков" % player_count)

func get_player(index: int) -> PlayerData:
	if index < 0 or index >= players.size():
		push_error("PlayerManager: неверный индекс игрока %d" % index)
		return null
	return players[index]

func get_current_player() -> PlayerData:
	return get_player(current_player_index)

func get_balance(index: int) -> int:
	var p := get_player(index)
	return p.balance if p else 0

func add_balance(index: int, amount: int) -> void:
	var p := get_player(index)
	if p:
		p.balance += amount
		SignalBus.balance_changed.emit(index, p.balance)

func subtract_balance(index: int, amount: int) -> bool:
	# Возвращает false если недостаточно средств
	var p := get_player(index)
	if not p:
		return false
	if p.balance < amount:
		return false
	p.balance -= amount
	SignalBus.balance_changed.emit(index, p.balance)
	return true

func next_turn() -> void:
	var current := current_player_index
	var next := (current + 1) % player_count
	print("[PM] next_turn: player_count=%d current=%d next=%d" % [player_count, current, next])

	# Пропускаем банкротов
	while get_player(next).is_bankrupt and next != current:
		next = (next + 1) % player_count

	# Если все остальные банкроты — победитель найден
	if next == current:
		SignalBus.game_over.emit(current)
		return

	current_player_index = next
	# Сбросить счётчик дублей для нового игрока
	get_player(next).doubles_streak = 0
	SignalBus.turn_started.emit(next)

func is_color_group_owned_by(color_group: BoardCell.ColorGroup, player_index: int) -> bool:
	# Проверяем, владеет ли игрок всей цветовой группой
	var p := get_player(player_index)
	if not p:
		return false

	for cell in BoardData.cells:
		if cell.color_group == color_group and cell.type == BoardCell.CellType.PROPERTY:
			if not (cell.cell_index in p.owned_properties):
				return false
	return true

func declare_bankrupt(player_index: int) -> void:
	var p := get_player(player_index)
	if p:
		p.is_bankrupt = true
		p.owned_properties.clear()
		p.owned_hotels.clear()
		p.dealers.clear()
		p.mortgaged_cells.clear()
		SignalBus.player_bankrupt.emit(player_index)
