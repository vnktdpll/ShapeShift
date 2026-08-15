## Responsive, self-contained avatar for ShapeShift: Neon Gauntlet.
##
## The controller deliberately owns no run rules: TrackDirector decides whether a
## gate was correct, while this node exposes immediate logical lane/form state
## and a readable presentation layer for that decision.
class_name PlayerController
extends Node3D

signal lane_changed(lane: int)
signal lane_move_started(from_lane: int, to_lane: int)
signal shape_changed(shape: int)
signal shape_shift_started(from_shape: int, to_shape: int)
signal shape_shift_finished(shape: int)

enum PlayerState { READY, ACTIVE, IMPACTED, DISABLED }

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]
const LANE_SETTLE_SECONDS := 0.156
const SHAPE_MORPH_SECONDS := 0.108
const CUBE_COLOR := Color("41e6ff")
const PYRAMID_COLOR := Color("ff4bd8")
const SPHERE_COLOR := Color("ffe36b")

@export_category("Feel")
@export_range(0.08, 0.18, 0.001, "suffix:s") var lane_settle_seconds := LANE_SETTLE_SECONDS
@export_range(0.04, 0.12, 0.001, "suffix:s") var morph_seconds := SHAPE_MORPH_SECONDS
@export var reduced_motion := false
@export var input_enabled := true

var lane := 1
var current_shape := GameEvents.ShapeKind.CUBE
var state := PlayerState.READY

var _avatar: Node3D
var _shape_nodes: Array[Node3D] = []
var _shape_materials: Array[StandardMaterial3D] = []
var _shape_detail_materials: Array[Array] = []
var _trail_nodes: Array[MeshInstance3D] = []
var _trail_materials: Array[StandardMaterial3D] = []
var _rings: Array[MeshInstance3D] = []
var _ring_materials: Array[StandardMaterial3D] = []
var _lane_tween: Tween
var _bank_tween: Tween
var _morph_tween: Tween
var _morph_from := -1
var _morph_remaining := 0.0
var _burst_remaining := 0.0
var _trail_clock := 0.0
var _shape_spin := 0.0


func _ready() -> void:
	_build_avatar()
	reset_player(lane, current_shape)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or state == PlayerState.DISABLED:
		return
	if event.is_action_pressed(&"move_left", false):
		move_left()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_right", false):
		move_right()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"shape_cube", false):
		set_shape(GameEvents.ShapeKind.CUBE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"shape_pyramid", false):
		set_shape(GameEvents.ShapeKind.PYRAMID)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"shape_sphere", false):
		set_shape(GameEvents.ShapeKind.SPHERE)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _avatar == null:
		return
	_shape_spin += delta
	_avatar.rotation.y = sin(_shape_spin * 1.6) * 0.055
	_update_trail(delta)
	_update_shift_rings(delta)
	if _morph_remaining > 0.0:
		_morph_remaining -= delta
		if _morph_remaining <= 0.0 and _morph_from >= 0:
			_shape_nodes[_morph_from].visible = false
			_morph_from = -1
			shape_shift_finished.emit(current_shape)


## Callable by UI, controller mappings, and deterministic test harnesses.
## Logical state changes immediately; the presentation always resolves in <= 180 ms.
func move_left() -> bool:
	return move_to_lane(lane - 1)


## Callable by UI, controller mappings, and deterministic test harnesses.
func move_right() -> bool:
	return move_to_lane(lane + 1)


func move_to_lane(requested_lane: int) -> bool:
	if state == PlayerState.DISABLED:
		return false
	var destination := clampi(requested_lane, 0, LANE_X.size() - 1)
	if destination == lane:
		return false
	var previous_lane := lane
	lane = destination
	lane_move_started.emit(previous_lane, lane)
	lane_changed.emit(lane)
	_animate_lane(previous_lane, lane)
	return true


## Switch form immediately for gameplay; return false when the requested form is
## already live or invalid. Shapes use GameEvents.ShapeKind numeric values.
func set_shape(requested_shape: int) -> bool:
	if state == PlayerState.DISABLED or requested_shape < GameEvents.ShapeKind.CUBE or requested_shape > GameEvents.ShapeKind.SPHERE:
		return false
	if requested_shape == current_shape:
		return false
	var previous_shape := current_shape
	current_shape = requested_shape
	shape_shift_started.emit(previous_shape, current_shape)
	shape_changed.emit(current_shape)
	_animate_shape_shift(previous_shape, current_shape)
	return true


func set_active(active: bool) -> void:
	if active:
		state = PlayerState.ACTIVE
		input_enabled = true
	else:
		state = PlayerState.READY
		input_enabled = false


