extends Node3D

# Корневой скрипт: инициализация игры

@onready var board: Node3D = $Board3D
@onready var hud = $HUD
@onready var win_screen = $WinScreen

func _ready() -> void:
	# Быстрый старт для отладки: 2 игрока
	PlayerManager.setup_players(2)
	board.spawn_tokens()
	hud.setup_players()
	GameState.start_game()

	SignalBus.game_over.connect(_on_game_over)

func _on_game_over(winner_index: int) -> void:
	var winner := PlayerManager.get_player(winner_index)
	win_screen.get_node("CenterPanel/VBox/PlayerNameLabel").text = winner.name
	win_screen.show()
