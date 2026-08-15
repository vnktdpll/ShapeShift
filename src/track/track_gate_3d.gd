## Runtime-built neon gate.  The required form is a real emissive mesh, rather
## than a texture, so it stays readable at every quality level and needs no art
## asset provenance.
class_name TrackGate3D
extends Node3D

const LANE_X := [-3.1, 0.0, 3.1]
const CYAN := Color("38e8ff")
const MAGENTA := Color("fc4fc6")
const AMBER := Color("ffc857")
const DARK := Color("11172d")
const PANEL_DARK := Color("050915")
const PANEL_EDGE := Color("1a2945")
const LANE_NAMES: PackedStringArray = ["LEFT", "CENTER", "RIGHT"]

# Gates are intentionally authored at four bounded detail levels.  The course
# promotes only the next choice, preventing a stack of world-space labels from
# competing at the vanishing point while still giving a player depth context.
enum VisualPriority {
	FOCAL,
	SECONDARY,
	DEPTH,
	SUPPRESSED,
}

var spec: TrackGateSpec
var _accent: Color = CYAN
var _telegraphed: bool = false
var _visual_priority: VisualPriority = VisualPriority.SUPPRESSED
var _distance_to_impact: float = INF
var _frame_nodes: Array[Node3D] = []
var _depth_frame_nodes: Array[Node3D] = []
var _panel_nodes: Array[Node3D] = []
var _outline_nodes: Array[Node3D] = []
var _label_nodes: Array[Node3D] = []
var _material_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _static_visuals_built: bool = false
var _obstacle_panels: Array[Node3D] = []
var _target_slots: Array[Dictionary] = []
var _transform_rails: Array[Node3D] = []
var _transform_spine: Node3D
var _active_panel_nodes: Array[Node3D] = []
var _active_outline_nodes: Array[Node3D] = []
var _active_label_nodes: Array[Node3D] = []


func configure(p_spec: TrackGateSpec) -> void:
	spec = p_spec
	_accent = _accent_for(p_spec.pattern)
	_telegraphed = false
	# Gates are recycled during play. Build a bounded superset of their visual
	# parts once, then only retarget transforms/text/visibility. This removes the
	# frame spikes caused by allocating and freeing dozens of meshes per judgment.
	if not _static_visuals_built:
		_build_frame()
		_build_static_pattern_parts()
		_static_visuals_built = true
	_apply_spec_to_static_parts()
	# A recycled node must never inherit the previous gate's foreground detail.
	_visual_priority = VisualPriority.FOCAL
	set_visual_priority(VisualPriority.SUPPRESSED, INF)


func _build_static_pattern_parts() -> void:
	for lane: int in range(3):
		var obstacle := _add_box(Vector3(2.86, 5.8, 0.16), Vector3(LANE_X[lane], 0.05, 0.03), _mat(DARK, Color("263252"), 0.15))
		_obstacle_panels.append(obstacle)
		_panel_nodes.append(obstacle)
		for slot_index: int in range(2):
			_target_slots.append(_build_static_target_slot(lane, slot_index))
		var rail := _add_box(Vector3(2.55, 0.10, 0.44), Vector3(LANE_X[lane], -1.7, -0.08), _mat(DARK, MAGENTA, 1.2))
		_transform_rails.append(rail)
		_panel_nodes.append(rail)
	_transform_spine = _add_box(Vector3(0.12, 5.9, 0.48), Vector3(0.0, 0.05, -0.12), _mat(DARK, MAGENTA, 0.8))
	_panel_nodes.append(_transform_spine)