func set_impacted() -> void:
	state = PlayerState.IMPACTED
	input_enabled = false
	_trigger_shift_burst(0.20)
	if _avatar != null:
		var impact_tween := create_tween()
		impact_tween.tween_property(_avatar, "scale", Vector3(1.35, 0.58, 1.35), 0.075)
		impact_tween.tween_property(_avatar, "scale", Vector3.ONE, 0.14)


## In-place reset for the near-instant fail -> restart loop.
func reset_player(start_lane := 1, start_shape := GameEvents.ShapeKind.CUBE) -> void:
	lane = clampi(start_lane, 0, LANE_X.size() - 1)
	current_shape = clampi(start_shape, GameEvents.ShapeKind.CUBE, GameEvents.ShapeKind.SPHERE)
	state = PlayerState.READY
	input_enabled = true
	_morph_from = -1
	_morph_remaining = 0.0
	_burst_remaining = 0.0
	if _lane_tween != null:
		_lane_tween.kill()
	if _bank_tween != null:
		_bank_tween.kill()
	if _morph_tween != null:
		_morph_tween.kill()
	if _avatar == null:
		return
	_avatar.position.x = LANE_X[lane]
	_avatar.rotation.z = 0.0
	_avatar.scale = Vector3.ONE
	for shape_index in _shape_nodes.size():
		_shape_nodes[shape_index].visible = shape_index == current_shape
		_shape_nodes[shape_index].scale = Vector3.ONE
		_set_shape_alpha(shape_index, 1.0 if shape_index == current_shape else 0.0)
	for trail_index in _trail_nodes.size():
		_trail_nodes[trail_index].position = Vector3(LANE_X[lane], 0.0, 0.65 + trail_index * 0.38)


## Alias used by game orchestration code that treats the player as a run component.
func reset_run(start_lane := 1, start_shape := GameEvents.ShapeKind.CUBE) -> void:
	reset_player(start_lane, start_shape)


func _animate_lane(from_lane: int, to_lane: int) -> void:
	if _avatar == null:
		return
	if _lane_tween != null:
		_lane_tween.kill()
	if _bank_tween != null:
		_bank_tween.kill()
	var direction := signf(float(to_lane - from_lane))
	var target_x: float = LANE_X[to_lane]
	var anticipation_x: float = target_x - direction * 0.18
	var anticipation_time := 0.036 if not reduced_motion else 0.018
	var settle_time := maxf(0.001, (lane_settle_seconds if not reduced_motion else 0.075) - anticipation_time)
	_lane_tween = create_tween()
	_lane_tween.set_trans(Tween.TRANS_SINE)
	_lane_tween.set_ease(Tween.EASE_OUT)
	_lane_tween.tween_property(_avatar, "position:x", anticipation_x, anticipation_time)
	_lane_tween.set_trans(Tween.TRANS_BACK)
	_lane_tween.set_ease(Tween.EASE_OUT)
	_lane_tween.tween_property(_avatar, "position:x", target_x, settle_time)
	_bank_tween = create_tween()
	_bank_tween.set_trans(Tween.TRANS_SINE)
	_bank_tween.tween_property(_avatar, "rotation:z", -direction * 0.19, anticipation_time + settle_time * 0.40)
	_bank_tween.set_ease(Tween.EASE_OUT)
	_bank_tween.tween_property(_avatar, "rotation:z", 0.0, settle_time * 0.60)
	_trigger_shift_burst(0.075)


func _animate_shape_shift(previous_shape: int, next_shape: int) -> void:
	if _avatar == null:
		return
	if _morph_tween != null:
		_morph_tween.kill()
	if _morph_from >= 0:
		_shape_nodes[_morph_from].visible = false
	var duration := morph_seconds if not reduced_motion else minf(morph_seconds, 0.055)
	var outgoing := _shape_nodes[previous_shape]
	var incoming := _shape_nodes[next_shape]
	outgoing.visible = true
	incoming.visible = true
	incoming.scale = Vector3.ONE * 0.54
	_set_shape_alpha(previous_shape, 1.0)
	_set_shape_alpha(next_shape, 0.0)
	_morph_from = previous_shape
	_morph_remaining = duration
	_morph_tween = create_tween().set_parallel(true)
	_morph_tween.set_trans(Tween.TRANS_QUAD)
	_morph_tween.set_ease(Tween.EASE_OUT)
	_morph_tween.tween_property(outgoing, "scale", Vector3.ONE * 1.34, duration)
	_morph_tween.tween_property(_shape_materials[previous_shape], "albedo_color:a", 0.0, duration)
	_morph_tween.tween_property(incoming, "scale", Vector3.ONE, duration)
	_morph_tween.tween_property(_shape_materials[next_shape], "albedo_color:a", 1.0, duration)
	for material: StandardMaterial3D in _shape_detail_materials[previous_shape]:
		_morph_tween.tween_property(material, "albedo_color:a", 0.0, duration)
	for material: StandardMaterial3D in _shape_detail_materials[next_shape]:
		_morph_tween.tween_property(material, "albedo_color:a", 1.0, duration)
	_trigger_shift_burst(duration)


