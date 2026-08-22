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
	_test_neutral_hold_input_contract()
	_test_touch_hold_signal_contract()
	_test_modular_scene_architecture()
	_test_player_visual_silhouettes()
	_test_bounded_course_pool()
	_test_lane_correct_judgment_light()
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


func _test_neutral_hold_input_contract() -> void:
	var player_script: Script = load("res://src/player/player_controller.gd")
	var player: Node3D = player_script.new()
	player.reset_run(1, EVENTS.ShapeKind.CUBE)
	var fixed_node_count := _descendant_count(player)

	# Keyboard direction is a held absolute override, not a relative lane step.
	var left_key: InputEventKey = _action_event_of_type(&"move_left", "InputEventKey") as InputEventKey
	_expect(left_key != null, "keyboard left binding is available to the hold-input test")
	if left_key != null:
		left_key.pressed = true
		_expect(player.process_gameplay_input_event(left_key) and player.lane == 0, "keyboard press holds the left lane")
		left_key.pressed = false
		_expect(player.process_gameplay_input_event(left_key) and player.lane == 1, "keyboard release immediately returns to center")
	var pyramid_key: InputEventKey = _action_event_of_type(&"shape_pyramid", "InputEventKey") as InputEventKey
	_expect(pyramid_key != null, "keyboard pyramid binding is available to the hold-input test")
	if pyramid_key != null:
		pyramid_key.pressed = true
		_expect(player.process_gameplay_input_event(pyramid_key) and player.current_shape == EVENTS.ShapeKind.PYRAMID, "keyboard press holds pyramid")
		pyramid_key.pressed = false
		_expect(player.process_gameplay_input_event(pyramid_key) and player.current_shape == EVENTS.ShapeKind.CUBE, "keyboard form release immediately returns to cube")

	# The most recently pressed opposing direction wins; releasing it exposes the
	# still-held earlier direction before the final release returns to neutral.
	player.set_input_action_pressed(&"move_left", true)
	player.set_input_action_pressed(&"move_right", true)
	_expect(player.lane == 2, "latest simultaneous lane hold wins deterministically")
	player.set_input_action_pressed(&"move_right", false)
	_expect(player.lane == 0, "releasing latest lane hold restores the earlier held lane")
	player.set_input_action_pressed(&"move_left", false)
	_expect(player.lane == 1, "releasing final lane hold restores center")

	player.set_input_action_pressed(&"shape_pyramid", true)
	player.set_input_action_pressed(&"shape_sphere", true)
	_expect(player.current_shape == EVENTS.ShapeKind.SPHERE, "latest simultaneous form hold wins deterministically")
	player.set_input_action_pressed(&"shape_sphere", false)
	_expect(player.current_shape == EVENTS.ShapeKind.PYRAMID, "releasing latest form hold restores the earlier held form")
	player.set_input_action_pressed(&"shape_pyramid", false)
	_expect(player.current_shape == EVENTS.ShapeKind.CUBE, "releasing final form hold restores cube")

	# Controller D-pad/button and analog-axis edges use the same neutral contract.
	var right_pad: InputEventJoypadButton = _action_event_of_type(&"move_right", "InputEventJoypadButton") as InputEventJoypadButton
	_expect(right_pad != null, "controller D-pad right binding is available to the hold-input test")
	if right_pad != null:
		right_pad.pressed = true
		_expect(player.process_gameplay_input_event(right_pad) and player.lane == 2, "controller button press holds the right lane")
		right_pad.pressed = false
		_expect(player.process_gameplay_input_event(right_pad) and player.lane == 1, "controller button release returns to center")
	var sphere_pad: InputEventJoypadButton = _action_event_of_type(&"shape_sphere", "InputEventJoypadButton") as InputEventJoypadButton
	_expect(sphere_pad != null, "controller sphere binding is available to the hold-input test")
	if sphere_pad != null:
		sphere_pad.pressed = true
		_expect(player.process_gameplay_input_event(sphere_pad) and player.current_shape == EVENTS.ShapeKind.SPHERE, "controller form press holds sphere")
		sphere_pad.pressed = false
		_expect(player.process_gameplay_input_event(sphere_pad) and player.current_shape == EVENTS.ShapeKind.CUBE, "controller form release returns to cube")
	var left_stick: InputEventJoypadMotion = _action_event_of_type(&"move_left", "InputEventJoypadMotion") as InputEventJoypadMotion
	_expect(left_stick != null, "controller analog-left binding is available to the hold-input test")
	if left_stick != null:
		left_stick.axis_value = -1.0
		_expect(player.process_gameplay_input_event(left_stick) and player.lane == 0, "controller stick deflection holds the left lane")
		left_stick.axis_value = 1.0
		_expect(player.process_gameplay_input_event(left_stick) and player.lane == 2, "controller stick can cross directly from left to right")
		left_stick.axis_value = 0.0
		_expect(player.process_gameplay_input_event(left_stick) and player.lane == 1, "controller stick neutral returns to center")

	# Touch sends the same explicit press/release model through GameRoot.
	player.set_input_action_pressed(&"move_right", true)
	player.set_input_action_pressed(&"shape_pyramid", true)
	_expect(player.lane == 2 and player.current_shape == EVENTS.ShapeKind.PYRAMID, "touch-model holds steer lane and form together")
	player.set_input_action_pressed(&"move_right", false)
	player.set_input_action_pressed(&"shape_pyramid", false)
	_expect(player.lane == 1 and player.current_shape == EVENTS.ShapeKind.CUBE, "touch-model releases restore center cube")

	player.set_input_action_pressed(&"move_left", true)
	player.set_input_action_pressed(&"shape_sphere", true)
	player.set_active(false)
	_expect(player.lane == 1 and player.current_shape == EVENTS.ShapeKind.CUBE, "pausing clears held overrides to center cube")
	player.set_active(true)
	player.set_input_action_pressed(&"move_right", true)
	player.set_input_action_pressed(&"shape_pyramid", true)
	player.reset_run(1, EVENTS.ShapeKind.CUBE)
	_expect(player.lane == 1 and player.current_shape == EVENTS.ShapeKind.CUBE, "run reset clears held overrides to center cube")

	# Direct/autopilot calls stay persistent because neutral is applied only on an
	# actual release/reset/pause edge, never from per-frame absence polling.
	player.move_to_lane(0)
	player.set_shape(EVENTS.ShapeKind.SPHERE)
	player._process(0.25)
	_expect(player.lane == 0 and player.current_shape == EVENTS.ShapeKind.SPHERE, "programmatic lane/form selection persists without raw input")
	_expect(_descendant_count(player) == fixed_node_count, "hold/release input creates no additional player nodes")
	print("[METRIC] neutral_input=keyboard_controller_touch programmatic=persistent nodes=%d" % fixed_node_count)
	player.queue_free()


