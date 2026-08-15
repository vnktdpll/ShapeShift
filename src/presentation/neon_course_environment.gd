class_name NeonCourseEnvironment
extends Node3D

## Runtime-only course dressing.  This is deliberately separate from the
## deterministic gate course: the road gives the runner a strong sense of
## velocity without becoming another source of gameplay information.

@export_range(8, 48, 1) var segment_count: int = 18
@export_range(5.0, 24.0, 0.5) var segment_length: float = 10.0
@export_range(2.0, 6.0, 0.25) var lane_width: float = 3.25
@export var seed: int = 813
@export var reduced_flash: bool = false

const DECK_Y := -0.38
const ROAD_MARGIN := 0.78

var _segments: Array[Node3D] = []
var _course_root: Node3D
var _rng := RandomNumberGenerator.new()
var _scroll_speed: float = 0.0
var _cyan := Color("2ae8ff")
var _pink := Color("ff3cad")
var _violet := Color("814cff")

var _foundation_material: StandardMaterial3D
var _lane_materials: Array[StandardMaterial3D] = []
var _edge_material: StandardMaterial3D
var _divider_material: StandardMaterial3D
var _marker_material: StandardMaterial3D
var _shoulder_material: StandardMaterial3D
var _architecture_material: StandardMaterial3D
var _architecture_accent_material: StandardMaterial3D
var _road_inlay_material: StandardMaterial3D
var _road_panel_material: StandardMaterial3D
var _sky_structure_material: StandardMaterial3D
var _sky_accent_material: StandardMaterial3D
var _star_material: StandardMaterial3D


func _ready() -> void:
	build()


func _process(delta: float) -> void:
	if _scroll_speed > 0.0:
		advance(_scroll_speed * delta)


func build() -> void:
	if is_instance_valid(_course_root):
		_course_root.queue_free()
	_segments.clear()
	_course_root = Node3D.new()
	_course_root.name = "ReactiveCourseDressing"
	add_child(_course_root)
	_rng.seed = seed
	_configure_world()
	_build_material_palette()
	_create_horizon()
	_create_sky_composition()
	for index in segment_count:
		var segment := _make_segment(index)
		_course_root.add_child(segment)
		_segments.append(segment)


## Recycles visual dressing behind the runner. Call from the game's track tick.
func advance(distance: float) -> void:
	for segment in _segments:
		segment.position.z += distance
		if segment.position.z > segment_length * 1.5:
			segment.position.z -= float(segment_count) * segment_length


func set_scroll_speed(speed: float) -> void:
	_scroll_speed = maxf(0.0, speed)


func set_reduced_flash(enabled: bool) -> void:
	reduced_flash = enabled
	for segment in _segments:
		var pulse := segment.get_node_or_null("Pulse") as OmniLight3D
		if pulse:
			pulse.light_energy = 0.18 if enabled else 0.36


func _configure_world() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null:
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"
		add_child(world_environment)
	var environment := Environment.new()
	# The course is intentionally dark, but it should still have a deep, legible
	# ceiling. A procedural sky is substantially cheaper than a texture and gives
	# the upper frame a navy-to-indigo atmosphere instead of an empty black slab.
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("030719")
	sky_material.sky_horizon_color = Color("172651")
	# Keep the ground half close to the horizon hue: it reads as haze rather than
	# a hard graphic horizon line behind the physical course.
	sky_material.ground_bottom_color = Color("081432")
	sky_material.ground_horizon_color = Color("172651")
	sky_material.sky_curve = 0.58
	sky_material.ground_curve = 0.72
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("1b2853")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.96
	environment.glow_enabled = true
	environment.glow_intensity = 0.40
	environment.glow_strength = 0.54
	environment.fog_enabled = true
	environment.fog_light_color = Color("172550")
	environment.fog_light_energy = 0.38
	environment.fog_density = 0.0074
	environment.fog_aerial_perspective = 0.60
	environment.fog_sky_affect = 0.70
	world_environment.environment = environment


func _build_material_palette() -> void:
	# Shared materials keep the recycled course inexpensive: around 500 simple
	# meshes, but only a small, stable palette for the renderer to manage.
	_foundation_material = _dark_material(Color("071025"), 0.90, 0.28)
	_lane_materials = [
		_dark_material(Color("0a1b38"), 0.80, 0.20),
		_dark_material(Color("102042"), 0.78, 0.18),
		_dark_material(Color("0a1b38"), 0.80, 0.20),
	]
	_edge_material = _emissive_material(_cyan, 1.05)
	_divider_material = _emissive_material(Color("3696da"), 0.32)
	_marker_material = _emissive_material(Color("59eeff"), 0.62)
	_shoulder_material = _dark_material(Color("0a1731"), 0.86, 0.24)
	_architecture_material = _dark_material(Color("142856"), 0.72, 0.30)
	_architecture_accent_material = _emissive_material(_violet, 0.42)
	_road_inlay_material = _emissive_material(Color("315a98"), 0.13)
	_road_panel_material = _dark_material(Color("0c1a35"), 0.92, 0.16)
	# Cobalt infrastructure stays clearly below the warm gate energy, but is
	# bright enough to read as deliberate architecture on an ordinary display.
	_sky_structure_material = _emissive_material(Color("315fae"), 0.25)
	_sky_accent_material = _emissive_material(Color("5f94e8"), 0.31)
	_star_material = _emissive_material(Color("9bdfff"), 0.54)


