## Headless deterministic acceptance checks for ShapeShift: Neon Gauntlet.
## Run with: Godot --headless --path . --script res://tests/test_runner.gd
extends SceneTree

const EVENTS := preload("res://src/core/game_events.gd")
const SCORE_SCRIPT := preload("res://src/scoring/score_system.gd")
const GATE_SPEC_SCRIPT := preload("res://src/track/track_gate_spec.gd")
const PATTERN_LIBRARY_SCRIPT := preload("res://src/track/track_pattern_library.gd")
const FAIRNESS_SCRIPT := preload("res://src/track/track_fairness_solver.gd")
const COURSE_SCRIPT := preload("res://src/track/track_course.gd")
const GATE_SCRIPT := preload("res://src/track/track_gate_3d.gd")
const FX_SCRIPT := preload("res://src/presentation/fx_director.gd")
const PROFILE_SCRIPT := preload("res://src/core/profile_store.gd")
const BINDINGS_SCRIPT := preload("res://src/core/input_binding_store.gd")
const GAME_ROOT_SCRIPT := preload("res://src/core/game_root.gd")
const HUD_SCRIPT := preload("res://src/ui/hud_controller.gd")

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
	_test_player_visual_silhouettes()
	_test_bounded_course_pool()
	_test_bounded_interaction_fx()
	_test_one_life_contract()
	_test_binding_contract()
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
		_expect(spec.targets.size() == 1, "generated target %d contains exactly one lane/form choice" % index)
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


func _test_player_visual_silhouettes() -> void:
	var player_script: Script = load("res://src/player/player_controller.gd")
	var player: Node3D = player_script.new()
	player._ready()
	for form_name: String in ["CubeForm", "PyramidForm", "SphereForm"]:
		var form := player.find_child(form_name, true, false)
		_expect(form != null, "%s has a persistent presentation node" % form_name)
		if form != null:
			_expect(form.get_child_count() == 1 and form.get_child(0) is MeshInstance3D, "%s is one solid mesh without cage/core/rim detail" % form_name)
	player.queue_free()