func _build_avatar() -> void:
	_avatar = Node3D.new()
	_avatar.name = "Avatar"
	_avatar.position = Vector3(LANE_X[lane], 0.0, 0.0)
	add_child(_avatar)
	_add_shape_visual(_create_cube_mesh(), CUBE_COLOR, "CubeForm")
	_add_shape_visual(_create_pyramid_mesh(), PYRAMID_COLOR, "PyramidForm")
	_add_shape_visual(_create_sphere_mesh(), SPHERE_COLOR, "SphereForm")
	_build_shift_rings()
	_build_trail()
	_build_hitbox()


func _add_shape_visual(mesh: Mesh, tint: Color, visual_name: String) -> void:
	var form_root := Node3D.new()
	form_root.name = visual_name
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	# A shaded metallic body catches the course lighting; bounded emission keeps
	# the form vivid without turning it into an unreadable bloom blob.
	var material := _make_form_material(tint, 1.35)
	mesh_instance.material_override = material
	form_root.add_child(mesh_instance)
	var detail_materials: Array[StandardMaterial3D] = []
	var cage_material := _make_emissive_material(tint.lightened(0.10), 1.85)
	detail_materials.append(cage_material)
	_build_form_cage(form_root, visual_name, cage_material)
	# A compact core provides a measured focal point through the open cage.
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.17
	core_mesh.height = 0.34
	core_mesh.radial_segments = 12
	core_mesh.rings = 6
	core.mesh = core_mesh
	var core_material := _make_emissive_material(tint.lightened(0.18), 2.15)
	core_material.albedo_color.a = 0.94
	core.material_override = core_material
	form_root.add_child(core)
	detail_materials.append(core_material)
	# The rear ring reads as a rim from the chase camera rather than a halo.
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.49
	rim_mesh.outer_radius = 0.535
	rim_mesh.rings = 16
	rim_mesh.ring_segments = 6
	rim.mesh = rim_mesh
	rim.position.z = 0.36
	rim.rotation.x = PI * 0.5
	var rim_material := _make_emissive_material(tint.darkened(0.08), 1.15)
	rim_material.albedo_color.a = 0.65
	rim.material_override = rim_material
	form_root.add_child(rim)
	detail_materials.append(rim_material)
	_avatar.add_child(form_root)
	_shape_nodes.append(form_root)
	_shape_materials.append(material)
	_shape_detail_materials.append(detail_materials)


func _build_form_cage(parent: Node3D, visual_name: String, material: StandardMaterial3D) -> void:
	match visual_name:
		"CubeForm":
			# Twelve fine rails preserve the literal cube outline while suggesting
			# a machined energy cage.
			for y: float in [-0.67, 0.67]:
				for z: float in [-0.67, 0.67]:
					_add_cage_bar(parent, Vector3(1.39, 0.045, 0.045), Vector3(0, y, z), material)
			for x: float in [-0.67, 0.67]:
				for z: float in [-0.67, 0.67]:
					_add_cage_bar(parent, Vector3(0.045, 1.39, 0.045), Vector3(x, 0, z), material)
			for x: float in [-0.67, 0.67]:
				for y: float in [-0.67, 0.67]:
					_add_cage_bar(parent, Vector3(0.045, 0.045, 1.39), Vector3(x, y, 0), material)
		"PyramidForm":
			var corners := [Vector3(-0.85, -0.76, -0.85), Vector3(0.85, -0.76, -0.85), Vector3(0.85, -0.76, 0.85), Vector3(-0.85, -0.76, 0.85)]
			var apex := Vector3(0, 0.96, 0)
			for corner: Vector3 in corners:
				_add_cage_between(parent, corner, apex, material)
			for index in 4:
				_add_cage_between(parent, corners[index], corners[(index + 1) % 4], material)
		"SphereForm":
			for angle: float in [0.0, PI * 0.5, PI * 0.25]:
				var ring := MeshInstance3D.new()
				var ring_mesh := TorusMesh.new()
				ring_mesh.inner_radius = 0.76
				ring_mesh.outer_radius = 0.795
				ring_mesh.rings = 20
				ring_mesh.ring_segments = 6
				ring.mesh = ring_mesh
				ring.rotation = Vector3(PI * 0.5, angle, angle * 0.32)
				ring.material_override = material
				parent.add_child(ring)


func _add_cage_between(parent: Node3D, from: Vector3, to: Vector3, material: StandardMaterial3D) -> void:
	var delta := to - from
	var rail := _cage_box(Vector3(0.045, 0.045, delta.length()), material)
	rail.position = (from + to) * 0.5
	rail.quaternion = Quaternion(Vector3.FORWARD, delta.normalized())
	parent.add_child(rail)


