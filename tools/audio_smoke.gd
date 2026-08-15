extends SceneTree

## Headless contract check for the procedural presentation and audio modules.
## Run: Godot --headless --path . --script res://tools/audio_smoke.gd

func _init() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := NeonCourseEnvironment.new()
	world.add_child(environment)
	var fx := ArcadeFxDirector.new()
	world.add_child(fx)
	var audio := ReactiveAudioEngine.new()
	root.add_child(audio)
	var events := GameEvents.new()
	root.add_child(events)
	fx.bind_events(events)
	audio.bind_events(events)
	await process_frame
	events.run_started.emit(813)
	events.lane_changed.emit(1)
	events.shape_changed.emit(GameEvents.ShapeKind.SPHERE)
	events.gate_judged.emit(GameEvents.JudgmentKind.PERFECT, 100)
	events.combo_changed.emit(10, 2)
	events.speed_changed.emit(28.0, 0.72)
	events.run_paused.emit(true)
	events.run_paused.emit(false)
	events.run_failed.emit(1000, 1000)
	await process_frame
	assert(environment.get_node_or_null("ReactiveCourseDressing") != null)
	assert(audio.get_node_or_null("ProceduralMusic") != null)
	assert(audio.get_node_or_null("ProceduralSfx") != null)
	assert(fx.get_child_count() > 1)
	audio.shutdown_audio()
	await create_timer(0.25).timeout
	audio.queue_free()
	world.queue_free()
	events.queue_free()
	await process_frame
	await process_frame
	print("PRESENTATION_AUDIO_SMOKE_PASS")
	quit(0)
