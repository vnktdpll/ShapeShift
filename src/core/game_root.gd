class_name GameRoot
extends Node3D

var events: GameEvents
var profile: ProfileStore
var score_system: ScoreSystem
var player: PlayerController
var track: TrackCourse
var environment: NeonCourseEnvironment
var camera_rig: ArcadeCameraRig
var fx: ArcadeFxDirector
var audio_engine: ReactiveAudioEngine
var hud: HUDController
var input_bindings: InputBindingStore

var state: GameEvents.RunState = GameEvents.RunState.READY
var _state_before_pause: GameEvents.RunState = GameEvents.RunState.RUNNING
var _seed: int = 7719
var _run_index: int = 0
var _run_time: float = 0.0
var _speed: float = 14.0
var _speed_emit_clock: float = 0.0
var _previous_lane: int = 1
var _autopilot: bool = false
var _evidence_path: String = ""
var _crash_for_evidence: bool = false
var _telegraph_count: int = 0
var _frame_times_ms: Array[float] = []
var _benchmark_seconds: float = 0.0
var _benchmark_target: float = 0.0
var _restart_requested_at_usec: int = 0
var _force_max_speed: bool = false
var _restart_benchmark_count: int = 0
var _controls_evidence := false
var _evidence_delay := 9.0
var _evidence_form := -1
var _evidence_match_lane := -1

func _ready() -> void:
	_build_runtime()
	_parse_command_line()
	_apply_settings()
	if _evidence_match_lane >= 0:
		call_deferred("_capture_match_light_evidence")
	elif _controls_evidence:
		call_deferred("_capture_controls_evidence")
	elif _autopilot or not _evidence_path.is_empty() or _benchmark_target > 0.0:
		call_deferred("start_run", true)
	if _restart_benchmark_count > 0:
		get_tree().create_timer(0.5).timeout.connect(_run_restart_benchmark)

func _build_runtime() -> void:
	events = GameEvents.new()
	events.name = "GameEvents"
	add_child(events)
	profile = ProfileStore.new()
	profile.load_profile()
	input_bindings = InputBindingStore.new()
	input_bindings.capture_defaults()
	input_bindings.restore(profile)
	score_system = ScoreSystem.new()

	environment = NeonCourseEnvironment.new()
	environment.name = "NeonCourseEnvironment"
	add_child(environment)
	track = TrackCourse.new()
	track.name = "TrackCourse"
	add_child(track)
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	fx = ArcadeFxDirector.new()
	fx.name = "ArcadeFxDirector"
	add_child(fx)
	camera_rig = ArcadeCameraRig.new()
	camera_rig.name = "ArcadeCameraRig"
	camera_rig.target = player
	add_child(camera_rig)
	audio_engine = ReactiveAudioEngine.new()
	audio_engine.name = "ReactiveAudioEngine"
	add_child(audio_engine)
	hud = HUDController.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(profile, input_bindings)

	fx.set_emission_anchor(player)
	fx.bind_events(events)
	camera_rig.bind_events(events)
	audio_engine.bind_events(events)
	player.lane_changed.connect(_on_player_lane_changed)
	player.shape_changed.connect(_on_player_shape_changed)
	track.gate_telegraphed.connect(_on_gate_telegraphed)
	track.gate_judged.connect(_on_gate_judged)
	score_system.changed.connect(_on_score_changed)
	score_system.milestone.connect(_on_combo_milestone)
	hud.restart_requested.connect(_on_restart_requested)
	hud.pause_requested.connect(_set_paused)
	hud.settings_changed.connect(_apply_settings)
	hud.gameplay_action_requested.connect(_on_gameplay_action_requested)
	player.set_active(false)