func _build_static_target_slot(lane: int, slot_index: int) -> Dictionary:
	var panel_root := Node3D.new()
	panel_root.name = "TargetPanel_%d_%d" % [lane, slot_index]
	add_child(panel_root)
	var panel_material := _mat(PANEL_DARK, PANEL_EDGE, 0.08)
	var trim_material := _mat(PANEL_DARK, CYAN, 0.48)
	var side_material := _mat(PANEL_DARK, CYAN.darkened(0.18), 0.34)
	var background := _make_box(Vector3(2.54, 4.90, 0.15), panel_material)
	background.mesh = background.mesh.duplicate()
	background.position.z = -0.12
	panel_root.add_child(background)
	var top := _make_box(Vector3(2.61, 0.08, 0.17), trim_material)
	var bottom := _make_box(Vector3(2.61, 0.08, 0.17), trim_material)
	var left := _make_box(Vector3(0.065, 4.66, 0.19), side_material)
	var right := _make_box(Vector3(0.065, 4.66, 0.19), side_material)
	left.mesh = left.mesh.duplicate()
	right.mesh = right.mesh.duplicate()
	for part: MeshInstance3D in [top, bottom, left, right]:
		panel_root.add_child(part)
	_panel_nodes.append(panel_root)

	var aperture := Node3D.new()
	aperture.name = "ApertureSlot_%d_%d" % [lane, slot_index]
	add_child(aperture)
	var shape_roots: Array[Node3D] = []
	for shape: int in range(3):
		var shape_root := Node3D.new()
		shape_root.name = "Shape_%d" % shape
		aperture.add_child(shape_root)
		_build_shape_outline(shape_root, shape)
		shape_roots.append(shape_root)
	var label := Label3D.new()
	label.name = "TargetLabel"
	label.position = Vector3(0.0, 1.55, 0.10)
	label.font_size = 42
	label.outline_size = 6
	label.pixel_size = 0.012
	label.modulate = Color("e8f8ff")
	label.outline_modulate = Color("02050b")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	aperture.add_child(label)
	_outline_nodes.append(aperture)
	_label_nodes.append(label)
	return {"panel": panel_root, "background": background, "top": top, "bottom": bottom, "left": left, "right": right, "aperture": aperture, "shapes": shape_roots, "label": label}


func _apply_spec_to_static_parts() -> void:
	_active_panel_nodes.clear()
	_active_outline_nodes.clear()
	_active_label_nodes.clear()
	var targets_per_lane: Array[int] = [0, 0, 0]
	for target: Vector2i in spec.targets:
		targets_per_lane[target.x] += 1
	for lane: int in range(3):
		if targets_per_lane[lane] == 0:
			_active_panel_nodes.append(_obstacle_panels[lane])
	var used_per_lane: Array[int] = [0, 0, 0]
	for target: Vector2i in spec.targets:
		var occurrence := used_per_lane[target.x]
		used_per_lane[target.x] += 1
		var slot: Dictionary = _target_slots[target.x * 2 + occurrence]
		var stacked := targets_per_lane[target.x] > 1
		var y := (1.48 if occurrence == 0 else -1.48) if stacked else 0.0
		var panel_root := slot["panel"] as Node3D
		var aperture := slot["aperture"] as Node3D
		panel_root.position = Vector3(LANE_X[target.x], y, -0.03)
		aperture.position = Vector3(LANE_X[target.x], y, 0.06)
		_set_static_slot_height(slot, 2.54 if stacked else 4.90)
		var shapes := slot["shapes"] as Array
		for shape: int in range(shapes.size()):
			(shapes[shape] as Node3D).visible = shape == target.y
		var label := slot["label"] as Label3D
		label.text = "%s  %s\n%s LANE" % [_shape_glyph(target.y), _shape_name(target.y), LANE_NAMES[target.x]]
		_active_panel_nodes.append(panel_root)
		_active_outline_nodes.append(aperture)
		_active_label_nodes.append(label)
	if spec.pattern == TrackGateSpec.Pattern.TRANSFORM_CORRIDOR:
		_active_panel_nodes.append(_transform_spine)
		for target: Vector2i in spec.targets:
			var rail := _transform_rails[target.x]
			if not _active_panel_nodes.has(rail):
				_active_panel_nodes.append(rail)
	_apply_visual_priority()


func _set_static_slot_height(slot: Dictionary, height: float) -> void:
	var background := slot["background"] as MeshInstance3D
	var left := slot["left"] as MeshInstance3D
	var right := slot["right"] as MeshInstance3D
	(background.mesh as BoxMesh).size = Vector3(2.54, height, 0.15)
	(left.mesh as BoxMesh).size = Vector3(0.065, height - 0.24, 0.19)
	(right.mesh as BoxMesh).size = Vector3(0.065, height - 0.24, 0.19)
	(slot["top"] as Node3D).position = Vector3(0.0, height * 0.5, 0.08)
	(slot["bottom"] as Node3D).position = Vector3(0.0, -height * 0.5, 0.08)
	left.position = Vector3(-1.235, 0.0, 0.09)
	right.position = Vector3(1.235, 0.0, 0.09)


func set_visual_priority(priority: VisualPriority, distance_to_impact: float) -> void:
	# Public course-facing API: priority determines what can compete for player
	# attention; distance is retained for diagnostics and deterministic tuning.
	var next_priority: int = clampi(priority, VisualPriority.FOCAL, VisualPriority.SUPPRESSED)
	_distance_to_impact = maxf(0.0, distance_to_impact)
	if next_priority == _visual_priority:
		return
	_visual_priority = next_priority
	_apply_visual_priority()


