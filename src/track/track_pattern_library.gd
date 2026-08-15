## Deterministic authored pattern selection.  All methods are side-effect free
## except for the supplied RNG, making recorded runs repeatable from a seed.
class_name TrackPatternLibrary
extends RefCounted

const TUTORIAL_COUNT: int = 6


static func make_spec(index: int, impact_time: float, rng: RandomNumberGenerator) -> TrackGateSpec:
	if index < TUTORIAL_COUNT:
		return _tutorial_spec(index, impact_time)

	var pattern: TrackGateSpec.Pattern
	var roll: int = rng.randi_range(0, 99)
	if roll < 42:
		pattern = TrackGateSpec.Pattern.SINGLE_APERTURE
	elif roll < 75:
		pattern = TrackGateSpec.Pattern.SPLIT_WALL
	else:
		pattern = TrackGateSpec.Pattern.TRANSFORM_CORRIDOR
	var targets: Array[Vector2i] = _targets_for(pattern, rng)
	return TrackGateSpec.new(index, pattern, targets, impact_time, 1.45)


static func _tutorial_spec(index: int, impact_time: float) -> TrackGateSpec:
	var steps: Array[Dictionary] = [
		{"pattern": TrackGateSpec.Pattern.SINGLE_APERTURE, "targets": [Vector2i(1, GameEvents.ShapeKind.CUBE)], "text": "MATCH THE GATE  ·  CUBE"},
		{"pattern": TrackGateSpec.Pattern.SINGLE_APERTURE, "targets": [Vector2i(0, GameEvents.ShapeKind.CUBE)], "text": "SHIFT LEFT  ·  A / ←"},
		{"pattern": TrackGateSpec.Pattern.SINGLE_APERTURE, "targets": [Vector2i(2, GameEvents.ShapeKind.CUBE)], "text": "SHIFT RIGHT  ·  D / →"},
		{"pattern": TrackGateSpec.Pattern.SINGLE_APERTURE, "targets": [Vector2i(2, GameEvents.ShapeKind.PYRAMID)], "text": "MORPH PYRAMID  ·  2 / K"},
		{"pattern": TrackGateSpec.Pattern.SINGLE_APERTURE, "targets": [Vector2i(1, GameEvents.ShapeKind.SPHERE)], "text": "MORPH SPHERE  ·  3 / L"},
		{"pattern": TrackGateSpec.Pattern.SPLIT_WALL, "targets": [Vector2i(0, GameEvents.ShapeKind.CUBE), Vector2i(2, GameEvents.ShapeKind.PYRAMID)], "text": "TWO SAFE ROUTES  ·  CHOOSE FAST"},
	]
	var step: Dictionary = steps[index]
	var targets: Array[Vector2i] = []
	for target: Vector2i in step["targets"]:
		targets.append(target)
	return TrackGateSpec.new(index, step["pattern"], targets, impact_time, 1.8, step["text"])


static func _targets_for(pattern: TrackGateSpec.Pattern, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var first := Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
	if pattern == TrackGateSpec.Pattern.SINGLE_APERTURE:
		return [first]
	var second := Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
	while second == first:
		second = Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
	# Transform corridors deliberately expose different forms, so their route is
	# legible as an instruction to morph as well as move.
	if pattern == TrackGateSpec.Pattern.TRANSFORM_CORRIDOR and second.y == first.y:
		second.y = (first.y + rng.randi_range(1, 2)) % 3
	return [first, second]
