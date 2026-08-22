## Launches the real main scene and advances active gameplay long enough to catch
## runtime-only integration errors that parser and isolated subsystem tests miss.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var environment_scene := load("res://scenes/presentation/neon_environment.tscn") as PackedScene
	var environment_profile := load("res://assets/environment/neon_city_profile.tres") as NeonCityProfile
	if environment_scene == null or environment_profile == null:
		push_error("RUNTIME_SMOKE modular environment scene/profile could not load")
		quit(1)
		return
	var authored_environment := environment_scene.instantiate() as NeonCourseEnvironment
	if authored_environment == null or authored_environment.city_profile == null:
		push_error("RUNTIME_SMOKE modular environment scene is not profile-bound")
		quit(1)
		return
	var custom_profile := environment_profile.duplicate(true) as NeonCityProfile
	custom_profile.close_chunk_count = 4
	custom_profile.real_light_count = 3
	custom_profile.atmosphere_particle_count = 20
	authored_environment.city_profile = custom_profile
	authored_environment.build()
	if authored_environment.city_scroll_root_count() != 4 or authored_environment.real_city_light_count() != 3 or authored_environment.atmosphere_particle_count() != 20:
		push_error("RUNTIME_SMOKE environment profile values did not drive pooled generation")
		authored_environment.free()
		quit(1)
		return
	if authored_environment.city_building_footprint_count() != 84 or authored_environment.city_building_footprint_overlap_count() != 0:
		push_error("RUNTIME_SMOKE edited environment profile broke deterministic zoning")
		authored_environment.free()
		quit(1)
		return
	authored_environment.free()
	print("MODULAR_ENVIRONMENT_PASS scene=neon_environment profile=neon_city_profile custom_chunks=4 custom_lights=3 custom_atmosphere=20")
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("RUNTIME_SMOKE could not load main scene")
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var subsystem_scenes := {
		"NeonCourseEnvironment": "res://scenes/presentation/neon_environment.tscn",
		"TrackCourse": "res://scenes/gameplay/track/track_course.tscn",
		"Player": "res://scenes/gameplay/player/player.tscn",
		"ArcadeFxDirector": "res://scenes/presentation/arcade_fx_director.tscn",
		"ArcadeCameraRig": "res://scenes/presentation/arcade_camera_rig.tscn",
		"ReactiveAudioEngine": "res://scenes/audio/reactive_audio_engine.tscn",
		"HUD": "res://scenes/ui/hud.tscn",
	}
	for subsystem_name: String in subsystem_scenes:
		var matches := game.get_children().filter(func(child: Node) -> bool: return child.name == subsystem_name)
		if matches.size() != 1 or (matches[0] as Node).scene_file_path != subsystem_scenes[subsystem_name]:
			push_error("RUNTIME_SMOKE modular subsystem missing, duplicated, or not scene-authored: %s" % subsystem_name)
			await game._graceful_quit(1)
			return
	if game.fx.spark_template == null or game.fx.spark_profile == null \
			or game.fx.particle_capacity() != 100 \
			or game.fx.quality_particle_budget() != 100 \
			or game.fx.get_node("PooledSparks").get_child_count() != 100:
		push_error("RUNTIME_SMOKE authored FX template/profile did not drive exactly one bounded production pool")
		await game._graceful_quit(1)
		return
	if game.player.get_node_or_null("Avatar/CubeForm/CubePrimitive") == null \
			or game.player.get_node_or_null("Avatar/PyramidForm/PyramidPrimitive") == null \
			or game.player.get_node_or_null("Avatar/SphereForm/SpherePrimitive") == null \
			or game.player.get_node_or_null("Avatar/Hitbox/CollisionShape3D") == null:
		push_error("RUNTIME_SMOKE authored player primitives are incomplete")
		await game._graceful_quit(1)
		return
	var first_pooled_gate := game.track.get_child(0) as TrackGate3D
	if first_pooled_gate == null or first_pooled_gate.scene_file_path != "res://scenes/gameplay/track/target_gate.tscn" \
			or first_pooled_gate.get_node_or_null("StandaloneTarget/Target_Cube") == null \
			or first_pooled_gate.get_node_or_null("StandaloneTarget/Target_Pyramid") == null \
			or first_pooled_gate.get_node_or_null("StandaloneTarget/Target_Sphere") == null \
			or first_pooled_gate.get_node_or_null("PooledJudgmentLight") == null:
		push_error("RUNTIME_SMOKE pooled target gates are not authored primitive instances")
		await game._graceful_quit(1)
		return
	print("MODULAR_SCENE_TREE_PASS subsystems=%d player_forms=3 target_forms=3 fx_pool=100" % subsystem_scenes.size())
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
	if game.environment.close_window_pane_count() < 100 or game.environment.minimum_window_pane_height() < 0.30:
		push_error("RUNTIME_SMOKE close-city windows regressed to sparse line details")
		await game._graceful_quit(1)
		return
	if game.environment.mid_window_pane_count() < 100 or game.environment.far_window_pane_count() < 250:
		push_error("RUNTIME_SMOKE mid/far building belts lack occupied window rhythms")
		await game._graceful_quit(1)
		return
	if game.environment.mid_far_articulation_count() < 300:
		push_error("RUNTIME_SMOKE mid/far towers lack bounded setback/crown articulation")
		await game._graceful_quit(1)
		return
	if game.environment.city_building_footprint_count() != 86:
		push_error("RUNTIME_SMOKE authored city footprint registry is incomplete")
		await game._graceful_quit(1)
		return
	if game.environment.city_building_footprint_overlap_count() != 0:
		push_error("RUNTIME_SMOKE found building-on-building footprint penetration")
		await game._graceful_quit(1)
		return
	if game.environment.minimum_city_building_footprint_clearance() < game.environment.minimum_building_footprint_clearance_required():
		push_error("RUNTIME_SMOKE authored city building clearance fell below its safety margin")
		await game._graceful_quit(1)
		return
	if game.environment.minimum_cross_tier_lateral_gap() < 0.70:
		push_error("RUNTIME_SMOKE close/mid/far city zoning collapsed into an adjacent belt")
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
	var initial_window_panes: int = game.environment.close_window_pane_count() + game.environment.mid_window_pane_count() + game.environment.far_window_pane_count()
	var initial_articulations: int = game.environment.mid_far_articulation_count()
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
	var final_window_panes: int = game.environment.close_window_pane_count() + game.environment.mid_window_pane_count() + game.environment.far_window_pane_count()
	if final_window_panes != initial_window_panes or game.environment.mid_far_articulation_count() != initial_articulations:
		push_error("RUNTIME_SMOKE façade instance budget changed while scrolling")
		await game._graceful_quit(1)
		return
	print("CITY_SCROLL_PASS z=%.3f wraps=%d nodes=%d lights=%d atmosphere=%d panes=%d articulations=%d footprints=%d min_clearance=%.3f tier_gap=%.3f" % [game.environment.city_scroll_sample_z(), game.environment.city_scroll_wrap_count(), initial_environment_nodes, game.environment.real_city_light_count(), game.environment.atmosphere_particle_count(), final_window_panes, initial_articulations, game.environment.city_building_footprint_count(), game.environment.minimum_city_building_footprint_clearance(), game.environment.minimum_cross_tier_lateral_gap()])
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