func _add_cage_bar(parent: Node3D, size: Vector3, position: Vector3, material: StandardMaterial3D) -> void:
	var rail := _cage_box(size, material)
	rail.position = position
	parent.add_child(rail)


func _cage_box(size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var rail := MeshInstance3D.new()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = size
	rail.mesh = rail_mesh
	rail.material_override = material
	return rail


func _build_shift_rings() -> void:
	for index in 3:
		var ring := MeshInstance3D.new()
		ring.name = "ShiftRing%d" % index
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.64 + index * 0.04
		mesh.outer_radius = 0.69 + index * 0.04
		mesh.rings = 24
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.rotation = Vector3(index * 0.46, index * 0.79, index * 0.25)
		var material := _make_emissive_material(CUBE_COLOR, 3.6)
		material.albedo_color.a = 0.0
		ring.material_override = material
		_avatar.add_child(ring)
		_rings.append(ring)
		_ring_materials.append(material)


func _build_trail() -> void:
	var trail_mesh := TorusMesh.new()
	trail_mesh.inner_radius = 0.25
	trail_mesh.outer_radius = 0.29
	trail_mesh.rings = 16
	trail_mesh.ring_segments = 6
	for index in 8:
		var afterimage := MeshInstance3D.new()
		afterimage.name = "TrailEcho%d" % index
		afterimage.mesh = trail_mesh
		afterimage.position = Vector3(LANE_X[lane], 0.0, 0.65 + index * 0.38)
		afterimage.rotation.x = PI * 0.5
		var material := _make_emissive_material(CUBE_COLOR, 1.55)
		material.albedo_color.a = 0.26 * (1.0 - float(index) / 9.0)
		afterimage.material_override = material
		add_child(afterimage)
		_trail_nodes.append(afterimage)
		_trail_materials.append(material)


func _build_hitbox() -> void:
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 1
	hitbox.collision_mask = 2
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.72
	collision.shape = sphere
	hitbox.add_child(collision)
	_avatar.add_child(hitbox)


func _update_trail(delta: float) -> void:
	_trail_clock += delta
	var tint := _shape_color(current_shape)
	for index in _trail_nodes.size():
		var echo := _trail_nodes[index]
		var target := Vector3(_avatar.position.x, 0.0, 0.55 + index * 0.38)
		echo.position = echo.position.lerp(target, minf(1.0, delta * (15.0 - index * 0.9)))
		echo.rotation.z += delta * (1.8 + index * 0.16)
		echo.scale = Vector3.ONE * (0.72 + index * 0.055)
		var alpha := 0.22 * (1.0 - float(index) / 9.0)
		_trail_materials[index].albedo_color = Color(tint.r, tint.g, tint.b, alpha)


func _update_shift_rings(delta: float) -> void:
	if _burst_remaining <= 0.0:
		return
	_burst_remaining -= delta
	var normalized := clampf(_burst_remaining / maxf(morph_seconds, 0.001), 0.0, 1.0)
	var tint := _shape_color(current_shape)
	for index in _rings.size():
		var ring := _rings[index]
		ring.scale = Vector3.ONE * (1.0 + (1.0 - normalized) * (0.75 + index * 0.18))
		ring.rotation.y += delta * (4.0 + index)
		_ring_materials[index].albedo_color = Color(tint.r, tint.g, tint.b, normalized * 0.62)


func _trigger_shift_burst(duration: float) -> void:
	_burst_remaining = maxf(_burst_remaining, duration)


func _set_shape_alpha(shape_index: int, alpha: float) -> void:
	var tint := _shape_color(shape_index)
	_shape_materials[shape_index].albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	for material: StandardMaterial3D in _shape_detail_materials[shape_index]:
		var detail_tint := material.albedo_color
		material.albedo_color = Color(detail_tint.r, detail_tint.g, detail_tint.b, alpha)


func _shape_color(shape: int) -> Color:
	match shape:
		GameEvents.ShapeKind.CUBE:
			return CUBE_COLOR
		GameEvents.ShapeKind.PYRAMID:
			return PYRAMID_COLOR
		GameEvents.ShapeKind.SPHERE:
			return SPHERE_COLOR
	return CUBE_COLOR


func _make_emissive_material(tint: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_form_material(tint: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint.darkened(0.48)
	material.metallic = 0.74
	material.roughness = 0.20
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _create_cube_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.25, 1.25, 1.25)
	return mesh


func _create_sphere_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.78
	mesh.height = 1.56
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


func _create_pyramid_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-0.82, -0.74, -0.82), Vector3(0.82, -0.74, -0.82),
		Vector3(0.82, -0.74, 0.82), Vector3(-0.82, -0.74, 0.82),
		Vector3(0.0, 0.92, 0.0)
	])
	var indices := PackedInt32Array([
		0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4,
		0, 2, 1, 0, 3, 2
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
