extends SceneTree

func _init() -> void:
	call_deferred("run")


func run() -> void:
	var report := TrackFairnessSolver.simulate_judgments(10000, 7719)
	assert(report.valid, "Track schedule failed: %s" % report.failure)
	assert(report.checked == 10000, "Expected 10k judgments")
	var repeat := TrackFairnessSolver.simulate_judgments(10000, 7719)
	assert(repeat == report, "Same seed must produce identical validation")
	var course := TrackCourse.new()
	get_root().add_child(course)
	course.reset_course(7719)
	assert(course.active_specs().size() == course.pool_size, "Course pool did not build")
	assert(course.active_specs()[0].tutorial_text != "", "Onboarding gate missing")
	var first_target: Vector2i = course.active_specs()[0].targets[0]
	var received: Array = []
	course.gate_judged.connect(func(kind: int, points: int, sequence: int) -> void: received.append([kind, points, sequence]))
	course.set_player_state(first_target.x, first_target.y)
	course.advance(3.2, course.base_speed)
	assert(not received.is_empty() and received[0][0] == GameEvents.JudgmentKind.PERFECT, "Perfect judgment API failed")
	course.queue_free()
	print("TRACK_SELF_TEST PASS: %s" % report)
	quit(0)