func _input(event: InputEvent) -> void:
	if hud != null and hud.capture_confirm(event):
		get_viewport().set_input_as_handled()
		return
	if hud != null and hud.capture_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_mute", false):
		profile.muted = not profile.muted
		profile.save_profile()
		_apply_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause_game", false) and state not in [GameEvents.RunState.READY, GameEvents.RunState.CRASHED, GameEvents.RunState.RESULTS]:
		_set_paused(state != GameEvents.RunState.PAUSED)
		get_viewport().set_input_as_handled()
		return
	# Menus own ui_accept. Never let a legacy or user-created binding overlap
	# consume a focused controller press before the button receives it.
	if event.is_action_pressed(&"restart_run", false) and state in [GameEvents.RunState.TUTORIAL, GameEvents.RunState.RUNNING, GameEvents.RunState.CRASHED, GameEvents.RunState.RESULTS]:
		_on_restart_requested()
		get_viewport().set_input_as_handled()
		return
	if state == GameEvents.RunState.READY and _is_gameplay_input(event):
		start_run(false)


func _on_gameplay_action_requested(action: StringName) -> void:
	if action == &"pause_game":
		if state in [GameEvents.RunState.TUTORIAL, GameEvents.RunState.RUNNING]:
			_set_paused(true)
		return
	if state == GameEvents.RunState.READY:
		start_run(false)
	if state not in [GameEvents.RunState.TUTORIAL, GameEvents.RunState.RUNNING]:
		return
	match action:
		&"move_left": player.move_left()
		&"move_right": player.move_right()
		&"shape_cube": player.set_shape(GameEvents.ShapeKind.CUBE)
		&"shape_pyramid": player.set_shape(GameEvents.ShapeKind.PYRAMID)
		&"shape_sphere": player.set_shape(GameEvents.ShapeKind.SPHERE)

func _is_gameplay_input(event: InputEvent) -> bool:
	for action: StringName in [&"move_left", &"move_right", &"shape_cube", &"shape_pyramid", &"shape_sphere"]:
		if event.is_action_pressed(action, false):
			return true
	return false

func _process(delta: float) -> void:
	_frame_times_ms.append(delta * 1000.0)
	if _frame_times_ms.size() > 36000:
		_frame_times_ms.pop_front()
	if state in [GameEvents.RunState.TUTORIAL, GameEvents.RunState.RUNNING]:
		_run_time += delta
		_speed = track.max_speed if _force_max_speed else track.speed_for_elapsed(_run_time)
		track.set_player_state(player.lane, player.current_shape)
		track.advance(delta, _speed)
		environment.set_scroll_speed(_speed)
		var intensity := clampf((_speed - track.base_speed) / maxf(0.01, track.max_speed - track.base_speed), 0.0, 1.0)
		camera_rig.set_speed_normalized(intensity)
		_speed_emit_clock += delta
		if _speed_emit_clock >= 0.1:
			_speed_emit_clock = 0.0
			events.speed_changed.emit(_speed, intensity)
	if _benchmark_target > 0.0:
		_benchmark_seconds += delta
		if _benchmark_seconds >= _benchmark_target:
			_benchmark_target = 0.0
			_write_performance_evidence()
			_capture_and_quit()

func start_run(is_automatic: bool = false) -> void:
	_run_time = 0.0
	_telegraph_count = 0
	score_system.reset()
	player.reset_run(1, GameEvents.ShapeKind.CUBE)
	player.set_active(true)
	track.reset_course(_seed)
	state = GameEvents.RunState.TUTORIAL
	hud.show_running()
	hud.update_score(0)
	if _evidence_form >= GameEvents.ShapeKind.CUBE:
		player.set_shape(_evidence_form)
	events.run_started.emit(_seed)
	if not is_automatic:
		audio_engine.play_menu_action()

func reset_run() -> void:
	_restart_requested_at_usec = Time.get_ticks_usec()
	_run_index += 1
	_seed = 7719 + _run_index * 997
	_run_time = 0.0
	_telegraph_count = 0
	score_system.reset()
	player.reset_run(1, GameEvents.ShapeKind.CUBE)
	player.set_active(true)
	track.reset_course(_seed)
	state = GameEvents.RunState.TUTORIAL
	hud.show_running()
	hud.update_score(0)
	events.run_restarted.emit(_seed)
	var restart_ms := float(Time.get_ticks_usec() - _restart_requested_at_usec) / 1000.0
	# Reset restores the lane/form, score, course, and active touch input in place.

