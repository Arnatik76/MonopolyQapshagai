extends Node3D

# Управляет 3D сценой поля: размещение фишек, отелей, подсветка клетки

@onready var tokens_layer: Node3D = $TokensLayer
@onready var dealers_layer: Node3D = $DealersLayer
@onready var cell_highlight: OmniLight3D = $Lighting/CellHighlight
@onready var turn_state_machine: Node = $TurnStateMachine
@onready var dice_roller: Node3D = $DiceArea/DiceRoller3D

const TOKEN_SCENE := preload("res://scenes/game/PlayerToken3D.tscn")
const BOARD_RENDERER := preload("res://scripts/game/BoardRenderer.gd")

var _tokens: Array[Node3D] = []

func _ready() -> void:
	add_to_group("board")
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.dealer_placed.connect(_on_dealer_placed)
	SignalBus.player_moved.connect(_on_player_moved)
	SignalBus.move_player_requested.connect(_on_move_player_requested)

	turn_state_machine.set_dice_roller(dice_roller)
	_setup_board_texture()

func _setup_board_texture() -> void:
	# Создаём SubViewport 2048×2048 с процедурной отрисовкой поля
	var vp := SubViewport.new()
	vp.name = "BoardViewport"
	vp.size = Vector2i(2048, 2048)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var renderer := BOARD_RENDERER.new()
	vp.add_child(renderer)

	# Ждём два кадра — SubViewport должен отрендериться
	await get_tree().process_frame
	await get_tree().process_frame

	# Применяем текстуру к BoardTop (PlaneMesh поверх диска)
	var board_top := get_node_or_null("BoardDisc/BoardTop") as MeshInstance3D
	if board_top:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = vp.get_texture()
		# Убираем ambient_occlusion чтобы тёмные участки не были слишком тёмными
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		board_top.set_surface_override_material(0, mat)
		# После применения можно остановить обновление (поле статично)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		print("Board3D: текстура поля применена")
	else:
		push_error("Board3D: нода BoardDisc/BoardTop не найдена")

func spawn_tokens() -> void:
	# Вызывается после setup_players() в PlayerManager
	for child in tokens_layer.get_children():
		child.queue_free()
	_tokens.clear()

	for i in PlayerManager.player_count:
		var token: Node3D = TOKEN_SCENE.instantiate()
		tokens_layer.add_child(token)
		token.setup(i)
		_tokens.append(token)

func _on_turn_started(player_index: int) -> void:
	# Камера фокусируется на текущем игроке
	var player := PlayerManager.get_player(player_index)
	if player:
		var pos := BoardData.get_cell_world_pos(player.cell_position)
		SignalBus.camera_focus_requested.emit(pos)

func _on_player_moved(player_index: int, cell_index: int) -> void:
	# Подсветка активной клетки
	var pos := BoardData.get_cell_world_pos(cell_index)
	cell_highlight.global_position = Vector3(pos.x, 0.3, pos.z)
	cell_highlight.visible = true

func _on_dealer_placed(cell_index: int, player_index: int, is_senior: bool) -> void:
	# Визуально ставим фигурку дилера на клетку
	# Dealer3D.tscn будет создан позже — пока простой цилиндр
	var dealer := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.08
	mesh.height = 0.15
	dealer.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.1, 0.1) if is_senior else Color(0.1, 0.7, 0.2)
	dealer.material_override = mat
	dealers_layer.add_child(dealer)
	var pos := BoardData.get_cell_world_pos(cell_index)
	var player := PlayerManager.get_player(player_index)
	var d: Dictionary = player.dealers.get(cell_index, {"junior": 0, "senior": 0}) as Dictionary
	var count: int = (d.get("junior", 0) as int) + (d.get("senior", 0) as int)
	pos.y = 0.1 + (count - 1) * 0.12
	# Небольшое смещение к краю клетки
	pos.x += 0.2
	dealer.global_position = pos

func _on_move_player_requested(player_index: int, target_cell: int) -> void:
	if player_index < _tokens.size():
		await _tokens[player_index].move_to_cell(target_cell)

func on_roll_button_pressed() -> void:
	turn_state_machine.roll_dice()
