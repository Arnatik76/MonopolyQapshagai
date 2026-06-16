extends Node3D

# Управляет физическими кубиками (RigidBody3D)

@onready var dice1: RigidBody3D = $Dice1
@onready var dice2: RigidBody3D = $Dice2

func _ready() -> void:
	# Замораживаем кубики в начале — они не должны падать
	dice1.freeze = true
	dice2.freeze = true

func roll() -> void:
	print("[Dice] roll() started")
	for die in [dice1, dice2]:
		die.freeze = false
		die.global_position = Vector3(randf_range(-0.3, 0.3), 2.0, randf_range(-0.3, 0.3))
		die.linear_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 3.0), randf_range(-2.0, 2.0))
		die.angular_velocity = Vector3(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))

	await _wait_for_dice_to_stop()
	print("[Dice] dice stopped")

	var result_a := _read_die_value(dice1)
	var result_b := _read_die_value(dice2)
	var is_double := result_a == result_b
	print("[Dice] result: %d + %d, double=%s" % [result_a, result_b, is_double])

	dice1.freeze = true
	dice2.freeze = true

	SignalBus.dice_rolled.emit(result_a, result_b, is_double)
	SignalBus.dice_animation_finished.emit()
	print("[Dice] signals emitted")

func _wait_for_dice_to_stop() -> void:
	var elapsed := 0.0
	while elapsed < 8.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var v1 := dice1.linear_velocity.length() + dice1.angular_velocity.length()
		var v2 := dice2.linear_velocity.length() + dice2.angular_velocity.length()
		if v1 < 0.1 and v2 < 0.1:
			await get_tree().create_timer(0.3).timeout
			break
	# Принудительно возвращаем улетевший кубик на место
	for die: RigidBody3D in [dice1, dice2]:
		if die.global_position.y < -5.0 or die.global_position.length() > 15.0:
			die.global_position = Vector3(0, 0.5, 0)
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO

func _read_die_value(die: RigidBody3D) -> int:
	# Определяем верхнюю грань по ориентации кубика
	var die_basis := die.global_transform.basis
	var faces: Dictionary[int, Vector3] = {
		1: die_basis.y,
		6: -die_basis.y,
		2: die_basis.x,
		5: -die_basis.x,
		3: die_basis.z,
		4: -die_basis.z,
	}
	var best_dot: float = -INF
	var best_value: int = 1
	for value: int in faces:
		var dot: float = faces[value].dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_value = value
	return best_value
