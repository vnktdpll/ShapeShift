## Pure reachability checks for the Gauntlet course.  No Node APIs are used so
## this class is valid in headless tests and can simulate large schedules.
class_name TrackFairnessSolver
extends RefCounted

const LANE_STEP_SECONDS: float = 0.18
const SHAPE_SWITCH_SECONDS: float = 0.016 # one physics tick logical response
const MIN_TELEGRAPH_SECONDS: float = 1.25
const MIN_JUDGMENT_GAP_SECONDS: float = 0.42


static func minimum_transition_seconds(from: Vector2i, to: Vector2i) -> float:
	return maxf(absf(float(from.x - to.x)) * LANE_STEP_SECONDS, SHAPE_SWITCH_SECONDS if from.y != to.y else 0.0)


static func is_transition_reachable(previous: TrackGateSpec, next: TrackGateSpec) -> bool:
	var gap: float = next.impact_time - previous.impact_time
	if gap < MIN_JUDGMENT_GAP_SECONDS or next.telegraph_seconds < MIN_TELEGRAPH_SECONDS:
		return false
	for from_target: Vector2i in previous.targets:
		for to_target: Vector2i in next.targets:
			if minimum_transition_seconds(from_target, to_target) <= gap:
				return true
	return false


static func validate_schedule(schedule: Array[TrackGateSpec]) -> Dictionary:
	if schedule.is_empty():
		return {"valid": true, "checked": 0, "failure": ""}
	for i: int in range(schedule.size()):
		var spec: TrackGateSpec = schedule[i]
		if spec.targets.is_empty() or spec.telegraph_seconds < MIN_TELEGRAPH_SECONDS:
			return {"valid": false, "checked": i, "failure": "invalid gate %d" % spec.sequence}
		for target: Vector2i in spec.targets:
			if target.x < 0 or target.x > 2 or target.y < 0 or target.y > 2:
				return {"valid": false, "checked": i, "failure": "out of range target"}
		if i > 0 and not is_transition_reachable(schedule[i - 1], spec):
			return {"valid": false, "checked": i, "failure": "unreachable %d -> %d" % [schedule[i - 1].sequence, spec.sequence]}
	return {"valid": true, "checked": schedule.size(), "failure": ""}


static func simulate_judgments(count: int = 10000, seed: int = 7719) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var schedule: Array[TrackGateSpec] = []
	var impact: float = 1.8
	for index: int in range(count):
		# This exceeds two lane changes at 180 ms and remains a readable 1.25 s
		# lead even at the maximum intended 30 units/s course speed.
		impact += 0.78 + float(rng.randi_range(0, 7)) * 0.09
		schedule.append(TrackPatternLibrary.make_spec(index, impact, rng))
	var report := validate_schedule(schedule)
	report["seed"] = seed
	report["simulated"] = count
	return report
