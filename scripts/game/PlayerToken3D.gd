extends Node3D

# Управляет 3D фишкой одного игрока

@onready var token_mesh: MeshInstance3D = $TokenMesh
@onready var glow_ring: OmniLight3D = $GlowRing
@onready var name_label: Label3D = $NameLabel

var player_index: int = 0

func _ready() -> void:
	glow_ring.visible = false
	SignalBus.turn_started.connect(_on_turn_started)

func setup(index: int) -> void:
	player_index = index
	var player := PlayerManager.get_player(index)
	if not player:
		return

	# Цвет фишки
	var mat := StandardMaterial3D.new()
	mat.albedo_color = player.token_color
	mat.metallic = 0.3
	mat.roughness = 0.5
	token_mesh.material_override = mat

	# Подсветка цветом игрока
	glow_ring.light_color = player.token_color
	glow_ring.light_energy = 2.0
	glow_ring.omni_range = 0.8

	# Имя над фишкой
	name_label.text = player.name

	# Начальная позиция — клетка 0
	global_position = BoardData.get_cell_world_pos(0)
	global_position.y = 0.5

func _on_turn_started(idx: int) -> void:
	# Только активный игрок светится
	glow_ring.visible = (idx == player_index)

func move_to_cell(target_cell: int) -> void:
	var player := PlayerManager.get_player(player_index)
	if not player:
		return

	var start_cell := player.cell_position
	var steps := (target_cell - start_cell) % BoardData.CELL_COUNT
	if steps < 0:
		steps += BoardData.CELL_COUNT

	for i in steps:
		var next_cell := (start_cell + i + 1) % BoardData.CELL_COUNT

		# При прохождении через START (кроме последнего шага) — +200М
		if next_cell == 0 and i < steps - 1:
			PlayerManager.add_balance(player_index, 200)

		var target_pos := BoardData.get_cell_world_pos(next_cell)
		target_pos.y = 0.5

		# Прыжок дугой через верх
		var mid_pos: Vector3 = global_position.lerp(target_pos, 0.5)
		mid_pos.y = 1.2

		var tween := create_tween()
		tween.tween_property(self, "global_position", mid_pos, 0.12)
		tween.tween_property(self, "global_position", target_pos, 0.12)
		await tween.finished

	SignalBus.player_moved.emit(player_index, target_cell)