func fail_run() -> void:
	if state in [GameEvents.RunState.CRASHED, GameEvents.RunState.RESULTS]:
		return
	state = GameEvents.RunState.CRASHED
	track.stop_course()
	player.set_impacted()
	var is_new_best := profile.register_score(score_system.score)
	events.run_failed.emit(score_system.score, profile.high_score)
	await get_tree().create_timer(0.18).timeout
	state = GameEvents.RunState.RESULTS
	hud.show_results(score_system.score, profile.high_score, is_new_best)
	if _crash_for_evidence and not _evidence_path.is_empty():
		await get_tree().create_timer(0.45).timeout
		_capture_and_quit()

func _set_paused(paused: bool) -> void:
	if paused:
		_state_before_pause = state
		state = GameEvents.RunState.PAUSED
		player.set_active(false)
	else:
		state = _state_before_pause
		player.set_active(true)
	hud.show_paused(paused)
	events.run_paused.emit(paused)

func _on_restart_requested() -> void:
	audio_engine.play_menu_action()
	reset_run()

func _on_player_lane_changed(lane: int) -> void:
	var direction := signf(float(lane - _previous_lane))
	_previous_lane = lane
	events.lane_changed.emit(lane)
	camera_rig.set_lane_direction(direction)
	fx.emit_lane_trail_world(player.lane_world_position(lane), direction)

func _on_player_shape_changed(shape: int) -> void:
	var typed_shape: GameEvents.ShapeKind = shape as GameEvents.ShapeKind
	events.shape_changed.emit(typed_shape)

func _on_gate_telegraphed(lane: int, shape: GameEvents.ShapeKind, time_to_impact: float, tutorial_text: String) -> void:
	_telegraph_count += 1
	events.gate_telegraphed.emit(lane, shape, time_to_impact)
	# Gate geometry teaches the opening sequence; active play never displays prose.
	if _autopilot:
		var should_crash := _crash_for_evidence and _telegraph_count >= 5
		_autopilot_target(lane, shape, maxf(0.0, time_to_impact - 0.42), should_crash)

func _autopilot_target(lane: int, shape: GameEvents.ShapeKind, delay: float, should_crash: bool) -> void:
	await get_tree().create_timer(delay).timeout
	if state not in [GameEvents.RunState.TUTORIAL, GameEvents.RunState.RUNNING]:
		return
	if should_crash:
		player.move_to_lane((lane + 1) % 3)
		player.set_shape((int(shape) + 1) % 3)
	else:
		player.move_to_lane(lane)
		player.set_shape(shape)

func _on_gate_judged(kind: GameEvents.JudgmentKind, _base_points: int, gate_sequence: int) -> void:
	var intensity := clampf((_speed - track.base_speed) / maxf(0.01, track.max_speed - track.base_speed), 0.0, 1.0)
	var awarded := score_system.register_judgment(kind, intensity)
	events.gate_judged.emit(kind, awarded)
	events.combo_changed.emit(score_system.combo, score_system.multiplier)
	if judgment_is_terminal(kind):
		# ShapeShift is a strict one-attempt run: anything short of a perfect
		# lane/form match ends the run immediately.
		player.play_damage_feedback()
		camera_rig.impulse_shake(0.18, 0.12)
		fail_run()
	elif kind == GameEvents.JudgmentKind.PERFECT:
		hud.pulse_success()
		camera_rig.impulse_shake(0.045, 0.06)
	else:
		camera_rig.impulse_shake(0.10, 0.08)
	if gate_sequence >= TrackPatternLibrary.TUTORIAL_COUNT - 1 and state == GameEvents.RunState.TUTORIAL:
		state = GameEvents.RunState.RUNNING


static func judgment_is_terminal(kind: GameEvents.JudgmentKind) -> bool:
	return kind != GameEvents.JudgmentKind.PERFECT

