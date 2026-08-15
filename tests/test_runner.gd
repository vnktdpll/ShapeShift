## Headless deterministic acceptance checks for ShapeShift: Neon Gauntlet.
## Run with: Godot --headless --path . --script res://tests/test_runner.gd
extends SceneTree

const EVENTS := preload("res://src/core/game_events.gd")
const SCORE_SCRIPT := preload("res://src/scoring/score_system.gd")
const GATE_SPEC_SCRIPT := preload("res://src/track/track_gate_spec.gd")
const PATTERN_LIBRARY_SCRIPT := preload("res://src/track/track_pattern_library.gd")
const FAIRNESS_SCRIPT := preload("res://src/track/track_fairness_solver.gd")
const COURSE_SCRIPT := preload("res://src/track/track_course.gd")

var _failures: Array[String] = []
var _checks := 0
var _started_usec := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	print("[TEST] ShapeShift deterministic acceptance suite")
	_test_all_lane_shape_pairs()
	_test_score_combo_multiplier()
	_test_fairness_and_patterns()
	_test_player_contract_and_restart()
	_test_bounded_course_pool()
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		printerr("[FAIL] %s" % label)


func _test_all_lane_shape_pairs() -> void:
	var validated_pairs := 0
	for lane: int in range(3):
		for shape: int in range(3):
			var gate := GATE_SPEC_SCRIPT.new(0, GATE_SPEC_SCRIPT.Pattern.SINGLE_APERTURE, [Vector2i(lane, shape)], 2.0, 1.5)
			_expect(gate.accepts(lane, shape), "gate accepts lane %d shape %d" % [lane, shape])
			for other_lane: int in range(3):
				for other_shape: int in range(3):
					if other_lane != lane or other_shape != shape:
						_expect(not gate.accepts(other_lane, other_shape), "gate rejects incorrect pair for %d/%d" % [lane, shape])
			validated_pairs += 1
	print("[METRIC] lane_shape_pairs=%d" % validated_pairs)


func _test_score_combo_multiplier() -> void:
	var score := SCORE_SCRIPT.new()
	score.reset()
	var total := 0
	for ignored: int in range(5):
		total += score.register_judgment(EVENTS.JudgmentKind.PERFECT)
	_expect(total == 600, "five perfect judgments score 600")
	_expect(score.combo == 5 and score.multiplier == 2 and score.best_combo == 5, "combo multiplier reaches 2 at five")
	var near_points := score.register_judgment(EVENTS.JudgmentKind.NEAR_MISS)
	_expect(near_points == 120 and score.near_misses == 1 and score.combo == 6, "near miss awards scaled points and continues combo")
	score.register_judgment(EVENTS.JudgmentKind.MISS)
	_expect(score.combo == 0 and score.multiplier == 1 and score.score == 720, "miss resets combo without erasing score")
	for ignored: int in range(40):
		score.register_judgment(EVENTS.JudgmentKind.PERFECT, 1.0)
	_expect(score.multiplier == 8 and score.best_combo == 40, "multiplier is capped at eight")
	print("[METRIC] score_after_contract=%d multiplier_cap=%d" % [score.score, score.multiplier])


func _test_fairness_and_patterns() -> void:
	var report: Dictionary = FAIRNESS_SCRIPT.simulate_judgments(10000, 7719)
	_expect(report.get("valid", false), "10,000 generated judgments are reachable: %s" % report.get("failure", ""))
	_expect(report.get("checked", 0) == 10000, "fairness solver checked all 10,000 judgments")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7719
	var pattern_counts := [0, 0, 0]
	var seen_pairs: Dictionary = {}
	var previous: Variant = null
	for index: int in range(10000):
		var spec := PATTERN_LIBRARY_SCRIPT.make_spec(index, 2.0 + float(index) * 1.0, rng)
		pattern_counts[int(spec.pattern)] += 1
		for target: Vector2i in spec.targets:
			seen_pairs["%d:%d" % [target.x, target.y]] = true
		if previous != null:
			_expect(FAIRNESS_SCRIPT.is_transition_reachable(previous, spec), "reconstructed deterministic transition %d is reachable" % index)
		previous = spec
	for count: int in pattern_counts:
		_expect(count > 0, "all three obstacle patterns occur")
	_expect(seen_pairs.size() == 9, "deterministic patterns cover all nine lane/form pairs")
	print("[METRIC] fairness_checked=%d seed=%d patterns=%s pairs=%d" % [report.get("checked", 0), report.get("seed", 0), str(pattern_counts), seen_pairs.size()])