func _create_horizon() -> void:
	# A low-energy reactor is a stable vanishing-point landmark, not a competing
	# objective.  Its bands give the far end of the road an authored destination.
	var horizon_z := -segment_length * float(segment_count) * 0.87
	var reactor := MeshInstance3D.new()
	reactor.name = "HorizonReactor"
	var sphere := SphereMesh.new()
	sphere.radius = 7.6
	sphere.height = 15.2
	sphere.radial_segments = 32
	sphere.rings = 16
	reactor.mesh = sphere
	reactor.material_override = _emissive_material(_violet, 0.68)
	reactor.position = Vector3(0.0, 4.0, horizon_z)
	_course_root.add_child(reactor)
	for y in [-2.8, -0.9, 1.0, 2.9]:
		var band := _make_box(Vector3(15.4, 0.07, 0.12), _emissive_material(_cyan, 0.55))
		band.position = Vector3(0.0, 4.0 + y, horizon_z + 4.9)
		_course_root.add_child(band)
	var key := DirectionalLight3D.new()
	key.light_color = Color("6c84ff")
	key.light_energy = 0.62
	key.rotation_degrees = Vector3(-42.0, -18.0, 0.0)
	_course_root.add_child(key)


func _create_sky_composition() -> void:
	# These are a fixed, shallow-cost layer behind the gate pool. Their shapes
	# stay above or beyond the decision aperture, leaving the next gate's form and
	# lane labels as the dominant read at both the base and maximum speed.
	var sky_root := Node3D.new()
	sky_root.name = "SkyInfrastructure"
	_course_root.add_child(sky_root)
	_create_horizon_frame(sky_root, -46.0, 8.8, 22.0, 0.42)
	_create_horizon_frame(sky_root, -108.0, 12.4, 32.0, 0.26)
	_create_horizon_frame(sky_root, -174.0, 16.2, 42.0, 0.16)
	_create_upper_ribs(sky_root)
	_create_sky_stars(sky_root)


func _create_horizon_frame(parent: Node3D, depth: float, height: float, span: float, accent_energy: float) -> void:
	# Broken portal frames suggest a huge built environment without forming a
	# false gate. The open lower center deliberately preserves the roadway cone.
	for side in [-1.0, 1.0]:
		var upright := _make_box(Vector3(0.34, height * 0.64, 0.42), _sky_structure_material)
		upright.position = Vector3(side * span * 0.50, height * 0.56, depth)
		upright.rotation.z = side * -0.10
		parent.add_child(upright)
		var rail := _make_box(Vector3(span * 0.23, 0.14, 0.34), _sky_structure_material)
		rail.position = Vector3(side * span * 0.30, height, depth)
		rail.rotation.z = side * -0.08
		parent.add_child(rail)
		var tracer := _make_box(Vector3(span * 0.19, 0.026, 0.048), _emissive_material(Color("4c80d6"), accent_energy))
		tracer.position = rail.position + Vector3(0.0, 0.105, -0.17)
		tracer.rotation.z = rail.rotation.z
		parent.add_child(tracer)
	var crown := _make_box(Vector3(span * 0.26, 0.17, 0.38), _sky_structure_material)
	crown.position = Vector3(0.0, height + 0.35, depth)
	parent.add_child(crown)
	var crown_light := _make_box(Vector3(span * 0.17, 0.028, 0.052), _emissive_material(_violet, accent_energy * 0.92))
	crown_light.position = crown.position + Vector3(0.0, 0.12, -0.18)
	parent.add_child(crown_light)


