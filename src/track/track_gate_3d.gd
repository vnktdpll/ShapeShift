## Runtime-built standalone target for ShapeShift: Neon Gauntlet.
##
## Each pooled node owns one bounded set of shape meshes. Reconfiguration only
## changes which shape is visible and where it sits; it never allocates visual
## nodes during play. Only the nearest (FOCAL) target can be visible, so the
## course always presents one unambiguous lane/form instruction at a time.
class_name TrackGate3D
extends Node3D

const LANE_X := [-3.1, 0.0, 3.1]
const CYAN := Color("38e8ff")
const MAGENTA := Color("fc4fc6")
const AMBER := Color("ffc857")
const TARGET_SCALE := 1.72
const TARGET_Y := 1.62

enum VisualPriority {
	FOCAL,
	SECONDARY,
	DEPTH,
	SUPPRESSED,
}

var spec: TrackGateSpec
var _telegraphed := false
var _visual_priority: VisualPriority = VisualPriority.SUPPRESSED
var _distance_to_impact := INF
var _target_root: Node3D
var _shape_roots: Array[Node3D] = []
var _judgment_light: OmniLight3D
var _judgment_tween: Tween
var _material_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _static_visuals_built := false


func configure(p_spec: TrackGateSpec) -> void:
	spec = p_spec
	_telegraphed = false
	if not _static_visuals_built:
		_build_static_visuals()
		_static_visuals_built = true
	_apply_spec()
	# Recycled targets may have been focal in their previous life. Suppress them
	# until TrackCourse assigns the single nearest target as the new focal cue.
	_visual_priority = VisualPriority.FOCAL
	set_visual_priority(VisualPriority.SUPPRESSED, INF)


func set_visual_priority(priority: VisualPriority, distance_to_impact: float) -> void:
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


func visible_target_count() -> int:
	if not visible or _target_root == null or not _target_root.visible:
		return 0
	var count := 0
	for shape_root: Node3D in _shape_roots:
		if shape_root.visible:
			count += 1
	return count


func mark_telegraphed() -> void:
	_telegraphed = true


func play_judgment_flash(success: bool) -> void:
	# The broad particle cue is handled by ArcadeFxDirector. This local point
	# light is preallocated with the pooled target and merely retargeted here.
	if _judgment_light == null:
		return
	if not is_inside_tree():
		_judgment_light.visible = false
		return
	if _judgment_tween != null and _judgment_tween.is_valid():
		_judgment_tween.kill()
	_judgment_light.light_color = Color("dffcff") if success else Color("ff3864")
	_judgment_light.light_energy = 2.1
	_judgment_light.visible = true
	_judgment_tween = create_tween()
	_judgment_tween.tween_property(_judgment_light, "light_energy", 0.0, 0.12)
	_judgment_tween.tween_callback(_judgment_light.set_visible.bind(false))


func _build_static_visuals() -> void:
	_target_root = Node3D.new()
	_target_root.name = "StandaloneTarget"
	_target_root.scale = Vector3.ONE * TARGET_SCALE
	add_child(_target_root)
	for shape: int in range(3):
		var shape_root := Node3D.new()
		shape_root.name = "Target_%s" % GameEvents.shape_name(shape)
		shape_root.visible = false
		_target_root.add_child(shape_root)
		_build_shape(shape_root, shape)
		_shape_roots.append(shape_root)
	_judgment_light = OmniLight3D.new()
	_judgment_light.name = "PooledJudgmentLight"
	_judgment_light.light_energy = 0.0
	_judgment_light.omni_range = 4.2
	_judgment_light.shadow_enabled = false
	_judgment_light.visible = false
	add_child(_judgment_light)


func _apply_spec() -> void:
	# Pattern generation guarantees one target; this guard makes malformed data
	# fail closed without ever exposing stale visuals from a recycled node.
	for shape_root: Node3D in _shape_roots:
		shape_root.visible = false
	if spec == null or spec.targets.is_empty():
		_target_root.visible = false
		return
	var target: Vector2i = spec.targets[0]
	# Stage the entire outline above the deck. At the largest sphere radius this
	# leaves the lower silhouette just above the road instead of clipping it into
	# a caret/semicircle at decision distance.
	_target_root.position = Vector3(LANE_X[clampi(target.x, 0, 2)], TARGET_Y, 0.0)
	_shape_roots[clampi(target.y, 0, 2)].visible = true
	_apply_visual_priority()


func _build_shape(parent: Node3D, shape: int) -> void:
	var material := _mat(Color("081122"), _shape_tint(shape), 1.55)
	match shape:
		GameEvents.ShapeKind.CUBE:
			# Thick, literal square silhouette: roughly 2.8 world units after the
			# root scale, substantially larger than the former framed aperture.
			_add_box_to(parent, Vector3(2.02, 0.20, 0.24), Vector3(0.0, 0.91, 0.0), material)
			_add_box_to(parent, Vector3(2.02, 0.20, 0.24), Vector3(0.0, -0.91, 0.0), material)
			_add_box_to(parent, Vector3(0.20, 2.02, 0.24), Vector3(-0.91, 0.0, 0.0), material)
			_add_box_to(parent, Vector3(0.20, 2.02, 0.24), Vector3(0.91, 0.0, 0.0), material)
		GameEvents.ShapeKind.PYRAMID:
			_add_outline_bar(parent, Vector2(-1.05, -0.88), Vector2(1.05, -0.88), material)
			_add_outline_bar(parent, Vector2(1.05, -0.88), Vector2(0.0, 1.02), material)
			_add_outline_bar(parent, Vector2(0.0, 1.02), Vector2(-1.05, -0.88), material)
		_:
			var ring := MeshInstance3D.new()
			ring.name = "SphereRing"
			var mesh := TorusMesh.new()
			mesh.inner_radius = 0.82
			mesh.outer_radius = 1.08
			mesh.ring_segments = 32
			mesh.rings = 12
			ring.mesh = mesh
			ring.rotation_degrees.x = 90.0
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ring.material_override = material
			parent.add_child(ring)


func _add_outline_bar(parent: Node3D, from: Vector2, to: Vector2, material: StandardMaterial3D) -> void:
	var delta := to - from
	var bar := _make_box(Vector3(delta.length(), 0.20, 0.24), material)
	bar.position = Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, 0.0)
	bar.rotation.z = delta.angle()
	parent.add_child(bar)


func _add_box_to(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var node := _make_box(size, material)
	node.position = at
	parent.add_child(node)


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
	var cached := _material_cache.get(key) as StandardMaterial3D
	if cached != null:
		return cached
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.30
	material.roughness = 0.54
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	_material_cache[key] = material
	return material


func _shape_tint(shape: int) -> Color:
	match shape:
		GameEvents.ShapeKind.PYRAMID:
			return MAGENTA
		GameEvents.ShapeKind.SPHERE:
			return AMBER
	return CYAN


func _apply_visual_priority() -> void:
	# Crucial clarity invariant: future pooled targets carry no visible shape.
	# The focal target alone is both visible and actionable to the player.
	if _target_root != null:
		_target_root.visible = _visual_priority == VisualPriority.FOCAL
