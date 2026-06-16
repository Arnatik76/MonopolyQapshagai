extends Node

# Главный синглтон — фаза хода и глобальные флаги

enum TurnPhase {
	WAIT_FOR_ROLL,   # ждём нажатия «Бросить кубики»
	ROLLING,         # физическая анимация кубиков
	MOVING,          # фишка движется по клеткам (Tween)
	CELL_ACTION,     # определяем что делать на клетке
	BUY_DECISION,    # предлагаем купить свободную собственность / номер отеля
	AUCTION,         # аукцион (старт 10М)
	CARD_EFFECT,     # показываем карту Шанс/Событие + применяем эффект
	BET_MINIGAME,    # мини-игра «Ставки» (клетка 18)
	JAIL_ENTRY,      # анимация/логика посадки в тюрьму
	JAIL_DECISION,   # игрок в тюрьме: платить/ждать/дубль
	TURN_END,        # конец хода, переход к следующему
}

var current_phase: TurnPhase = TurnPhase.WAIT_FOR_ROLL
var game_started: bool = false
var last_dice_a: int = 0
var last_dice_b: int = 0
var last_is_double: bool = false

func _ready() -> void:
	SignalBus.dice_rolled.connect(_on_dice_rolled)

func set_phase(phase: TurnPhase) -> void:
	current_phase = phase

func start_game() -> void:
	game_started = true
	current_phase = TurnPhase.WAIT_FOR_ROLL
	# Первый ход — сигнал для игрока 0
	SignalBus.turn_started.emit(PlayerManager.current_player_index)

func _on_dice_rolled(a: int, b: int, is_double: bool) -> void:
	last_dice_a = a
	last_dice_b = b
	last_is_double = is_double
