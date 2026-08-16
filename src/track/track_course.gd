## Deterministic recycled forward course for ShapeShift: Neon Gauntlet.
## Player coordinate contract: lane x is supplied as 0..2, player remains at
## Z = 0, and gates move from negative Z towards the positive-Z exit.
class_name TrackCourse
extends Node3D

signal gate_telegraphed(lane: int, shape: GameEvents.ShapeKind, time_to_impact: float, tutorial_text: String)
signal gate_judged(kind: GameEvents.JudgmentKind, points: int, gate_sequence: int)
signal gate_recycled(gate_sequence: int)

@export_range(6, 18, 1) var pool_size: int = 10
@export var lane_width: float = 3.1
@export var auto_advance: bool = false
@export var base_speed: float = 14.0
@export var max_speed: float = 30.0

const JUDGMENT_Z: float = 0.0
const EXIT_Z: float = 3.0
const MIN_SPAWN_DISTANCE: float = 24.0

var _rng := RandomNumberGenerator.new()
var _active: Array[TrackGate3D] = []
var _pool: Array[TrackGate3D] = []
var _sequence: int = 0
var _elapsed: float = 0.0
var _player_lane: int = 1
var _player_shape: GameEvents.ShapeKind = GameEvents.ShapeKind.CUBE
var _running: bool = false
var _last_speed: float = 14.0


func _ready() -> void:
	for index: int in range(pool_size):
		var gate := TrackGate3D.new()
		gate.name = "RecycledGate%02d" % index
		gate.visible = false
		add_child(gate)
		_pool.append(gate)


func _process(delta: float) -> void:
	if auto_advance and _running:
		advance(delta, speed_for_elapsed(_elapsed))


func reset_course(seed: int = 7719) -> void:
	_rng.seed = seed
	_sequence = 0
	_elapsed = 0.0
	_running = true
	_last_speed = base_speed
	# _recycle removes from _active, so iterate a snapshot to return every gate.
	for gate: TrackGate3D in _active.duplicate():
		_recycle(gate)
	_active.clear()
	# Fill enough look-ahead geometry that restarts have no instantiation hitch.
	for ignored: int in range(pool_size):
		_spawn_next(base_speed)
	_update_visual_hierarchy()


func stop_course() -> void:
	_running = false


func set_player_state(lane: int, shape: GameEvents.ShapeKind) -> void:
	_player_lane = clampi(lane, 0, 2)
	_player_shape = shape


func advance(delta: float, current_speed: float) -> void:
	if not _running or delta <= 0.0:
		return
	_last_speed = maxf(0.01, current_speed)
	_elapsed += delta
	for gate: TrackGate3D in _active.duplicate():
		gate.position.z += _last_speed * delta
		var time_to_impact := absf(gate.position.z - JUDGMENT_Z) / maxf(_last_speed, 0.01)
		if not gate._telegraphed and time_to_impact <= gate.spec.telegraph_seconds:
			_emit_telegraph(gate)
		if gate.position.z >= JUDGMENT_Z:
			_judge(gate)
		elif gate.position.z > EXIT_Z:
			_recycle(gate)
	# A judged gate keeps its flash briefly before re-entering the pool.  Do not
	# spin while every pooled node is temporarily occupied by that feedback.
	while _active.size() < pool_size and not _pool.is_empty():
		_spawn_next(_last_speed)
	_update_visual_hierarchy()


func speed_for_elapsed(seconds: float) -> float:
	# Smooth escalation leaves reaction time readable while progressively reducing
	# gate spacing.  Main may use this directly or supply its own speed to advance.
	var intensity: float = clampf(seconds / 105.0, 0.0, 1.0)
	return lerpf(base_speed, max_speed, intensity * intensity * (3.0 - 2.0 * intensity))


func active_specs() -> Array[TrackGateSpec]:
	var specs: Array[TrackGateSpec] = []
	for gate: TrackGate3D in _active:
		specs.append(gate.spec)
	return specs


func visible_target_count() -> int:
	var count := 0
	for child: Node in get_children():
		if child is TrackGate3D:
			count += (child as TrackGate3D).visible_target_count()
	return count


func deterministic_validation(count: int = 10000, seed: int = 7719) -> Dictionary:
	return TrackFairnessSolver.simulate_judgments(count, seed)