func visual_priority() -> VisualPriority:
	return _visual_priority


func distance_to_impact() -> float:
	return _distance_to_impact


func mark_telegraphed() -> void:
	_telegraphed = true


func play_judgment_flash(success: bool) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("dffcff") if success else Color("ff3864")
	light.light_energy = 5.5
	light.omni_range = 8.0
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.16)
	tween.tween_callback(light.queue_free)


func _build_frame() -> void:
	# The broad structural rail carries a recessed light strip and sparse end
	# caps.  This reads as a manufactured portal without introducing competing
	# symbols at telegraph distance.
	var top_rail := _add_box(Vector3(10.8, 0.24, 0.32), Vector3(0, 3.4, 0), _mat(DARK, _accent, 0.45))
	_frame_nodes.append(top_rail)
	_depth_frame_nodes.append(top_rail)
	_frame_nodes.append(_add_box(Vector3(10.34, 0.045, 0.36), Vector3(0, 3.39, -0.18), _mat(PANEL_DARK, _accent.lightened(0.08), 0.92)))
	for x: float in [-5.15, 5.15]:
		_frame_nodes.append(_add_box(Vector3(0.34, 0.40, 0.38), Vector3(x, 3.4, 0.0), _mat(PANEL_DARK, _accent, 0.70)))
	var bottom_rail := _add_box(Vector3(10.8, 0.12, 0.20), Vector3(0, -3.2, 0), _mat(DARK, _accent, 0.35))
	_frame_nodes.append(bottom_rail)
	_frame_nodes.append(_add_box(Vector3(10.2, 0.035, 0.24), Vector3(0, -3.18, -0.13), _mat(PANEL_DARK, _accent.darkened(0.12), 0.58)))
	for x: float in [-4.65, -1.55, 1.55, 4.65]:
		var upright := _add_box(Vector3(0.17, 6.6, 0.28), Vector3(x, 0.1, 0), _mat(DARK, _accent, 0.7))
		_frame_nodes.append(upright)
		var inset_x := x - signf(x) * 0.075
		_frame_nodes.append(_add_box(Vector3(0.035, 6.10, 0.32), Vector3(inset_x, 0.1, -0.16), _mat(PANEL_DARK, _accent.lightened(0.06), 0.82)))
		if absf(x) > 4.0:
			_depth_frame_nodes.append(upright)


func _build_pattern() -> void:
	match spec.pattern:
		TrackGateSpec.Pattern.SINGLE_APERTURE:
			_build_single()
		TrackGateSpec.Pattern.SPLIT_WALL:
			_build_split()
		TrackGateSpec.Pattern.TRANSFORM_CORRIDOR:
			_build_transform()


func _build_single() -> void:
	var target: Vector2i = spec.targets[0]
	for lane: int in range(3):
		if lane != target.x:
			_add_obstacle_panel(Vector3(2.86, 5.8, 0.16), Vector3(LANE_X[lane], 0.05, 0.03), _mat(DARK, Color("263252"), 0.15))
	_build_target(target, 0.0)


func _build_split() -> void:
	# Open only the valid cells; if both choices share a lane, a central divider
	# visually distinguishes the two forms without suggesting a false route.
	for lane: int in range(3):
		var lane_has_target := false
		for target: Vector2i in spec.targets:
			lane_has_target = lane_has_target or target.x == lane
		if not lane_has_target:
			_add_obstacle_panel(Vector3(2.86, 5.8, 0.16), Vector3(LANE_X[lane], 0.05, 0.03), _mat(DARK, Color("263252"), 0.15))
	for target: Vector2i in spec.targets:
		_build_target(target, -0.03)


func _build_transform() -> void:
	# Two luminous form pylons and a chevron spine read as a "morph corridor".
	# Either shown target is valid, giving the player a fair escape route.
	for lane: int in range(3):
		var lane_has_target := false
		for target: Vector2i in spec.targets:
			lane_has_target = lane_has_target or target.x == lane
		if not lane_has_target:
			_add_obstacle_panel(Vector3(2.86, 5.8, 0.16), Vector3(LANE_X[lane], 0.05, 0.03), _mat(DARK, Color("263252"), 0.15))
	for target: Vector2i in spec.targets:
		_build_target(target, -0.10)
		_add_obstacle_panel(Vector3(2.55, 0.10, 0.44), Vector3(LANE_X[target.x], -1.7, -0.08), _mat(DARK, MAGENTA, 1.2))
	_add_obstacle_panel(Vector3(0.12, 5.9, 0.48), Vector3(0, 0.05, -0.12), _mat(DARK, MAGENTA, 0.8))


