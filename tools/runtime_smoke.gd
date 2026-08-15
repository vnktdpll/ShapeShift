## Launches the real main scene and advances active gameplay long enough to catch
## runtime-only integration errors that parser and isolated subsystem tests miss.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("RUNTIME_SMOKE could not load main scene")
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.start_run(true)
	if game.environment.real_city_light_count() != 4 or game.environment.atmosphere_particle_count() != 36:
		push_error("RUNTIME_SMOKE city light/atmosphere budget changed")
		await game._graceful_quit(1)
		return
	if game.environment.find_child("HorizonBeacon", true, false) != null:
		push_error("RUNTIME_SMOKE found stationary building-like horizon geometry")
		await game._graceful_quit(1)
		return
	if game.environment.city_scroll_root_count() != 5:
		push_error("RUNTIME_SMOKE expected five independently recycled facade chunks")
		await game._graceful_quit(1)
		return
	if game.environment.mid_city_scroll_root_count() != 7 or game.environment.far_city_scroll_root_count() != 8:
		push_error("RUNTIME_SMOKE expected independently recycled mid/far building layers")
		await game._graceful_quit(1)
		return
	if game.environment.city_scroll_spacing_error() > 0.01 or game.environment.mid_city_scroll_spacing_error() > 0.01 or game.environment.far_city_scroll_spacing_error() > 0.01:
		push_error("RUNTIME_SMOKE initial city-layer spacing is discontinuous")
		await game._graceful_quit(1)
		return
	var initial_city_z: float = game.environment.city_scroll_sample_z()
	var initial_mid_city_z: float = game.environment.mid_city_scroll_sample_z()
	var initial_far_city_z: float = game.environment.far_city_scroll_sample_z()
	var initial_city_wraps: int = game.environment.city_scroll_wrap_count()
	var initial_environment_nodes: int = game.environment.bounded_environment_node_count()
	game.environment.set_reduced_flash(true)
	if game.environment.atmosphere_amount_ratio() > 0.35:
		push_error("RUNTIME_SMOKE reduced-flash did not lower city atmosphere density")
		await game._graceful_quit(1)
		return
	game.environment.set_reduced_flash(false)
	for frame: int in range(90):
		await process_frame
		if game.track.visible_target_count() != 1:
			push_error("RUNTIME_SMOKE expected exactly one visible target on frame %d, got %d" % [frame, game.track.visible_target_count()])
			await game._graceful_quit(1)
			return
		for spec: TrackGateSpec in game.track.active_specs():
			if spec.targets.size() != 1:
				push_error("RUNTIME_SMOKE found a multi-target gate")
				await game._graceful_quit(1)
				return
	if is_equal_approx(game.environment.city_scroll_sample_z(), initial_city_z) and game.environment.city_scroll_wrap_count() == initial_city_wraps:
		push_error("RUNTIME_SMOKE city district did not move with the active course")
		await game._graceful_quit(1)
		return
	if is_equal_approx(game.environment.mid_city_scroll_sample_z(), initial_mid_city_z):
		push_error("RUNTIME_SMOKE mid-city building layer remained stationary")
		await game._graceful_quit(1)
		return
	if is_equal_approx(game.environment.far_city_scroll_sample_z(), initial_far_city_z):
		push_error("RUNTIME_SMOKE far-city building layer remained stationary")
		await game._graceful_quit(1)
		return
	# Cross a complete facade pitch explicitly so the bounded recycle path is
	# covered even on unusually fast headless runners.
	game.environment.advance(20.0)
	if game.environment.city_scroll_wrap_count() <= initial_city_wraps:
		push_error("RUNTIME_SMOKE facade chunks did not recycle across the loop boundary")
		await game._graceful_quit(1)
		return
	if game.environment.city_scroll_last_wrap_count() >= game.environment.city_scroll_root_count():
		push_error("RUNTIME_SMOKE all city chunks wrapped together")
		await game._graceful_quit(1)
		return
	if game.environment.last_mid_city_wrap_count() <= 0 or game.environment.last_mid_city_wrap_count() >= game.environment.mid_city_scroll_root_count():
		push_error("RUNTIME_SMOKE mid-city layer did not recycle a staggered chunk")
		await game._graceful_quit(1)
		return
	if game.environment.last_far_city_wrap_count() <= 0 or game.environment.last_far_city_wrap_count() >= game.environment.far_city_scroll_root_count():
		push_error("RUNTIME_SMOKE far-city layer did not recycle a staggered chunk")
		await game._graceful_quit(1)
		return
	if game.environment.city_scroll_spacing_error() > 0.01 or game.environment.mid_city_scroll_spacing_error() > 0.01 or game.environment.far_city_scroll_spacing_error() > 0.01:
		push_error("RUNTIME_SMOKE city-layer spacing changed across recycle")
		await game._graceful_quit(1)
		return
	if game.environment.bounded_environment_node_count() != initial_environment_nodes:
		push_error("RUNTIME_SMOKE environment node budget grew while scrolling")
		await game._graceful_quit(1)
		return
	if game.environment.real_city_light_count() != 4 or game.environment.atmosphere_particle_count() != 36:
		push_error("RUNTIME_SMOKE city light/atmosphere budget grew while scrolling")
		await game._graceful_quit(1)
		return
	print("CITY_SCROLL_PASS z=%.3f wraps=%d nodes=%d lights=%d atmosphere=%d" % [game.environment.city_scroll_sample_z(), game.environment.city_scroll_wrap_count(), initial_environment_nodes, game.environment.real_city_light_count(), game.environment.atmosphere_particle_count()])
	# Exercise the real GameRoot miss path. A single MISS must synchronously leave
	# active gameplay, then settle on results; restart must restore a fresh run.
	game._on_gate_judged(GameEvents.JudgmentKind.MISS, 0, 999)
	if game.state != GameEvents.RunState.CRASHED or game.player.input_enabled:
		push_error("RUNTIME_SMOKE first miss was not immediately terminal")
		await game._graceful_quit(1)
		return
	await create_timer(0.22).timeout
	if game.state != GameEvents.RunState.RESULTS:
		push_error("RUNTIME_SMOKE terminal miss did not reach results")
		await game._graceful_quit(1)
		return
	game.reset_run()
	if game.state != GameEvents.RunState.TUTORIAL or not game.player.input_enabled or game.score_system.score != 0:
		push_error("RUNTIME_SMOKE restart did not restore a fresh one-attempt run")
		await game._graceful_quit(1)
		return
	print("ONE_LIFE_RESTART_PASS")
	print("RUNTIME_SMOKE_PASS")
	await game._graceful_quit(0)