func _create_upper_ribs(parent: Node3D) -> void:
	# Nearer off-axis ribs make the ceiling feel like a constructed transit
	# gauntlet. They deliberately terminate outside the lane aperture, so they
	# lend scale without ever reading as an interactive obstacle.
	for side in [-1.0, 1.0]:
		for offset in [0.0, 1.0]:
			var depth: float = -31.0 - float(offset) * 19.0
			var base_x: float = side * (10.2 + float(offset) * 2.0)
			var rib := _make_box(Vector3(0.26, 5.6 + offset * 1.2, 0.34), _sky_structure_material)
			rib.position = Vector3(base_x, 6.0 + offset * 1.25, depth)
			rib.rotation.z = side * (0.32 - offset * 0.06)
			parent.add_child(rib)
			var arm := _make_box(Vector3(2.2 + offset * 0.55, 0.16, 0.28), _sky_structure_material)
			arm.position = Vector3(side * (8.9 + offset * 1.35), 8.15 + offset * 1.55, depth)
			arm.rotation.z = side * -0.18
			parent.add_child(arm)
			var beacon_line := _make_box(Vector3(0.72, 0.035, 0.05), _sky_accent_material)
			beacon_line.position = arm.position + Vector3(side * -0.20, 0.105, -0.15)
			beacon_line.rotation.z = arm.rotation.z
			parent.add_child(beacon_line)


func _create_sky_stars(parent: Node3D) -> void:
	# A deterministic sparse field adds parallax-like depth to the high sky. It
	# avoids the center-lower cone where telegraphs and gate shapes need contrast.
	var star_points := [
		Vector3(-15.0, 8.4, -42.0), Vector3(13.8, 10.1, -49.0),
		Vector3(-10.4, 12.4, -62.0), Vector3(16.4, 14.6, -74.0),
		Vector3(-18.6, 16.1, -91.0), Vector3(8.8, 17.7, -104.0),
		Vector3(-6.5, 19.4, -138.0), Vector3(20.2, 21.2, -156.0),
		Vector3(-22.0, 24.0, -172.0), Vector3(3.8, 23.3, -194.0),
	]
	for point in star_points:
		var star := _make_box(Vector3(0.095, 0.095, 0.055), _star_material)
		star.position = point
		parent.add_child(star)


func _make_segment(index: int) -> Node3D:
	var segment := Node3D.new()
	segment.name = "DressingSegment_%02d" % index
	segment.position.z = -float(index) * segment_length
	_create_road_deck(segment, index)
	_create_lane_rhythm(segment, index)
	_create_side_landscape(segment, index)
	if index % 4 == 2:
		_create_midground_landmark(segment, index)
	var pulse := OmniLight3D.new()
	pulse.name = "Pulse"
	pulse.light_color = _pink if index % 2 == 0 else _cyan
	pulse.light_energy = 0.18 if reduced_flash else 0.36
	pulse.omni_range = 4.2
	pulse.position = Vector3(0.0, 0.65, -segment_length * 0.32)
	segment.add_child(pulse)
	return segment


func _create_road_deck(segment: Node3D, index: int) -> void:
	var road_half_width := lane_width * 1.5 + ROAD_MARGIN
	var foundation := _make_box(Vector3(road_half_width * 2.0, 0.32, segment_length - 0.06), _foundation_material)
	foundation.position = Vector3(0.0, DECK_Y, 0.0)
	segment.add_child(foundation)
	# Three subtly distinct road beds make lane placement readable without adding
	# a bright pattern under the gate silhouettes.
	for lane in [-1, 0, 1]:
		var bed := _make_box(Vector3(lane_width - 0.13, 0.045, segment_length - 0.22), _lane_materials[lane + 1])
		bed.position = Vector3(float(lane) * lane_width, DECK_Y + 0.182, 0.0)
		segment.add_child(bed)
		# Low, metallic inset rails give each lane a layered manufactured surface.
		# They remain nearly black at a glance, avoiding a second set of lane cues.
		# Alternate the secondary inlay modules. The foreground retains its premium
		# rhythm while far segments avoid hundreds of sub-pixel draw calls.
		if index % 2 == 0:
			for offset in [-0.78, 0.78]:
				var inset := _make_box(Vector3(0.028, 0.012, segment_length - 0.42), _road_inlay_material)
				inset.position = Vector3(float(lane) * lane_width + offset, DECK_Y + 0.212, 0.0)
				segment.add_child(inset)
			var core_panel := _make_box(Vector3(0.34, 0.015, segment_length * 0.40), _road_panel_material)
			core_panel.position = Vector3(float(lane) * lane_width, DECK_Y + 0.214, 0.0)
			segment.add_child(core_panel)
	# Repeating deck seams create scale and motion even when the player is still.
	for z in [-segment_length * 0.48, 0.0, segment_length * 0.48]:
		var seam := _make_box(Vector3(road_half_width * 2.0 - 0.28, 0.026, 0.055), _divider_material)
		seam.position = Vector3(0.0, DECK_Y + 0.215, z)
		segment.add_child(seam)