func _build_target(target: Vector2i, z_offset: float) -> void:
	var x: float = LANE_X[target.x]
	var y := _target_y(target)
	# The gate is an aperture, not a glowing prop.  A near-black plate keeps the
	# silhouette readable against the course at both distant telegraph range and
	# close, high-speed approach.  The low-energy rim provides depth without
	# blooming into the shape itself.
	_panel_nodes.append(_add_box(Vector3(2.54, _target_panel_height(target), 0.15), Vector3(x, y, z_offset - 0.12), _mat(PANEL_DARK, PANEL_EDGE, 0.08)))
	_panel_nodes.append(_add_box(Vector3(2.61, 0.08, 0.17), Vector3(x, y + _target_panel_height(target) * 0.5, z_offset - 0.04), _mat(PANEL_DARK, _accent, 0.48)))
	_panel_nodes.append(_add_box(Vector3(2.61, 0.08, 0.17), Vector3(x, y - _target_panel_height(target) * 0.5, z_offset - 0.04), _mat(PANEL_DARK, _accent, 0.48)))
	# Inset side strips, corner blocks, and a restrained inner rail make the
	# aperture feel finished while leaving the literal form glyph dominant.
	var panel_height := _target_panel_height(target)
	for side: float in [-1.0, 1.0]:
		_panel_nodes.append(_add_box(Vector3(0.065, panel_height - 0.24, 0.19), Vector3(x + side * 1.235, y, z_offset - 0.03), _mat(PANEL_DARK, _accent.darkened(0.18), 0.34)))
		for vertical: float in [-1.0, 1.0]:
			_panel_nodes.append(_add_box(Vector3(0.18, 0.18, 0.23), Vector3(x + side * 1.23, y + vertical * (panel_height * 0.5 - 0.08), z_offset - 0.01), _mat(PANEL_DARK, _accent, 0.72)))
	_panel_nodes.append(_add_box(Vector3(2.24, 0.028, 0.18), Vector3(x, y - panel_height * 0.5 + 0.22, z_offset - 0.01), _mat(PANEL_DARK, _accent.lightened(0.10), 0.38)))

	var aperture := Node3D.new()
	aperture.name = "Aperture_%s_%s" % [LANE_NAMES[target.x], _shape_name(target.y)]
	aperture.position = Vector3(x, y, z_offset + 0.06)
	add_child(aperture)
	_outline_nodes.append(aperture)
	_build_shape_outline(aperture, target.y)
	_add_target_label(aperture, target)


func _target_y(target: Vector2i) -> float:
	# A split gate may intentionally offer two different forms in one lane.
	# Stack those apertures so neither label nor silhouette can occlude the other.
	var same_lane: Array[Vector2i] = []
	for candidate: Vector2i in spec.targets:
		if candidate.x == target.x:
			same_lane.append(candidate)
	if same_lane.size() < 2:
		return 0.0
	return 1.48 if same_lane.find(target) == 0 else -1.48


func _target_panel_height(target: Vector2i) -> float:
	return 2.54 if _has_other_target_in_lane(target) else 4.90


func _has_other_target_in_lane(target: Vector2i) -> bool:
	var matches := 0
	for candidate: Vector2i in spec.targets:
		if candidate.x == target.x:
			matches += 1
	return matches > 1


func _build_shape_outline(parent: Node3D, shape: int) -> void:
	var outline_material := _mat(Color("101a2d"), _accent, 1.05)
	match shape:
		GameEvents.ShapeKind.CUBE:
			# An intentionally literal square frame reads as a cube instruction
			# before the player has time to interpret colour or text.
			_add_box_to(parent, Vector3(1.76, 0.17, 0.17), Vector3(0.0, 0.79, 0.0), outline_material)
			_add_box_to(parent, Vector3(1.76, 0.17, 0.17), Vector3(0.0, -0.79, 0.0), outline_material)
			_add_box_to(parent, Vector3(0.17, 1.76, 0.17), Vector3(-0.79, 0.0, 0.0), outline_material)
			_add_box_to(parent, Vector3(0.17, 1.76, 0.17), Vector3(0.79, 0.0, 0.0), outline_material)
		GameEvents.ShapeKind.PYRAMID:
			# Three rigid edge bars create a front-facing triangle/pyramid glyph.
			_add_outline_bar(parent, Vector2(-0.87, -0.73), Vector2(0.87, -0.73), outline_material)
			_add_outline_bar(parent, Vector2(0.87, -0.73), Vector2(0.0, 0.84), outline_material)
			_add_outline_bar(parent, Vector2(0.0, 0.84), Vector2(-0.87, -0.73), outline_material)
		_:
			# A torus faces the camera as a true circular ring, unlike a shaded
			# sphere which collapsed to a bright blob at distance.
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius = 0.67
			mesh.outer_radius = 0.87
			mesh.ring_segments = 32
			mesh.rings = 12
			ring.mesh = mesh
			ring.rotation_degrees.x = 90.0
			ring.material_override = outline_material
			parent.add_child(ring)