func _test_bounded_course_pool() -> void:
	var course: Node3D = COURSE_SCRIPT.new()
	course.pool_size = 6
	# The pool setup is intentionally node-tree independent. Calling _ready here
	# makes this a pure headless allocation test rather than a renderer test.
	course._ready()
	course.reset_course(7719)
	_expect(course.active_specs().size() == 6, "course pre-fills its configured gate pool")
	_expect(course.visible_target_count() == 1, "course exposes exactly one standalone target after reset")
	for spec: TrackGateSpec in course.active_specs():
		_expect(spec.targets.size() == 1, "every active pooled gate owns one target")
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
	_expect(course.visible_target_count() <= 1, "course never exposes multiple target shapes while advancing")
	var sample_gate := course.get_child(0) as Node3D
	var target_node_count := _descendant_count(sample_gate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	for index: int in range(100):
		sample_gate.configure(PATTERN_LIBRARY_SCRIPT.make_spec(index + 10, float(index + 2), rng))
	_expect(_descendant_count(sample_gate) == target_node_count, "pooled target reconfiguration never allocates additional visual nodes")
	print("[METRIC] gate_nodes=%d active_gates=%d visible_targets=%d target_nodes=%d" % [gate_nodes, course.active_specs().size(), course.visible_target_count(), target_node_count])
	course.queue_free()


func _test_bounded_interaction_fx() -> void:
	var world := Node3D.new()
	world.position = Vector3(11.0, 2.0, -7.0)
	get_root().add_child(world)
	var fx: Node3D = FX_SCRIPT.new()
	world.add_child(fx)
	var fixed_node_count := _descendant_count(fx)
	for ignored: int in range(20):
		fx.emit_impact(Vector3.ZERO)
	_expect(fx.active_particle_count() <= fx.particle_capacity(), "repeated negative impacts remain inside the particle pool cap")
	_expect(_descendant_count(fx) == fixed_node_count, "interaction bursts reuse nodes instead of allocating particle nodes")
	fx._process(1.0)
	_expect(fx.active_particle_count() == 0, "expired interaction particles return to the free pool")
	fx.emit_success(Vector3.ZERO)
	_expect(fx.active_particle_count() == 18, "positive target pass emits a visible bounded particle burst")
	fx._process(1.0)
	fx.set_reduced_flash(true)
	fx.emit_impact(Vector3.ZERO)
	_expect(fx.active_particle_count() <= 6, "reduced-flash mode caps interaction burst density")
	# Reproduce the runtime hierarchy that originally left the effect anchor at
	# center while the Avatar child moved. Every judged burst must follow the
	# actual left/center/right avatar world position.
	var player_script: Script = load("res://src/player/player_controller.gd")
	var player: Node3D = player_script.new()
	world.add_child(player)
	fx.set_emission_anchor(player)
	for lane: int in range(3):
		player.reset_run(lane, EVENTS.ShapeKind.CUBE)
		fx._on_gate_judged(EVENTS.JudgmentKind.PERFECT, 100)
		_expect(fx.last_burst_origin_world().is_equal_approx(player.interaction_world_position()), "lane %d judged burst follows the player's world position" % lane)
		fx.emit_lane_trail_world(player.lane_world_position(lane), 0.0)
		_expect(fx.last_burst_origin_world().is_equal_approx(player.lane_world_position(lane)), "lane %d trail burst uses its world-space lane origin" % lane)
	print("[METRIC] fx_nodes=%d particle_capacity=%d reduced_burst=%d" % [fixed_node_count, fx.particle_capacity(), fx.active_particle_count()])
	world.queue_free()


func _descendant_count(root: Node) -> int:
	var total := root.get_child_count()
	for child: Node in root.get_children():
		total += _descendant_count(child)
	return total


func _test_one_life_contract() -> void:
	_expect(GAME_ROOT_SCRIPT.judgment_is_terminal(EVENTS.JudgmentKind.MISS), "the first full miss is terminal in a one-attempt run")
	_expect(not GAME_ROOT_SCRIPT.judgment_is_terminal(EVENTS.JudgmentKind.NEAR_MISS), "near miss remains survivable")
	_expect(not GAME_ROOT_SCRIPT.judgment_is_terminal(EVENTS.JudgmentKind.PERFECT), "perfect judgment remains survivable")
	print("[METRIC] one_life_terminal_judgment=MISS")


func _test_binding_contract() -> void:
	var bindings := BINDINGS_SCRIPT.new()
	bindings.capture_defaults()
	var profile := PROFILE_SCRIPT.new()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	var encoded := BINDINGS_SCRIPT.event_to_data(key)
	var decoded := BINDINGS_SCRIPT.event_from_data(encoded)
	_expect(BINDINGS_SCRIPT.events_match(key, decoded), "keyboard binding serialization round-trips")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	_expect(BINDINGS_SCRIPT.events_match(pad, BINDINGS_SCRIPT.event_from_data(BINDINGS_SCRIPT.event_to_data(pad))), "controller binding serialization round-trips")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	_expect(BINDINGS_SCRIPT.events_match(stick, BINDINGS_SCRIPT.event_from_data(BINDINGS_SCRIPT.event_to_data(stick))), "controller axis binding serialization round-trips")
	_expect(InputMap.action_get_events(&"move_left").any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion), "default controller movement supports the analog stick")
	profile.input_bindings = {"move_left": [encoded]}
	bindings.restore(profile)
	_expect(InputMap.event_is_action(decoded, &"move_left", true), "persisted mapping restores to input action behavior")
	var right_event: InputEvent = InputMap.action_get_events(&"move_right")[0]
	var conflict := bindings.bind(&"move_left", right_event, profile, false, false)
	_expect(not conflict.get("ok", true) and conflict.get("reason", "") == "conflict", "binding conflict is detected before mutation")
	var displaced: InputEvent = InputMap.action_get_events(&"move_left")[0].duplicate()
	var swapped := bindings.bind(&"move_left", right_event, profile, true, false)
	_expect(swapped.get("ok", false) and not bindings.conflicts_for(&"move_left", right_event).has(&"move_right"), "explicit swap resolves a conflicting binding")
	_expect(not bindings.conflicts_for(&"move_right", displaced).has(&"move_left"), "swap moves the displaced binding instead of creating a new conflict")
	_expect(InputMap.action_get_events(&"move_right").any(func(event: InputEvent) -> bool: return BINDINGS_SCRIPT.events_match(event, displaced)), "conflicting action receives the target's displaced primary binding")
	_expect(InputMap.action_get_events(&"ui_accept").any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton), "controller can accept focused menus by default")
	_expect(InputMap.action_get_events(&"ui_cancel").any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton), "controller can cancel menus and capture by default")
	var accept_event: InputEvent = InputMap.action_get_events(&"ui_accept").filter(func(event: InputEvent) -> bool: return event is InputEventJoypadButton)[0]
	_expect(not InputMap.action_get_events(&"restart_run").any(func(event: InputEvent) -> bool: return BINDINGS_SCRIPT.events_match(event, accept_event)), "controller menu accept does not collide with restart")
	_expect(bindings.readable_binding(&"move_right").contains("PAD") or bindings.readable_binding(&"move_right").contains("STICK"), "controls menu exposes a controller binding label")
	var insets: Vector4 = HUD_SCRIPT.scaled_safe_insets(Vector2(1280, 720), Vector2i(2560, 1440), Rect2i(100, 50, 2360, 1340))
	_expect(insets.is_equal_approx(Vector4(50, 25, 50, 25)), "touch safe-area insets scale into the gameplay viewport")
	_expect(HUD_SCRIPT.TOUCH_FORM_ACTIONS == [&"shape_pyramid", &"shape_sphere"], "touch HUD exposes only triangle and circle form overrides")
	_expect(HUD_SCRIPT.TOUCH_NEUTRAL_FORM == &"shape_cube", "touch form returns to cube when neither override is held")
	InputMap.action_erase_events(&"move_left")
	bindings.ensure_recovery(profile)
	_expect(not InputMap.action_get_events(&"move_left").is_empty(), "recovery restores an unusable empty action")
	bindings.reset_defaults(profile, false)
	_expect(BINDINGS_SCRIPT.events_match(InputMap.action_get_events(&"move_left")[0], bindings._defaults[&"move_left"][0]), "reset defaults restores original mapping")
	print("[METRIC] binding_actions=%d restored=%s" % [BINDINGS_SCRIPT.ACTIONS.size(), bindings.readable_binding(&"move_left")])


func _finish() -> void:
	var elapsed_ms := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	if _failures.is_empty():
		print("[PASS] checks=%d elapsed_ms=%.1f" % [_checks, elapsed_ms])
		quit(0)
		return
	printerr("[FAIL] checks=%d failures=%d elapsed_ms=%.1f" % [_checks, _failures.size(), elapsed_ms])
	quit(1)
