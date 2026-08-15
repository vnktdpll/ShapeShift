class_name ArcadeCameraRig
extends Node3D

## A comfortable follow rig. Game code only needs to assign `target` and call
## set_speed_normalized; shake is capped and becomes gentler in reduced motion.

@export var target: Node3D
@export var follow_offset := Vector3(0.0, 4.6, 9.7)
@export_range(55.0, 100.0, 1.0) var base_fov: float = 70.0
@export_range(0.0, 18.0, 0.1) var fov_boost: float = 11.0
@export_range(0.0, 16.0, 0.1) var max_bank_degrees: float = 7.0
@export var reduced_motion: bool = false

var camera: Camera3D
var _speed_normalized: float = 0.0
var _bank_target: float = 0.0
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _rng := RandomNumberGenerator.new()
var _last_lane: int = 1


func _ready() -> void:
	camera = get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.current = true
	camera.position = follow_offset
	camera.look_at(Vector3(0.0, 0.45, -8.0), Vector3.UP)
	_rng.seed = 9917


func _process(delta: float) -> void:
	var desired := global_position
	if is_instance_valid(target):
		desired = target.global_position
		global_position = global_position.lerp(desired, 1.0 - exp(-delta * 14.0))
	var bank_limit := max_bank_degrees * (0.48 if reduced_motion else 1.0)
	rotation.z = lerp(rotation.z, deg_to_rad(clamp(_bank_target, -bank_limit, bank_limit)), 1.0 - exp(-delta * 12.0))
	camera.fov = lerp(camera.fov, base_fov + fov_boost * _speed_normalized, 1.0 - exp(-delta * 4.5))
	_update_shake(delta)


func set_speed_normalized(value: float) -> void:
	_speed_normalized = clampf(value, 0.0, 1.0)


func bind_events(events: GameEvents) -> void:
	events.speed_changed.connect(_on_speed_changed)
	events.lane_changed.connect(_on_lane_changed)
	events.run_failed.connect(_on_run_failed)


func set_lane_direction(direction: float) -> void:
	_bank_target = clampf(-direction * (4.0 + 3.0 * _speed_normalized), -max_bank_degrees, max_bank_degrees)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		_shake_time = 0.0


func impulse_shake(strength: float = 0.25, duration: float = 0.12) -> void:
	if reduced_motion:
		return
	_shake_strength = minf(0.32, maxf(_shake_strength, strength))
	_shake_duration = minf(0.22, maxf(_shake_duration, duration))
	_shake_time = _shake_duration


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		camera.position = camera.position.lerp(follow_offset, 1.0 - exp(-delta * 24.0))
		return
	_shake_time -= delta
	var envelope := clampf(_shake_time / maxf(_shake_duration, 0.01), 0.0, 1.0)
	var offset := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.55, 0.55), 0.0) * _shake_strength * envelope
	camera.position = follow_offset + offset


func _on_speed_changed(_speed: float, normalized_intensity: float) -> void:
	set_speed_normalized(normalized_intensity)


func _on_lane_changed(lane: int) -> void:
	set_lane_direction(signf(float(lane - _last_lane)))
	_last_lane = lane


func _on_run_failed(_score: int, _high_score: int) -> void:
	impulse_shake(0.28, 0.18)
