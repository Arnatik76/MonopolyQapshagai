extends Camera3D

# Орбитальная камера — два режима: обзор поля и слежение за игроком

const DEFAULT_DISTANCE := 12.0
const DEFAULT_PITCH    := 55.0
const FOLLOW_DISTANCE  := 7.5
const FOLLOW_PITCH     := 42.0
const MIN_DISTANCE     := 4.0
const MAX_DISTANCE     := 22.0

var yaw          := 0.0
var pitch        := DEFAULT_PITCH
var distance     := DEFAULT_DISTANCE
var focus_target := Vector3.ZERO
var follow_mode  := false

func _ready() -> void:
	add_to_group("camera_controller")
	SignalBus.camera_focus_requested.connect(_on_focus_requested)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clamp(distance - 1.0, MIN_DISTANCE, MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clamp(distance + 1.0, MIN_DISTANCE, MAX_DISTANCE)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw   -= event.relative.x * 0.3
		pitch  = clamp(pitch - event.relative.y * 0.2, 15.0, 80.0)

func _process(delta: float) -> void:
	var speed := 60.0 * delta
	if Input.is_action_pressed("rotate_camera_left"):
		yaw += speed
	elif Input.is_action_pressed("rotate_camera_right"):
		yaw -= speed
	_update_transform()

func _on_focus_requested(target: Vector3) -> void:
	if follow_mode:
		_animate_to(target, FOLLOW_DISTANCE, FOLLOW_PITCH)

func set_follow_mode(enabled: bool) -> void:
	follow_mode = enabled
	if follow_mode:
		var player := PlayerManager.get_player(PlayerManager.current_player_index)
		if player:
			var pos := BoardData.get_cell_world_pos(player.cell_position)
			_animate_to(pos, FOLLOW_DISTANCE, FOLLOW_PITCH)
	else:
		_animate_to(Vector3.ZERO, DEFAULT_DISTANCE, DEFAULT_PITCH)

func _animate_to(target: Vector3, to_dist: float, to_pitch: float, duration := 0.55) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "focus_target", target, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "distance",     to_dist, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "pitch",        to_pitch, duration).set_trans(Tween.TRANS_SINE)

func _update_transform() -> void:
	var yr := deg_to_rad(yaw)
	var pr := deg_to_rad(pitch)
	var offset := Vector3(cos(pr) * sin(yr), sin(pr), cos(pr) * cos(yr)) * distance
	global_position = focus_target + offset
	look_at(focus_target, Vector3.UP)