func _create_lane_rhythm(segment: Node3D, index: int) -> void:
	var outer_edge := lane_width * 1.5 + ROAD_MARGIN - 0.16
	# Separators are deliberately dimmer than gate frames, so they guide eye
	# movement rather than masquerading as a choice prompt.
	for x in [-lane_width * 0.5, lane_width * 0.5]:
		var divider := _make_box(Vector3(0.055, 0.038, segment_length - 0.18), _divider_material)
		divider.position = Vector3(x, DECK_Y + 0.225, 0.0)
		segment.add_child(divider)
	for side in [-1.0, 1.0]:
		var edge := _make_box(Vector3(0.10, 0.078, segment_length - 0.12), _edge_material)
		edge.position = Vector3(side * outer_edge, DECK_Y + 0.25, 0.0)
		segment.add_child(edge)
		var shoulder := _make_box(Vector3(0.52, 0.105, segment_length - 0.12), _shoulder_material)
		shoulder.position = Vector3(side * (outer_edge + 0.34), DECK_Y + 0.105, 0.0)
		segment.add_child(shoulder)
		# Staggered shoulder plates make the edge feel engineered rather than a
		# single flat strip. Their cool reflection is intentionally sub-gate.
		if index % 2 == 0:
			for plate_index in 2:
				var plate := _make_box(Vector3(0.44, 0.018, 1.35), _road_panel_material)
				plate.position = Vector3(side * (outer_edge + 0.34), DECK_Y + 0.167, -2.18 + plate_index * 4.3)
				segment.add_child(plate)
				var plate_line := _make_box(Vector3(0.34, 0.014, 0.032), _road_inlay_material)
				plate_line.position = plate.position + Vector3(0.0, 0.018, -0.55)
				segment.add_child(plate_line)
	# Offset chevrons travel under the player's peripheral vision. They are all
	# on the deck plane, leaving the middle-height gate decision silhouettes open.
	for marker_index in 3:
		var z := -3.55 + float(marker_index) * 3.35
		for side in [-1.0, 1.0]:
			var marker := _make_box(Vector3(0.56, 0.032, 0.22), _marker_material)
			marker.position = Vector3(side * (outer_edge - 0.42), DECK_Y + 0.245, z)
			marker.rotation.y = side * (0.22 if index % 2 == 0 else -0.22)
			segment.add_child(marker)


func _create_side_landscape(segment: Node3D, index: int) -> void:
	var outer_edge := lane_width * 1.5 + ROAD_MARGIN
	for side in [-1.0, 1.0]:
		# Guardrail rhythm frames the track but has a deliberately low profile.
		for z in [-2.5, 2.5]:
			var post := _make_box(Vector3(0.11, 0.78, 0.11), _architecture_accent_material)
			post.position = Vector3(side * (outer_edge + 0.72), 0.05, z)
			segment.add_child(post)
		var rail := _make_box(Vector3(0.09, 0.10, segment_length - 0.55), _architecture_accent_material)
		rail.position = Vector3(side * (outer_edge + 0.72), 0.38, 0.0)
		segment.add_child(rail)
		if (index + (0 if side < 0.0 else 1)) % 3 == 0:
			_create_city_pylon(segment, side, index)


func _create_midground_landmark(segment: Node3D, index: int) -> void:
	# A side-only arch reads as a piece of infrastructure in the midground; it
	# never crosses the lane/gate aperture space.
	var outer_edge := lane_width * 1.5 + ROAD_MARGIN
	for side in [-1.0, 1.0]:
		var support := _make_box(Vector3(0.36, 3.2, 0.48), _architecture_material)
		support.position = Vector3(side * (outer_edge + 2.15), 1.22, -1.4)
		segment.add_child(support)
		var cap := _make_box(Vector3(1.7, 0.16, 0.36), _architecture_accent_material)
		cap.position = Vector3(side * (outer_edge + 1.43), 2.65, -1.4)
		segment.add_child(cap)
		var beacon := _make_box(Vector3(0.18, 0.18, 0.20), _edge_material if (index + int(side)) % 2 == 0 else _architecture_accent_material)
		beacon.position = Vector3(side * (outer_edge + 2.15), 2.83, -1.4)
		segment.add_child(beacon)


func _create_city_pylon(segment: Node3D, side: float, index: int) -> void:
	var pylon := MeshInstance3D.new()
	pylon.name = "SidePylon"
	var prism := BoxMesh.new()
	var height := 2.2 + _rng.randf() * 4.6
	prism.size = Vector3(0.52 + _rng.randf() * 0.38, height, 0.58 + _rng.randf() * 0.45)
	pylon.mesh = prism
	pylon.position = Vector3(side * (lane_width * 2.55 + _rng.randf() * 1.1), height * 0.5 - 0.24, _rng.randf_range(-3.7, 3.7))
	pylon.material_override = _architecture_material
	segment.add_child(pylon)
	var crown := _make_box(Vector3(0.20, 0.16, 0.20), _architecture_accent_material if index % 2 == 0 else _edge_material)
	crown.position = pylon.position + Vector3(0.0, height * 0.5 + 0.06, 0.0)
	segment.add_child(crown)


func _make_box(size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	return node


func _dark_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.60)
	material.metallic = 0.36
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