func _test_touch_hold_signal_contract() -> void:
	var hud: CanvasLayer = HUD_SCRIPT.new()
	var edges: Array[String] = []
	hud.gameplay_action_changed.connect(func(action: StringName, pressed: bool) -> void: edges.append("%s:%s" % [action, str(pressed)]))
	hud._on_touch_activated(&"move_left")
	hud._on_touch_activated(&"move_right")
	hud._on_touch_deactivated(&"move_right")
	hud._on_touch_deactivated(&"move_left")
	hud._on_touch_activated(&"shape_pyramid")
	hud._on_touch_activated(&"shape_sphere")
	hud._on_touch_deactivated(&"shape_sphere")
	hud._on_touch_deactivated(&"shape_pyramid")
	_expect(edges == ["move_left:true", "move_right:true", "move_right:false", "move_left:false", "shape_pyramid:true", "shape_sphere:true", "shape_sphere:false", "shape_pyramid:false"], "touch HUD forwards every lane/form press and release edge in order")
	hud._on_touch_activated(&"move_left")
	hud._on_touch_activated(&"shape_sphere")
	hud._set_touch_visible(false)
	_expect(hud._held_touch_lanes.is_empty() and hud._held_touch_shapes.is_empty(), "hiding touch controls clears multi-touch hold bookkeeping")
	hud.queue_free()


func _action_event_of_type(action: StringName, type_name: String) -> InputEvent:
	for event: InputEvent in InputMap.action_get_events(action):
		if event.get_class() == type_name:
			return event.duplicate()
	return null