func _on_score_changed(score: int, combo: int, multiplier: int) -> void:
	hud.update_score(score, combo, multiplier)

func _on_combo_milestone(combo: int) -> void:
	hud.pulse_success()

func _apply_settings() -> void:
	player.reduced_motion = profile.reduced_motion
	camera_rig.set_reduced_motion(profile.reduced_motion)
	fx.set_reduced_flash(profile.reduced_flash)
	fx.set_quality(profile.quality as ArcadeFxDirector.Quality)
	environment.set_reduced_flash(profile.reduced_flash)
	audio_engine.set_music_volume_db(_linear_to_db(profile.music_volume))
	audio_engine.set_effects_volume_db(_linear_to_db(profile.sfx_volume))
	audio_engine.set_muted(profile.muted)

func _linear_to_db(value: float) -> float:
	return -36.0 if value <= 0.01 else clampf(linear_to_db(value), -36.0, 0.0)

func _parse_command_line() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--autopilot":
			_autopilot = true
		elif argument == "--evidence-results":
			_autopilot = true
			_crash_for_evidence = true
		elif argument.begins_with("--evidence="):
			_evidence_path = argument.trim_prefix("--evidence=")
		elif argument.begins_with("--evidence-delay="):
			_evidence_delay = maxf(0.25, argument.trim_prefix("--evidence-delay=").to_float())
		elif argument.begins_with("--evidence-form="):
			match argument.trim_prefix("--evidence-form=").to_lower():
				"cube": _evidence_form = GameEvents.ShapeKind.CUBE
				"pyramid": _evidence_form = GameEvents.ShapeKind.PYRAMID
				"sphere": _evidence_form = GameEvents.ShapeKind.SPHERE
		elif argument.begins_with("--evidence-match-lane="):
			match argument.trim_prefix("--evidence-match-lane=").to_lower():
				"left", "0": _evidence_match_lane = 0
				"center", "centre", "1": _evidence_match_lane = 1
				"right", "2": _evidence_match_lane = 2
		elif argument.begins_with("--benchmark="):
			_benchmark_target = maxf(1.0, argument.trim_prefix("--benchmark=").to_float())
		elif argument == "--max-speed":
			_force_max_speed = true
		elif argument == "--evidence-controls":
			_controls_evidence = true
		elif argument.begins_with("--restart-benchmark="):
			_restart_benchmark_count = maxi(1, argument.trim_prefix("--restart-benchmark=").to_int())
			_autopilot = true
	if not _evidence_path.is_empty() and not _crash_for_evidence and _evidence_match_lane < 0:
		get_tree().create_timer(_evidence_delay).timeout.connect(_capture_and_quit)


func _capture_controls_evidence() -> void:
	hud._open_controls()
	await get_tree().create_timer(0.5).timeout
	await _capture_and_quit()


func _capture_match_light_evidence() -> void:
	# Evidence-only deterministic staging: exercise the same successful-judgment
	# handler and pooled gate light as live play, but hold the course at impact so
	# the 120 ms lane-local flash can be captured reliably. Normal play never
	# enters this path because it requires an explicit command-line flag.
	start_run(true)
	await get_tree().process_frame
	await get_tree().process_frame
	player.reset_run(_evidence_match_lane, GameEvents.ShapeKind.CUBE)
	player.set_active(true)
	track.set_player_state(_evidence_match_lane, GameEvents.ShapeKind.CUBE)
	track.stop_course()
	var evidence_gate: TrackGate3D = null
	for child: Node in track.get_children():
		if child is TrackGate3D and (child as TrackGate3D).visual_priority() == TrackGate3D.VisualPriority.FOCAL:
			evidence_gate = child as TrackGate3D
			break
	if evidence_gate == null:
		for child: Node in track.get_children():
			if child is TrackGate3D:
				evidence_gate = child as TrackGate3D
				break
	if evidence_gate == null:
		push_error("Match-light evidence could not locate a pooled gate")
		await _graceful_quit(1)
		return
	var evidence_spec := TrackGateSpec.new(
		777000 + _evidence_match_lane,
		TrackGateSpec.Pattern.SINGLE_APERTURE,
		[Vector2i(_evidence_match_lane, GameEvents.ShapeKind.CUBE)],
		0.0,
		1.5
	)
	evidence_gate.configure(evidence_spec)
	evidence_gate.position = Vector3.ZERO
	evidence_gate.visible = true
	evidence_gate.set_visual_priority(TrackGate3D.VisualPriority.SUPPRESSED, 0.0)
	_on_gate_judged(GameEvents.JudgmentKind.PERFECT, 100, evidence_spec.sequence)
	evidence_gate.hold_judgment_flash_for_evidence(true)
	print("MATCH_LIGHT_EVIDENCE lane=%d player=%s light=%s" % [_evidence_match_lane, str(player.interaction_world_position()), str(evidence_gate.judgment_light_world_position())])
	await RenderingServer.frame_post_draw
	await _capture_and_quit()

