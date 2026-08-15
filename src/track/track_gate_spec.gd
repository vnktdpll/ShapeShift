## Immutable data for one approaching gate.
##
## Coordinate contract: the player is fixed near world Z = 0 and faces -Z.
## Gates spawn at negative Z and travel towards positive Z, reaching the
## judgment plane at Z = 0. A target pair is the one required lane/form match.
class_name TrackGateSpec
extends RefCounted

enum Pattern { SINGLE_APERTURE, SPLIT_WALL, TRANSFORM_CORRIDOR }

var sequence: int = 0
var pattern: Pattern = Pattern.SINGLE_APERTURE
var targets: Array[Vector2i] = [] # Vector2i(lane 0..2, GameEvents.ShapeKind)
var impact_time: float = 0.0
var telegraph_seconds: float = 1.6
var tutorial_text: String = ""


func _init(
		p_sequence: int = 0,
		p_pattern: Pattern = Pattern.SINGLE_APERTURE,
		p_targets: Array[Vector2i] = [],
		p_impact_time: float = 0.0,
		p_telegraph_seconds: float = 1.6,
		p_tutorial_text: String = ""
	) -> void:
	sequence = p_sequence
	pattern = p_pattern
	# Canonicalize at the data boundary so even a malformed caller cannot create
	# multiple simultaneous actionable choices.
	targets.clear()
	if not p_targets.is_empty():
		targets.append(p_targets[0])
	impact_time = p_impact_time
	telegraph_seconds = p_telegraph_seconds
	tutorial_text = p_tutorial_text


func accepts(lane: int, shape: GameEvents.ShapeKind) -> bool:
	return targets.has(Vector2i(lane, int(shape)))


func has_lane(lane: int) -> bool:
	for target: Vector2i in targets:
		if target.x == lane:
			return true
	return false


func has_shape(shape: GameEvents.ShapeKind) -> bool:
	for target: Vector2i in targets:
		if target.y == int(shape):
			return true
	return false


func describe_target() -> String:
	var labels: PackedStringArray = []
	for target: Vector2i in targets:
		labels.append("L%d %s" % [target.x + 1, GameEvents.shape_name(target.y)])
	return " / ".join(labels)