func _test_modular_scene_architecture() -> void:
	var scene_paths := [
		"res://scenes/gameplay/player/player.tscn",
		"res://scenes/gameplay/track/target_gate.tscn",
		"res://scenes/gameplay/track/track_course.tscn",
		"res://scenes/presentation/arcade_camera_rig.tscn",
		"res://scenes/presentation/arcade_fx_director.tscn",
		"res://scenes/presentation/neon_environment.tscn",
		"res://scenes/audio/reactive_audio_engine.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/main.tscn",
	]
	for path: String in scene_paths:
		var packed := load(path) as PackedScene
		_expect(packed != null and packed.can_instantiate(), "%s is a loadable editor scene" % path)

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var expected_subsystems := ["NeonCourseEnvironment", "TrackCourse", "Player", "ArcadeFxDirector", "ArcadeCameraRig", "ReactiveAudioEngine", "HUD"]
	var actual_subsystems: Array[String] = []
	for child: Node in main.get_children():
		actual_subsystems.append(child.name)
	_expect(actual_subsystems == expected_subsystems, "main scene exposes the stable named subsystem tree")
	_expect(main.get_node("NeonCourseEnvironment").scene_file_path == "res://scenes/presentation/neon_environment.tscn", "main instances the authored environment scene")
	_expect(main.get_node("TrackCourse").scene_file_path == "res://scenes/gameplay/track/track_course.tscn", "main instances the authored track scene")
	_expect(main.get_node("Player").scene_file_path == "res://scenes/gameplay/player/player.tscn", "main instances the authored player scene")
	_expect(main.get_node("ArcadeCameraRig/Camera3D") is Camera3D, "camera scene exposes its editable Camera3D primitive")
	_expect(main.get_node("ArcadeFxDirector/PooledSparks") is Node3D and main.get_node("ArcadeFxDirector/ScreenFeedback/Flash") is ColorRect, "FX scene exposes stable pool and screen-feedback authoring groups")
	_expect(main.get_node("ReactiveAudioEngine/ProceduralMusic") is AudioStreamPlayer and main.get_node("ReactiveAudioEngine/ProceduralSfx") is AudioStreamPlayer, "audio scene exposes both editable generator players")
	_expect(main.get_node("HUD").scene_file_path == "res://scenes/ui/hud.tscn", "main instances the authored HUD scene")
	var player_scene: Node3D = main.get_node("Player") as Node3D
	var authored_player_node_count := _descendant_count(player_scene)
	var authored_form_materials: Array[Material] = []
	for form_name: String in ["CubeForm", "PyramidForm", "SphereForm"]:
		var primitive := player_scene.get_node("Avatar/%s" % form_name).get_child(0) as MeshInstance3D
		_expect(primitive != null, "player scene exposes editable %s primitive" % form_name)
		authored_form_materials.append(primitive.material_override)
	_expect(player_scene.get_node("Avatar/Hitbox/CollisionShape3D") is CollisionShape3D, "player scene exposes its editable collision primitive")
	player_scene._ready()
	_expect(_descendant_count(player_scene) == authored_player_node_count, "player controller binds the authored primitive tree without runtime duplication")
	for index in 3:
		var bound_primitive := player_scene.get_node("Avatar/%s" % ["CubeForm", "PyramidForm", "SphereForm"][index]).get_child(0) as MeshInstance3D
		_expect(bound_primitive.material_override == authored_form_materials[index], "player form %d retains its scene-authored editable material" % index)
	var course: Node3D = main.get_node("TrackCourse") as Node3D
	_expect(course.gate_scene is PackedScene and course.gate_scene.resource_path == "res://scenes/gameplay/track/target_gate.tscn", "track scene exports its reusable target-gate PackedScene")
	var authored_gate := (load("res://scenes/gameplay/track/target_gate.tscn") as PackedScene).instantiate() as Node3D
	var authored_gate_node_count := _descendant_count(authored_gate)
	var authored_cube_material := (authored_gate.get_node("StandaloneTarget/Target_Cube/Top") as MeshInstance3D).material_override
	authored_gate.configure(GATE_SPEC_SCRIPT.new(0, GATE_SPEC_SCRIPT.Pattern.SINGLE_APERTURE, [Vector2i(2, EVENTS.ShapeKind.CUBE)], 2.0, 1.5))
	_expect(authored_gate_node_count == 13 and _descendant_count(authored_gate) == authored_gate_node_count, "authored target gate binds without duplicating its 13-node primitive tree")
	_expect(authored_gate.get_node("StandaloneTarget/Target_Cube/Top").material_override == authored_cube_material, "target gate retains its scene-authored editable material")
	_expect(authored_gate.get_node("PooledJudgmentLight") is OmniLight3D, "target gate exposes its editable lane-local judgment light")
	authored_gate.free()
	print("[METRIC] modular_scenes=%d main_subsystems=%d editable_player_forms=3" % [scene_paths.size(), actual_subsystems.size()])
	main.free()


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