func _capture_and_quit() -> void:
	if not _evidence_path.is_empty():
		var absolute := _evidence_path if _evidence_path.is_absolute_path() else ProjectSettings.globalize_path("res://" + _evidence_path)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		var image := get_viewport().get_texture().get_image()
		var result := image.save_png(absolute)
		print("EVIDENCE_CAPTURE path=%s result=%d" % [absolute, result])
	await _graceful_quit()

func _write_performance_evidence() -> void:
	if _frame_times_ms.is_empty():
		return
	var sorted := _frame_times_ms.duplicate()
	sorted.sort()
	var p50: float = sorted[int(float(sorted.size() - 1) * 0.50)]
	var p95: float = sorted[int(float(sorted.size() - 1) * 0.95)]
	var p99: float = sorted[int(float(sorted.size() - 1) * 0.99)]
	var report := {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"frames": sorted.size(),
		"seconds": _benchmark_seconds,
		"p50_ms": p50,
		"p95_ms": p95,
		"p99_ms": p99,
		"p95_target_ms": 16.7,
		"passed": p95 <= 16.7,
		"active_gate_nodes": track.get_child_count(),
		"quality": profile.quality,
		"speed_mode": "forced_maximum" if _force_max_speed else "adaptive",
		"resolution": "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
	}
	var path := ProjectSettings.globalize_path("res://docs/evidence/performance.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("PERFORMANCE %s" % JSON.stringify(report))

func _run_restart_benchmark() -> void:
	var samples: Array[float] = []
	for iteration: int in range(_restart_benchmark_count):
		# Exercise the actual results-state course/player teardown path, then measure
		# the complete reset call that restores active input and a populated course.
		state = GameEvents.RunState.RESULTS
		track.stop_course()
		player.set_impacted()
		var started := Time.get_ticks_usec()
		reset_run()
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		samples.append(elapsed_ms)
		if state != GameEvents.RunState.TUTORIAL or not player.input_enabled or track.active_specs().is_empty():
			push_error("Restart benchmark cycle %d did not restore active run" % iteration)
			await _graceful_quit(1)
			return
		await get_tree().process_frame
	samples.sort()
	var p50: float = samples[int(float(samples.size() - 1) * 0.50)]
	var p95: float = samples[int(float(samples.size() - 1) * 0.95)]
	var worst: float = samples[samples.size() - 1]
	var report := {"cycles": samples.size(), "p50_ms": p50, "p95_ms": p95, "worst_ms": worst, "threshold_ms": 350.0, "passed": p95 <= 350.0}
	var path := ProjectSettings.globalize_path("res://docs/evidence/restart_latency.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("RESTART_LATENCY %s" % JSON.stringify(report))
	await _graceful_quit(0 if report.passed else 1)

func _graceful_quit(exit_code: int = 0) -> void:
	if is_instance_valid(audio_engine):
		audio_engine.shutdown_audio()
		await get_tree().create_timer(0.25).timeout
	get_tree().quit(exit_code)
