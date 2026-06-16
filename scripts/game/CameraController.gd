extends Camera3D

# Орбитальная камера над игровым столом

const DEFAULT_DISTANCE := 12.0
const DEFAULT_ELEVATION := 55.0
const MIN_DISTANCE := 6.0
const MAX_DISTANCE := 20.0

var yaw := 0.0
var pitch := 55.0
var distance := DEFAULT_DISTANCE
var focus_target := Vector3.ZERO

func _ready() -> void:
	SignalBus.camera_focus_requested.connect(_on_focus_requested)
	_update_transform()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clamp(distance - 1.0, MIN_DISTANCE, MAX_DISTANCE)
			_update_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clamp(distance + 1.0, MIN_DISTANCE, MAX_DISTANCE)
			_update_transform()

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.3
		pitch = clamp(pitch - event.relative.y * 0.2, 20.0, 80.0)
		_update_transform()

func _process(_delta: float) -> void:
	# Клавишное вращение
	var rotate_speed := 60.0 * _delta
	if Input.is_action_pressed("rotate_camera_left"):
		yaw += rotate_speed
		_update_transform()
	elif Input.is_action_pressed("rotate_camera_right"):
		yaw -= rotate_speed
		_update_transform()

func _on_focus_requested(target: Vector3) -> void:
	focus_on(target)

func focus_on(world_pos: Vector3, duration := 0.6) -> void:
	var tween := create_tween()
	tween.tween_property(self, "focus_target", world_pos, duration).set_trans(Tween.TRANS_SINE)
	tween.connect("finished", _update_transform)

func _update_transform() -> void:
	var yaw_rad := deg_to_rad(yaw)
	var pitch_rad := deg_to_rad(pitch)

	var offset := Vector3(
		cos(pitch_rad) * sin(yaw_rad),
		sin(pitch_rad),
		cos(pitch_rad) * cos(yaw_rad)
	) * distance

	global_position = focus_target + offset
	look_at(focus_target, Vector3.UP)