func _test_player_contract_and_restart() -> void:
	# Load dynamically so a player parse error becomes a concise failed contract
	# instead of preventing the independent fairness and scoring suite from running.
	var player_script: Script = load("res://src/player/player_controller.gd")
	_expect(player_script != null and player_script.can_instantiate(), "PlayerController parses and instantiates")
	if player_script == null or not player_script.can_instantiate():
		return
	var player: Node3D = player_script.new()
	_expect(float(player.lane_settle_seconds) <= 0.18, "lane presentation settles within 180ms contract")
	_expect(float(player.morph_seconds) <= 0.12, "shape morph presentation settles within 120ms contract")
	_expect(FAIRNESS_SCRIPT.LANE_STEP_SECONDS <= 0.18, "fairness lane transition matches input contract")
	for lane: int in range(3):
		for shape: int in range(3):
			player.reset_run(lane, shape)
			_expect(player.lane == lane and player.current_shape == shape, "reset restores lane/form %d/%d" % [lane, shape])
			var from_lane: int = int(player.lane)
			var next_lane: int = (from_lane + 1) % 3
			_expect(player.move_to_lane(next_lane) and player.lane == next_lane, "lane state changes immediately %d->%d" % [from_lane, next_lane])
			var next_shape := (shape + 1) % 3
			_expect(player.set_shape(next_shape) and player.current_shape == next_shape, "shape state changes immediately %d->%d" % [shape, next_shape])
	player.set_impacted()
	_expect(not player.input_enabled, "impact disables player input")
	var restart_started := Time.get_ticks_usec()
	player.reset_run(1, EVENTS.ShapeKind.CUBE)
	var restart_usec := Time.get_ticks_usec() - restart_started
	_expect(player.lane == 1 and player.current_shape == EVENTS.ShapeKind.CUBE and player.input_enabled, "fail -> in-place restart restores playable state")
	_expect(restart_usec < 50000, "restart state reset completes under 50ms")
	print("[METRIC] restart_reset_usec=%d player_nodes=%d" % [restart_usec, player.get_child_count()])
	player.queue_free()


func _test_bounded_course_pool() -> void:
	var course: Node3D = COURSE_SCRIPT.new()
	course.pool_size = 6
	# The pool setup is intentionally node-tree independent. Calling _ready here
	# makes this a pure headless allocation test rather than a renderer test.
	course._ready()
	course.reset_course(7719)
	_expect(course.active_specs().size() == 6, "course pre-fills its configured gate pool")
	var initial_specs: Array = course.active_specs()
	course.reset_course(7719)
	var reset_specs: Array = course.active_specs()
	_expect(initial_specs.size() == reset_specs.size() and initial_specs[0].describe_target() == reset_specs[0].describe_target(), "course reset is deterministic for a fixed seed")
	for ignored: int in range(25):
		course.advance(0.08, 20.0)
	var gate_nodes := 0
	for child: Node in course.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("track_gate_3d.gd"):
			gate_nodes += 1
	_expect(gate_nodes == 6, "course retains exactly its six allocated gate nodes")
	_expect(course.active_specs().size() <= 6, "active gates never exceed configured pool")
	print("[METRIC] gate_nodes=%d active_gates=%d pool_cap=%d" % [gate_nodes, course.active_specs().size(), course.pool_size])
	course.queue_free()


func _finish() -> void:
	var elapsed_ms := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	if _failures.is_empty():
		print("[PASS] checks=%d elapsed_ms=%.1f" % [_checks, elapsed_ms])
		quit(0)
		return
	printerr("[FAIL] checks=%d failures=%d elapsed_ms=%.1f" % [_checks, _failures.size(), elapsed_ms])
	quit(1)