func _add_outline_bar(parent: Node3D, from: Vector2, to: Vector2, material: StandardMaterial3D) -> void:
	var delta := to - from
	var bar := _make_box(Vector3(delta.length(), 0.17, 0.17), material)
	bar.position = Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, 0.0)
	bar.rotation.z = delta.angle()
	parent.add_child(bar)


func _add_target_label(parent: Node3D, target: Vector2i) -> void:
	var label := Label3D.new()
	label.name = "TargetLabel"
	label.text = "%s  %s\n%s LANE" % [_shape_glyph(target.y), _shape_name(target.y), LANE_NAMES[target.x]]
	label.position = Vector3(0.0, 1.55, 0.10)
	label.font_size = 42
	label.outline_size = 6
	# Labels are intentionally world-sized so stacked future gates do not turn
	# into a screen-space text wall.  The outline remains the primary distant cue.
	label.pixel_size = 0.012
	label.modulate = Color("e8f8ff")
	label.outline_modulate = Color("02050b")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
	_label_nodes.append(label)


func _shape_name(shape: int) -> String:
	return GameEvents.shape_name(shape)


func _shape_glyph(shape: int) -> String:
	match shape:
		GameEvents.ShapeKind.CUBE:
			return "□"
		GameEvents.ShapeKind.PYRAMID:
			return "△"
	return "○"


func _add_box(size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := _make_box(size, material)
	node.position = at
	add_child(node)
	return node


func _add_box_to(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var node := _make_box(size, material)
	node.position = at
	parent.add_child(node)


func _add_obstacle_panel(size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	_panel_nodes.append(_add_box(size, at, material))


func _make_box(size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var key := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	var mesh: BoxMesh = _box_mesh_cache.get(key) as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_box_mesh_cache[key] = mesh
	node.mesh = mesh
	node.material_override = material
	return node


func _mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var key := "%s|%s|%.3f" % [albedo.to_html(true), emission.to_html(true), energy]
	var cached: StandardMaterial3D = _material_cache.get(key) as StandardMaterial3D
	if cached != null:
		return cached
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.55
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	_material_cache[key] = material
	return material


func _accent_for(pattern: TrackGateSpec.Pattern) -> Color:
	match pattern:
		TrackGateSpec.Pattern.SPLIT_WALL:
			return AMBER
		TrackGateSpec.Pattern.TRANSFORM_CORRIDOR:
			return MAGENTA
	return CYAN


func _clear_children() -> void:
	for child: Node in get_children():
		child.queue_free()
	_frame_nodes.clear()
	_depth_frame_nodes.clear()
	_panel_nodes.clear()
	_outline_nodes.clear()
	_label_nodes.clear()


func _apply_visual_priority() -> void:
	var show_frame := _visual_priority == VisualPriority.FOCAL
	var show_panels := _visual_priority == VisualPriority.FOCAL
	var show_outlines := _visual_priority <= VisualPriority.SECONDARY
	var show_labels := _visual_priority == VisualPriority.FOCAL
	var show_depth_frame := _visual_priority == VisualPriority.DEPTH
	_set_visible(_frame_nodes, show_frame)
	_set_visible(_panel_nodes, false)
	_set_visible(_outline_nodes, false)
	_set_visible(_label_nodes, false)
	_set_visible(_active_panel_nodes, show_panels)
	_set_visible(_active_outline_nodes, show_outlines)
	_set_visible(_active_label_nodes, show_labels)
	if show_depth_frame:
		_set_visible(_depth_frame_nodes, true)


func _set_visible(nodes: Array[Node3D], should_show: bool) -> void:
	for node: Node3D in nodes:
		if is_instance_valid(node):
			node.visible = should_show