static func classify_judgment(gate_spec: TrackGateSpec, player_lane: int, player_shape: GameEvents.ShapeKind) -> GameEvents.JudgmentKind:
	# One-attempt rules are intentionally binary: only an exact lane/form pair
	# survives. Partial matches are misses, never a hidden extra life.
	if gate_spec != null and gate_spec.accepts(player_lane, player_shape):
		return GameEvents.JudgmentKind.PERFECT
	return GameEvents.JudgmentKind.MISS


func _spawn_next(speed: float) -> void:
	if _pool.is_empty():
		return
	var gate: TrackGate3D = _pool.pop_back()
	var gap_seconds := _gap_seconds()
	var furthest_z: float = -MIN_SPAWN_DISTANCE
	if not _active.is_empty():
		furthest_z = _active[0].position.z
		for active_gate: TrackGate3D in _active:
			furthest_z = minf(furthest_z, active_gate.position.z)
	var spawn_z: float = minf(-maxf(MIN_SPAWN_DISTANCE, speed * 1.8), furthest_z - speed * gap_seconds)
	var impact_time: float = _elapsed + absf(spawn_z - JUDGMENT_Z) / maxf(speed, 0.01)
	gate.configure(TrackPatternLibrary.make_spec(_sequence, impact_time, _rng))
	_sequence += 1
	gate.position = Vector3(0.0, 0.0, spawn_z)
	gate.visible = true
	_active.append(gate)


func _update_visual_hierarchy() -> void:
	# Gate position is the sole priority authority.  Sorting by sequence breaks
	# the impossible equal-Z case deterministically, keeping captures/tests and
	# pooled restarts visually reproducible.
	var ranked: Array[TrackGate3D] = _active.duplicate()
	ranked.sort_custom(func(a: TrackGate3D, b: TrackGate3D) -> bool:
		if not is_equal_approx(a.position.z, b.position.z):
			return a.position.z > b.position.z
		return a.spec.sequence < b.spec.sequence
	)
	for index: int in ranked.size():
		var gate: TrackGate3D = ranked[index]
		var priority: TrackGate3D.VisualPriority = TrackGate3D.VisualPriority.SUPPRESSED
		if index == 0:
			priority = TrackGate3D.VisualPriority.FOCAL
		elif index == 1:
			priority = TrackGate3D.VisualPriority.SECONDARY
		elif index == 2:
			priority = TrackGate3D.VisualPriority.DEPTH
		var distance: float = maxf(0.0, JUDGMENT_Z - gate.position.z)
		gate.set_visual_priority(priority, distance)


func _gap_seconds() -> float:
	var intensity: float = clampf((_last_speed - base_speed) / maxf(0.01, max_speed - base_speed), 0.0, 1.0)
	return maxf(TrackFairnessSolver.MIN_JUDGMENT_GAP_SECONDS + 0.08, 1.30 - intensity * 0.48)


func _emit_telegraph(gate: TrackGate3D) -> void:
	if gate.spec == null or gate.spec.targets.is_empty():
		return
	gate.mark_telegraphed()
	var target: Vector2i = gate.spec.targets[0]
	var time_to_impact: float = absf(gate.position.z - JUDGMENT_Z) / maxf(_last_speed, 0.01)
	gate_telegraphed.emit(target.x, target.y, time_to_impact, gate.spec.tutorial_text)


func _judge(gate: TrackGate3D) -> void:
	if not _active.has(gate):
		return
	var kind := classify_judgment(gate.spec, _player_lane, _player_shape)
	var points: int = 100 if kind == GameEvents.JudgmentKind.PERFECT else 0
	# Hide the completed instruction before promoting its successor. Judgment
	# feedback comes from the preallocated light and shared particle pool, so two
	# target shapes can never overlap during the hand-off.
	gate.set_visual_priority(TrackGate3D.VisualPriority.SUPPRESSED, 0.0)
	gate.play_judgment_flash(kind != GameEvents.JudgmentKind.MISS)
	gate_judged.emit(kind, points, gate.spec.sequence)
	_active.erase(gate)
	# Let the 160 ms flash play before the node is returned to the bounded pool.
	get_tree().create_timer(0.18).timeout.connect(_recycle.bind(gate))


func _recycle(gate: TrackGate3D) -> void:
	if is_instance_valid(gate) and not _pool.has(gate):
		_active.erase(gate)
		gate.visible = false
		_pool.append(gate)
		if gate.spec != null:
			gate_recycled.emit(gate.spec.sequence)