func _test_lane_correct_judgment_light() -> void:
	# Reconfigure one pooled gate across every lane beneath a translated parent.
	# This catches both the original center-lane flash and local/world mixups.
	var translated_parent := Node3D.new()
	translated_parent.position = Vector3(9.0, 1.5, -4.0)
	get_root().add_child(translated_parent)
	var gate: Node3D = GATE_SCRIPT.new()
	gate.position = Vector3(-2.0, 0.5, 3.0)
	translated_parent.add_child(gate)
	gate.configure(GATE_SPEC_SCRIPT.new(0, GATE_SPEC_SCRIPT.Pattern.SINGLE_APERTURE, [Vector2i(0, EVENTS.ShapeKind.CUBE)], 2.0, 1.5))
	var fixed_node_count := _descendant_count(gate)
	for lane: int in range(3):
		var spec := GATE_SPEC_SCRIPT.new(lane, GATE_SPEC_SCRIPT.Pattern.SINGLE_APERTURE, [Vector2i(lane, EVENTS.ShapeKind.CUBE)], 2.0, 1.5)
		gate.configure(spec)
		var expected_local := Vector3(GATE_SCRIPT.LANE_X[lane], 0.22, 0.0)
		_expect(gate.judgment_light_local_position().is_equal_approx(expected_local), "lane %d pooled judgment light targets the matched local lane" % lane)
		var expected_world := gate.to_global(expected_local)
		_expect(gate.judgment_light_world_position().is_equal_approx(expected_world), "lane %d pooled judgment light preserves its lane under translated hierarchy" % lane)
		_expect(_descendant_count(gate) == fixed_node_count, "lane %d judgment-light retarget preserves the pooled node count" % lane)
	translated_parent.queue_free()


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
	var target := GATE_SPEC_SCRIPT.new(0, GATE_SPEC_SCRIPT.Pattern.SINGLE_APERTURE, [Vector2i(0, EVENTS.ShapeKind.CUBE)], 2.0, 1.5)
	_expect(COURSE_SCRIPT.classify_judgment(target, 0, EVENTS.ShapeKind.CUBE) == EVENTS.JudgmentKind.PERFECT, "exact lane/form match is classified perfect")
	_expect(COURSE_SCRIPT.classify_judgment(target, 0, EVENTS.ShapeKind.SPHERE) == EVENTS.JudgmentKind.MISS, "right lane with wrong form is classified miss")
	_expect(COURSE_SCRIPT.classify_judgment(target, 1, EVENTS.ShapeKind.CUBE) == EVENTS.JudgmentKind.MISS, "wrong lane with right form is classified miss")
	_expect(COURSE_SCRIPT.classify_judgment(target, 2, EVENTS.ShapeKind.PYRAMID) == EVENTS.JudgmentKind.MISS, "wrong lane/form is classified miss")
	_expect(GAME_ROOT_SCRIPT.judgment_is_terminal(EVENTS.JudgmentKind.MISS), "the first mismatch is terminal in a one-attempt run")
	_expect(GAME_ROOT_SCRIPT.judgment_is_terminal(EVENTS.JudgmentKind.NEAR_MISS), "even a legacy near-miss signal is terminal")
	_expect(not GAME_ROOT_SCRIPT.judgment_is_terminal(EVENTS.JudgmentKind.PERFECT), "perfect judgment remains survivable")
	print("[METRIC] one_life_survivable_judgment=PERFECT")


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
