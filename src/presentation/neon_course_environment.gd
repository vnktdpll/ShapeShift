class_name NeonCourseEnvironment
extends Node3D

## Runtime-only course dressing.  This is deliberately separate from the
## deterministic gate course: the road gives the runner a strong sense of
## velocity without becoming another source of gameplay information.

const DEFAULT_CITY_PROFILE: NeonCityProfile = preload("res://assets/environment/neon_city_profile.tres")

@export var city_profile: NeonCityProfile = DEFAULT_CITY_PROFILE
@export_range(8, 48, 1) var segment_count: int = 8
@export_range(5.0, 24.0, 0.5) var segment_length: float = 10.0
@export_range(2.0, 6.0, 0.25) var lane_width: float = 3.25
@export var seed: int = 813
@export var reduced_flash: bool = false

const DECK_Y := -0.38
const ROAD_MARGIN := 0.78

var _segments: Array[Node3D] = []
var _city_scroll_nodes: Array[Node3D] = []
var _mid_city_scroll_nodes: Array[Node3D] = []
var _far_city_scroll_nodes: Array[Node3D] = []
var _course_root: Node3D
var _course_batch_root: Node3D
var _course_batch_groups: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _scroll_speed: float = 0.0
var _cyan := Color("2ae8ff")
var _pink := Color("ff3cad")
var _violet := Color("814cff")
var _amber := Color("ffbd45")

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
var _sky_accent_material: StandardMaterial3D
var _star_material: StandardMaterial3D
var _warm_marker_material: StandardMaterial3D
var _city_near_material: StandardMaterial3D
var _city_colored_material: StandardMaterial3D
var _atmosphere_particles: GPUParticles3D
var _city_wrap_count: int = 0
var _last_city_wrap_count: int = 0
var _mid_city_wrap_count: int = 0
var _far_city_wrap_count: int = 0
var _last_mid_city_wrap_count: int = 0
var _last_far_city_wrap_count: int = 0
var _bounded_environment_node_count: int = 0
var _close_window_pane_count: int = 0
var _mid_window_pane_count: int = 0
var _far_window_pane_count: int = 0
var _mid_far_articulation_count: int = 0
var _city_building_footprints: Array[Dictionary] = []

const MIN_BUILDING_FOOTPRINT_CLEARANCE := 0.18
# Lateral zoning keeps whole buildings—not just their centre points—out of one
# another. Each tier starts beyond the maximum outer edge of the tier before it;
# the progressively wider bands still project as a dense canyon at their greater
# depth without stacking grey masses through the closer silhouettes.


func _ready() -> void:
	build()


func _process(delta: float) -> void:
	if _scroll_speed > 0.0:
		advance(_scroll_speed * delta)


func build() -> void:
	if city_profile == null:
		city_profile = DEFAULT_CITY_PROFILE
	if is_instance_valid(_course_root):
		_course_root.queue_free()
	_segments.clear()
	_city_scroll_nodes.clear()
	_mid_city_scroll_nodes.clear()
	_far_city_scroll_nodes.clear()
	_city_wrap_count = 0
	_last_city_wrap_count = 0
	_mid_city_wrap_count = 0
	_far_city_wrap_count = 0
	_last_mid_city_wrap_count = 0
	_last_far_city_wrap_count = 0
	_close_window_pane_count = 0
	_mid_window_pane_count = 0
	_far_window_pane_count = 0
	_mid_far_articulation_count = 0
	_city_building_footprints.clear()
	_course_batch_groups.clear()
	_course_root = Node3D.new()
	_course_root.name = "ReactiveCourseDressing"
	add_child(_course_root)
	_course_batch_root = Node3D.new()
	_course_batch_root.name = "BatchedCoursePrimitives"
	_course_root.add_child(_course_batch_root)
	_rng.seed = seed
	_configure_world()
	_build_material_palette()
	_create_key_light()
	_create_sky_composition()
	for index in segment_count:
		var segment := _make_segment(index)
		_course_root.add_child(segment)
		_segments.append(segment)
	_flush_course_batches()
	_bounded_environment_node_count = _descendant_count(_course_root)


## Recycles visual dressing behind the runner. Call from the game's track tick.
func advance(distance: float) -> void:
	var refresh_course_batches := false
	_course_batch_root.position.z += distance
	for segment in _segments:
		if segment.position.z + _course_batch_root.position.z > segment_length * 1.5:
			segment.position.z -= float(segment_count) * segment_length
			refresh_course_batches = true
	# Keep course transforms numerically compact on endless runs. The common root
	# provides the per-frame motion; repeated primitive transforms are touched only
	# when one segment recycles, never every frame.
	var loop_length := float(segment_count) * segment_length
	if _course_batch_root.position.z >= loop_length:
		_course_batch_root.position.z -= loop_length
		for segment in _segments:
			segment.position.z += loop_length
		refresh_course_batches = true
	if refresh_course_batches:
		_refresh_course_batches()
	# Independently recycled facade chunks use the course's forward motion with a
	# small depth-parallax reduction. Only a single chunk crosses the rear/front
	# boundary at a time; its buildings, emissive fixtures and optional real lamp
	# remain one transform hierarchy. No runtime nodes or particles are created.
	_last_city_wrap_count = _advance_city_layer(_city_scroll_nodes, distance * city_profile.close_scroll_multiplier, city_profile.close_front_z, city_profile.close_chunk_spacing * city_profile.close_chunk_count)
	_last_mid_city_wrap_count = _advance_city_layer(_mid_city_scroll_nodes, distance * city_profile.mid_scroll_multiplier, city_profile.mid_front_z, city_profile.mid_chunk_spacing * city_profile.mid_chunk_count)
	_last_far_city_wrap_count = _advance_city_layer(_far_city_scroll_nodes, distance * city_profile.far_scroll_multiplier, city_profile.far_front_z, city_profile.far_chunk_spacing * city_profile.far_chunk_count)
	_city_wrap_count += _last_city_wrap_count
	_mid_city_wrap_count += _last_mid_city_wrap_count
	_far_city_wrap_count += _last_far_city_wrap_count


func _advance_city_layer(nodes: Array[Node3D], layer_distance: float, front_z: float, loop_length: float) -> int:
	var wraps := 0
	for chunk in nodes:
		chunk.position.z += layer_distance
		if chunk.position.z > front_z:
			chunk.position.z -= loop_length
			wraps += 1
	return wraps


func set_scroll_speed(speed: float) -> void:
	_scroll_speed = maxf(0.0, speed)


func set_reduced_flash(enabled: bool) -> void:
	reduced_flash = enabled
	if is_instance_valid(_atmosphere_particles):
		_atmosphere_particles.amount_ratio = 0.35 if reduced_flash else 1.0


func real_city_light_count() -> int:
	if not is_instance_valid(_course_root):
		return 0
	return _course_root.find_children("BoundedCityLight*", "OmniLight3D", true, false).size()


func atmosphere_particle_count() -> int:
	return _atmosphere_particles.amount if is_instance_valid(_atmosphere_particles) else 0


func atmosphere_amount_ratio() -> float:
	return _atmosphere_particles.amount_ratio if is_instance_valid(_atmosphere_particles) else 0.0


func city_scroll_root_count() -> int:
	return _city_scroll_nodes.size()


func city_scroll_sample_z() -> float:
	return _city_scroll_nodes[0].position.z if not _city_scroll_nodes.is_empty() else 0.0


func city_scroll_wrap_count() -> int:
	return _city_wrap_count


func city_scroll_last_wrap_count() -> int:
	return _last_city_wrap_count


func city_scroll_spacing_error() -> float:
	return _city_layer_spacing_error(_city_scroll_nodes, city_profile.close_chunk_spacing * city_profile.close_chunk_count, city_profile.close_chunk_spacing)


func mid_city_scroll_root_count() -> int:
	return _mid_city_scroll_nodes.size()


func far_city_scroll_root_count() -> int:
	return _far_city_scroll_nodes.size()


func mid_city_scroll_sample_z() -> float:
	return _mid_city_scroll_nodes[0].position.z if not _mid_city_scroll_nodes.is_empty() else 0.0


func far_city_scroll_sample_z() -> float:
	return _far_city_scroll_nodes[0].position.z if not _far_city_scroll_nodes.is_empty() else 0.0


func mid_city_scroll_spacing_error() -> float:
	return _city_layer_spacing_error(_mid_city_scroll_nodes, city_profile.mid_chunk_spacing * city_profile.mid_chunk_count, city_profile.mid_chunk_spacing)


func far_city_scroll_spacing_error() -> float:
	return _city_layer_spacing_error(_far_city_scroll_nodes, city_profile.far_chunk_spacing * city_profile.far_chunk_count, city_profile.far_chunk_spacing)


func last_mid_city_wrap_count() -> int:
	return _last_mid_city_wrap_count


func last_far_city_wrap_count() -> int:
	return _last_far_city_wrap_count


func _city_layer_spacing_error(nodes: Array[Node3D], loop_length: float, spacing: float) -> float:
	if nodes.size() < 2:
		return 0.0
	var worst_error := 0.0
	for current in nodes:
		var next_gap := loop_length
		for candidate in nodes:
			if candidate == current:
				continue
			var gap := candidate.position.z - current.position.z
			if gap <= 0.0:
				gap += loop_length
			next_gap = minf(next_gap, gap)
		worst_error = maxf(worst_error, absf(next_gap - spacing))
	return worst_error


func bounded_environment_node_count() -> int:
	return _bounded_environment_node_count


## Public, deterministic presentation instrumentation. These counts describe
## preallocated façade modules rather than renderer-dependent visibility, so the
## runtime smoke can guard recognizable windows and articulated depth tiers.
func close_window_pane_count() -> int:
	return _close_window_pane_count


func mid_window_pane_count() -> int:
	return _mid_window_pane_count


func far_window_pane_count() -> int:
	return _far_window_pane_count


func mid_far_articulation_count() -> int:
	return _mid_far_articulation_count


func minimum_window_pane_height() -> float:
	return minf(city_profile.close_window_height, minf(city_profile.mid_window_height, city_profile.far_window_height))


func city_building_footprint_count() -> int:
	return _city_building_footprints.size()


func city_building_footprint_overlap_count() -> int:
	var overlaps := 0
	for first_index in _city_building_footprints.size():
		var first: Rect2 = _city_building_footprints[first_index].rect
		for second_index in range(first_index + 1, _city_building_footprints.size()):
			var second: Rect2 = _city_building_footprints[second_index].rect
			if _footprint_clearance(first, second) < 0.0:
				overlaps += 1
	return overlaps


func minimum_city_building_footprint_clearance() -> float:
	var minimum_clearance := INF
	for first_index in _city_building_footprints.size():
		var first: Rect2 = _city_building_footprints[first_index].rect
		for second_index in range(first_index + 1, _city_building_footprints.size()):
			var second: Rect2 = _city_building_footprints[second_index].rect
			minimum_clearance = minf(minimum_clearance, _footprint_clearance(first, second))
	return 0.0 if is_inf(minimum_clearance) else minimum_clearance


func minimum_cross_tier_lateral_gap() -> float:
	var minimum_gap := INF
	for first_index in _city_building_footprints.size():
		var first := _city_building_footprints[first_index]
		for second_index in range(first_index + 1, _city_building_footprints.size()):
			var second := _city_building_footprints[second_index]
			if first.side != second.side or first.layer == second.layer:
				continue
			var first_rect: Rect2 = first.rect
			var second_rect: Rect2 = second.rect
			minimum_gap = minf(minimum_gap, _axis_clearance(first_rect.position.x, first_rect.end.x, second_rect.position.x, second_rect.end.x))
	return 0.0 if is_inf(minimum_gap) else minimum_gap


func minimum_building_footprint_clearance_required() -> float:
	return MIN_BUILDING_FOOTPRINT_CLEARANCE


func _record_building_footprint(layer: StringName, side: float, center: Vector2, size: Vector2) -> void:
	_city_building_footprints.append({
		"layer": layer,
		"side": -1 if side < 0.0 else 1,
		"rect": Rect2(center - size * 0.5, size),
	})


func _footprint_clearance(first: Rect2, second: Rect2) -> float:
	var x_clearance := _axis_clearance(first.position.x, first.end.x, second.position.x, second.end.x)
	var z_clearance := _axis_clearance(first.position.y, first.end.y, second.position.y, second.end.y)
	# Axis-aligned footprints are disjoint when either axis has non-negative
	# clearance. The larger axis gap is the actual separating corridor; if both
	# are negative the result reports penetration rather than hiding the overlap.
	return maxf(x_clearance, z_clearance)


func _axis_clearance(first_min: float, first_max: float, second_min: float, second_max: float) -> float:
	if first_max <= second_min:
		return second_min - first_max
	if second_max <= first_min:
		return first_min - second_max
	return -minf(first_max, second_max) + maxf(first_min, second_min)


func _descendant_count(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		count += 1 + _descendant_count(child)
	return count


func _configure_world() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null:
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"
		add_child(world_environment)
	var environment := Environment.new()
	# A near-black indigo void lets the geometric course own the hierarchy. The
	# slightly lighter horizon gives the distant landmark a stage without turning
	# the whole sky into a bright competing field.
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("02030e")
	sky_material.sky_horizon_color = Color("17365f")
	# Keep the ground half close to the horizon hue: it reads as haze rather than
	# a hard graphic horizon line behind the physical course.
	sky_material.ground_bottom_color = Color("050a1c")
	sky_material.ground_horizon_color = Color("17365f")
	sky_material.sky_curve = 0.58
	sky_material.ground_curve = 0.72
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("172651")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.96
	environment.glow_enabled = true
	# Bloom should soften edge lights, not turn the gate silhouette into a blob.
	environment.glow_intensity = 0.30
	environment.glow_strength = 0.42
	environment.fog_enabled = true
	environment.fog_light_color = Color("17365f")
	environment.fog_light_energy = 0.40
	environment.fog_density = 0.0065
	environment.fog_aerial_perspective = 0.60
	environment.fog_sky_affect = 0.70
	world_environment.environment = environment


func _build_material_palette() -> void:
	# Shared materials keep the recycled course inexpensive, with only a small,
	# stable palette for the renderer to manage.
	_foundation_material = _dark_material(Color("071025"), 0.42, 0.62)
	_lane_materials = [
		_dark_material(Color("0a1b38"), 0.46, 0.55),
		_dark_material(Color("102042"), 0.48, 0.51),
		_dark_material(Color("0a1b38"), 0.46, 0.55),
	]
	_edge_material = _emissive_material(_cyan, 1.05)
	_divider_material = _emissive_material(Color("3696da"), 0.32)
	_marker_material = _emissive_material(Color("59eeff"), 0.62)
	_shoulder_material = _dark_material(Color("0a1731"), 0.40, 0.64)
	_architecture_material = _dark_material(Color("162d5f"), 0.36, 0.66)
	_architecture_accent_material = _emissive_material(_violet, 0.52)
	_road_inlay_material = _emissive_material(Color("315a98"), 0.13)
	_road_panel_material = _dark_material(Color("0c1a35"), 0.44, 0.60)
	# Cobalt infrastructure stays clearly below the warm gate energy, but is
	# bright enough to read as deliberate architecture on an ordinary display.
	_sky_accent_material = _emissive_material(Color("5f94e8"), 0.48)
	_star_material = _emissive_material(Color("9bdfff"), 0.54)
	_warm_marker_material = _emissive_material(_amber, 0.46)
	# The city is rendered from a handful of shared materials and MultiMeshes.
	# Its values stay below the interactive cyan/pink palette, so the richer
	# silhouette never steals the runner's decision cone.
	_city_near_material = _dark_material(Color("09132d"), 0.48, 0.52)
	# Mid/far bodies and panes share one vertex-colored material. Per-instance
	# color preserves the window contrast while keeping each moving depth chunk
	# to one draw instead of doubling the background draw-call budget.
	_city_colored_material = StandardMaterial3D.new()
	_city_colored_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_city_colored_material.albedo_color = Color.WHITE
	_city_colored_material.vertex_color_use_as_albedo = true


func _create_key_light() -> void:
	# Global illumination may remain fixed because it has no visible architectural
	# transform. Every visible building is owned by a recycled city chunk.
	var key := DirectionalLight3D.new()
	key.light_color = Color("6c84ff")
	key.light_energy = 0.62
	key.rotation_degrees = Vector3(-42.0, -18.0, 0.0)
	_course_root.add_child(key)


func _create_sky_composition() -> void:
	# All city geometry below is depth-scaled motion. Only atmosphere and tiny sky
	# points remain world-stable; no building or attached city structure does.
	var sky_root := Node3D.new()
	sky_root.name = "SkyInfrastructure"
	_course_root.add_child(sky_root)
	# Every building tier is an independently recycled chunk field. Close, mid,
	# and far layers use progressively slower parallax without leaving a static
	# city plate behind the course.
	_create_close_city_chunks(sky_root)
	_create_mid_city_chunks(sky_root)
	_create_far_city_chunks(sky_root)
	_create_atmospheric_particles(sky_root)
	_create_sky_stars(sky_root)


func _create_close_city_chunks(parent: Node3D) -> void:
	for index in city_profile.close_chunk_count:
		var chunk := Node3D.new()
		chunk.name = "ScrollingFacadeChunk%02d" % index
		chunk.position.z = 2.0 - float(index) * city_profile.close_chunk_spacing
		parent.add_child(chunk)
		_city_scroll_nodes.append(chunk)
		_create_close_city_chunk(chunk, index)


func _create_mid_city_chunks(parent: Node3D) -> void:
	for index in city_profile.mid_chunk_count:
		var chunk := Node3D.new()
		chunk.name = "ScrollingMidCityChunk%02d" % index
		chunk.position.z = 8.0 - float(index) * city_profile.mid_chunk_spacing
		parent.add_child(chunk)
		_mid_city_scroll_nodes.append(chunk)
		var masses: Array[Transform3D] = []
		var windows: Array[Transform3D] = []
		for side in [-1.0, 1.0]:
			for tier in 2:
				var height := 8.4 + float((index * 3 + tier * 2) % 5) * 1.38
				var width := 2.5 + float((index + tier) % 3) * 0.58
				var tier_inner_edge := city_profile.mid_inner_edge + float(tier) * city_profile.mid_tier_pitch
				var x: float = side * (tier_inner_edge + width * 0.5)
				var local_z := -float(tier) * city_profile.mid_tier_depth_pitch
				_record_building_footprint(&"mid", side, Vector2(x, chunk.position.z + local_z), Vector2(width, 4.2))
				# A broad lower shaft, inset upper setback, crown and vertical ribs
				# create a readable tower silhouette instead of a single grey slab.
				var lower_height := height * 0.69
				var upper_height := height - lower_height
				masses.append(_box_transform(Vector3(width, lower_height, 4.2), Vector3(x, lower_height * 0.5 - 0.45, local_z)))
				masses.append(_box_transform(Vector3(width * 0.72, upper_height, 3.35), Vector3(x, lower_height - 0.45 + upper_height * 0.5, local_z - 0.18)))
				masses.append(_box_transform(Vector3(width * 0.86, 0.28, 3.62), Vector3(x, height - 0.30, local_z - 0.18)))
				for rib_side in [-1.0, 1.0]:
					masses.append(_box_transform(Vector3(0.10, lower_height * 0.88, 0.10), Vector3(x + rib_side * width * 0.38, lower_height * 0.50, local_z + 2.14)))
				# Pane modules have both visible width and height. Deterministic gaps
				# make occupancy feel inhabited without becoming a bright checkerboard.
				for row in city_profile.mid_window_rows:
					for column in city_profile.mid_window_columns:
						if (index + tier * 2 + row * 3 + column + (0 if side < 0.0 else 1)) % 5 == 0:
							continue
						var column_center := (float(city_profile.mid_window_columns) - 1.0) * 0.5
						var pane_x := x + (float(column) - column_center) * width * 0.42
						windows.append(_box_transform(Vector3(width * city_profile.mid_window_width_ratio, city_profile.mid_window_height, 0.09), Vector3(pane_x, 1.25 + float(row) * 1.34, local_z + 2.16)))
						_mid_window_pane_count += 1
				# The inner side wall is often the largest surface from the runner's
				# perspective, so it receives a second, dimmer-looking pane rhythm
				# (same low-energy material) rather than remaining a blank grey flank.
				for row in 3:
					for depth_column in 2:
						if (index + tier + row + depth_column * 2) % 4 == 0:
							continue
						var pane_z := local_z + (float(depth_column) - 0.5) * 1.72
						windows.append(_box_transform(Vector3(0.09, 0.34, 0.62), Vector3(x - side * (width * 0.5 + 0.03), 1.58 + float(row) * 1.48, pane_z)))
						_mid_window_pane_count += 1
				_mid_far_articulation_count += 5
			# A stepped connector/roof silhouette breaks repetition between the
			# two depth columns while remaining outside the central decision cone.
			# Keep the connector inside the second mid-tier footprint instead of
			# bridging through the close-city band in front of it.
			var connector_x: float = side * (city_profile.mid_inner_edge + city_profile.mid_tier_pitch + 1.2)
			masses.append(_box_transform(Vector3(5.2, 0.46, 2.8), Vector3(connector_x, 5.4 + float(index % 3) * 0.58, -6.0)))
			masses.append(_box_transform(Vector3(2.3, 0.34, 2.2), Vector3(connector_x + side * 0.5, 5.78 + float(index % 3) * 0.58, -6.1)))
			_mid_far_articulation_count += 2
		_add_colored_box_multimesh(chunk, "MidCityArticulatedFacades", masses, windows, Color("172d51"), Color("477fa6"))


func _create_far_city_chunks(parent: Node3D) -> void:
	for index in city_profile.far_chunk_count:
		var chunk := Node3D.new()
		chunk.name = "ScrollingFarCityChunk%02d" % index
		chunk.position.z = 15.0 - float(index) * city_profile.far_chunk_spacing
		parent.add_child(chunk)
		_far_city_scroll_nodes.append(chunk)
		var masses: Array[Transform3D] = []
		var windows: Array[Transform3D] = []
		for side in [-1.0, 1.0]:
			for tier in 3:
				var height := 11.0 + float((index * 7 + tier * 3) % 7) * 1.48
				var width := 2.8 + float((index + tier) % 3) * 0.66
				var tier_inner_edge := city_profile.far_inner_edge + float(tier) * city_profile.far_tier_pitch
				var x: float = side * (tier_inner_edge + width * 0.5)
				var local_z := -float(tier) * city_profile.far_tier_depth_pitch
				_record_building_footprint(&"far", side, Vector2(x, chunk.position.z + local_z), Vector2(width, 3.2))
				var lower_height := height * 0.72
				var upper_height := height - lower_height
				masses.append(_box_transform(Vector3(width, lower_height, 3.2), Vector3(x, lower_height * 0.5 - 0.55, local_z)))
				masses.append(_box_transform(Vector3(width * 0.67, upper_height, 2.55), Vector3(x, lower_height - 0.55 + upper_height * 0.5, local_z - 0.12)))
				var crown_width := width * (0.42 + 0.08 * float((index + tier) % 3))
				masses.append(_box_transform(Vector3(crown_width, 0.38, 2.28), Vector3(x, height - 0.28, local_z - 0.12)))
				# Short rooftop spires give the far belt a genuine skyline rhythm.
				if (index + tier) % 2 == 0:
					masses.append(_box_transform(Vector3(0.12, 1.35, 0.12), Vector3(x, height + 0.50, local_z - 0.12)))
				for row in city_profile.far_window_rows:
					for column in city_profile.far_window_columns:
						if (index * 2 + tier + row + column * 3 + (0 if side < 0.0 else 1)) % 6 <= 1:
							continue
						var column_center := (float(city_profile.far_window_columns) - 1.0) * 0.5
						var pane_x := x + (float(column) - column_center) * width * 0.40
						windows.append(_box_transform(Vector3(width * city_profile.far_window_width_ratio, city_profile.far_window_height, 0.07), Vector3(pane_x, 1.42 + float(row) * 1.65, local_z + 1.64)))
						_far_window_pane_count += 1
				for row in 4:
					for depth_column in 2:
						if (index + tier * 2 + row * 3 + depth_column) % 5 <= 1:
							continue
						var pane_z := local_z + (float(depth_column) - 0.5) * 1.18
						windows.append(_box_transform(Vector3(0.07, 0.30, 0.48), Vector3(x - side * (width * 0.5 + 0.025), 1.66 + float(row) * 1.76, pane_z)))
						_far_window_pane_count += 1
				_mid_far_articulation_count += 4 if (index + tier) % 2 == 0 else 3
		_add_colored_box_multimesh(chunk, "FarCityArticulatedFacades", masses, windows, Color("142744"), Color("355878"))


func _create_close_city_chunk(chunk: Node3D, index: int) -> void:
	# Three MultiMeshes per chunk retain close-city density at a bounded draw
	# cost: matte masses, cyan window panes, and magenta/warm
	# accents. All geometry remains outside x=5.8 so target/lane silhouettes win.
	var masses: Array[Transform3D] = []
	var cyan_details: Array[Transform3D] = []
	var magenta_details: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var height := 10.0 + float((index * 5 + (0 if side < 0.0 else 2)) % 5) * 1.55
		var width := 3.4 + float(index % 3) * 0.52
		var x: float = side * (city_profile.close_inner_edge + width * 0.5)
		_record_building_footprint(&"close", side, Vector2(x, chunk.position.z), Vector2(width, 6.0))
		masses.append(_box_transform(Vector3(width, height, 6.0), Vector3(x, height * 0.5 - 0.58, 0.0)))
		# Side cantilever and a compact abstract sign enrich the near silhouette
		# without spanning the central gameplay cone.
		masses.append(_box_transform(Vector3(4.2, 0.32, 3.4), Vector3(side * (city_profile.close_inner_edge + 0.1 + float(index % 2) * 0.5), 8.1 + float(index % 2) * 1.5, -3.5)))
		masses.append(_box_transform(Vector3(width * 0.58, 1.42, 0.13), Vector3(x - side * width * 0.08, 5.0 + float(index % 2) * 1.45, 3.08)))
		for row in city_profile.close_window_rows:
			for column in city_profile.close_window_columns:
				if (index * 2 + row * 3 + column + (0 if side < 0.0 else 1)) % 5 == 0:
					continue
				var column_center := (float(city_profile.close_window_columns) - 1.0) * 0.5
				var pane_x := x + (float(column) - column_center) * width * 0.25
				cyan_details.append(_box_transform(Vector3(width * city_profile.close_window_width_ratio, city_profile.close_window_height, 0.08), Vector3(pane_x, 1.25 + float(row) * 1.28, 3.05)))
				_close_window_pane_count += 1
		for row in 5:
			for depth_column in 3:
				if (index + row * 2 + depth_column + (0 if side < 0.0 else 1)) % 5 <= 1:
					continue
				var pane_z := (float(depth_column) - 1.0) * 1.28
				cyan_details.append(_box_transform(Vector3(0.08, 0.40, 0.64), Vector3(x - side * (width * 0.5 + 0.03), 1.52 + float(row) * 1.38, pane_z)))
				_close_window_pane_count += 1
		# Compact, filled sign panels replace the former edge-to-edge neon lines.
		magenta_details.append(_box_transform(Vector3(width * 0.30, 1.05, 0.10), Vector3(x - side * width * 0.25, 5.10 + float(index % 2) * 1.20, 3.07)))
		magenta_details.append(_box_transform(Vector3(1.58, 0.44, 0.13), Vector3(side * (city_profile.close_inner_edge - 0.18 + float(index % 2) * 0.5), 7.89 + float(index % 2) * 1.5, -1.78)))
	# Four of the five chunks carry one complete streetlamp assembly. The light is
	# a child of the same chunk as its mast/emitter, preserving exact coherence.
	if index < city_profile.real_light_count:
		var side := -1.0 if index % 2 == 0 else 1.0
		var lamp_x := side * 6.35
		masses.append(_box_transform(Vector3(0.15, 3.45, 0.15), Vector3(lamp_x, 1.38, 0.0)))
		masses.append(_box_transform(Vector3(1.05, 0.12, 0.15), Vector3(lamp_x - side * 0.46, 3.04, 0.0)))
		var bulb_position := Vector3(lamp_x - side * 0.91, 2.91, 0.0)
		var bulb_details := cyan_details if index % 2 == 0 else magenta_details
		bulb_details.append(_box_transform(Vector3(0.32, 0.10, 0.42), bulb_position))
		var light := OmniLight3D.new()
		light.name = "BoundedCityLight%02d" % index
		light.position = bulb_position + Vector3(0.0, -0.12, 0.0)
		light.light_color = Color("48dfff") if index % 2 == 0 else Color("ff5fc7")
		light.light_energy = 1.42
		light.omni_range = 6.2
		light.shadow_enabled = false
		chunk.add_child(light)
	_add_box_multimesh(chunk, "FacadeMasses", masses, _city_near_material)
	# Both detail colors share a vertex-colored MultiMesh. This preserves every
	# pane/sign and its palette while removing one background draw per close chunk.
	# The profile's emission control maps to restrained unshaded RGB intensity.
	var profile_brightness := clampf(city_profile.window_emission_strength / 0.50, 0.0, 2.0)
	_add_colored_box_multimesh(chunk, "FacadeColoredDetails", cyan_details, magenta_details, _scaled_rgb(Color("62bdff"), profile_brightness), _scaled_rgb(Color("d94ba9"), profile_brightness))


func _create_atmospheric_particles(parent: Node3D) -> void:
	# One GPU emitter supplies sparse rain/haze sparkle through the whole visible
	# canyon. Its fixed count and preallocated GPU simulation add atmosphere with
	# no gameplay-particle contention and no GDScript per-frame allocation.
	_atmosphere_particles = GPUParticles3D.new()
	_atmosphere_particles.name = "CityAtmosphere"
	_atmosphere_particles.amount = city_profile.atmosphere_particle_count
	_atmosphere_particles.amount_ratio = 0.35 if reduced_flash else 1.0
	_atmosphere_particles.lifetime = 7.0
	_atmosphere_particles.preprocess = 7.0
	_atmosphere_particles.randomness = 0.42
	_atmosphere_particles.position = Vector3(0.0, 4.2, -33.0)
	_atmosphere_particles.visibility_aabb = AABB(Vector3(-12.0, -5.0, -48.0), Vector3(24.0, 14.0, 98.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(9.5, 5.0, 46.0)
	process_material.direction = Vector3(0.0, -1.0, 0.22)
	process_material.spread = 12.0
	process_material.initial_velocity_min = 0.48
	process_material.initial_velocity_max = 1.15
	process_material.gravity = Vector3(0.0, -0.55, 0.0)
	process_material.scale_min = 0.45
	process_material.scale_max = 1.0
	process_material.color = Color(0.48, 0.90, 1.0, 0.48)
	_atmosphere_particles.process_material = process_material
	var mote_mesh := QuadMesh.new()
	mote_mesh.size = Vector2(0.025, 0.24)
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.albedo_color = Color(0.42, 0.88, 1.0, 0.58)
	mote_material.emission_enabled = true
	mote_material.emission = Color("63dfff")
	mote_material.emission_energy_multiplier = 0.72
	mote_mesh.material = mote_material
	_atmosphere_particles.draw_pass_1 = mote_mesh
	parent.add_child(_atmosphere_particles)


func _box_transform(size: Vector3, position: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(size), position)


func _scaled_rgb(color: Color, multiplier: float) -> Color:
	return Color(color.r * multiplier, color.g * multiplier, color.b * multiplier, color.a)


func _add_box_multimesh(parent: Node3D, node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = box
	instances.instance_count = transforms.size()
	for index in transforms.size():
		instances.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.multimesh = instances
	node.material_override = material
	parent.add_child(node)


func _add_colored_box_multimesh(parent: Node3D, node_name: String, masses: Array[Transform3D], windows: Array[Transform3D], mass_color: Color, window_color: Color) -> void:
	var instance_total := masses.size() + windows.size()
	if instance_total == 0:
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = box
	instances.instance_count = instance_total
	var instance_index := 0
	for transform in masses:
		instances.set_instance_transform(instance_index, transform)
		instances.set_instance_color(instance_index, mass_color)
		instance_index += 1
	for transform in windows:
		instances.set_instance_transform(instance_index, transform)
		instances.set_instance_color(instance_index, window_color)
		instance_index += 1
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.multimesh = instances
	node.material_override = _city_colored_material
	parent.add_child(node)


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
	var star_transforms: Array[Transform3D] = []
	for point in star_points:
		star_transforms.append(_box_transform(Vector3(0.095, 0.095, 0.055), point))
	_add_box_multimesh(parent, "SkyStars", star_transforms, _star_material)


func _make_segment(index: int) -> Node3D:
	var segment := Node3D.new()
	segment.name = "DressingSegment_%02d" % index
	segment.position.z = -float(index) * segment_length
	_create_road_deck(segment, index)
	_create_lane_rhythm(segment, index)
	_create_side_landscape(segment, index)
	if index % 3 == 1:
		_create_perimeter_frame(segment, index)
	if index % 4 == 2:
		_create_midground_landmark(segment, index)
	_register_segment_boxes(segment, index)
	return segment


## The authored course builders below stay deliberately literal: every deck,
## rail, plate, pylon and accent is described as the box it represents. Once a
## segment is authored, register boxes sharing a material in course-wide
## MultiMeshes. The common batch root supplies continuous travel and only the
## recycled segment's logical offset changes. This retains exact silhouettes,
## material palette and independent recycling while removing hundreds of tiny
## background draw calls.
func _register_segment_boxes(segment: Node3D, segment_index: int) -> void:
	var originals: Array[MeshInstance3D] = []
	for child: Node in segment.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var box := mesh_instance.mesh as BoxMesh
		var material := mesh_instance.material_override
		if box == null or material == null:
			continue
		var key := material.get_instance_id()
		if not _course_batch_groups.has(key):
			_course_batch_groups[key] = {"material": material, "local_transforms": [], "segment_indices": []}
		var group: Dictionary = _course_batch_groups[key]
		var local_transforms: Array = group["local_transforms"]
		var segment_indices: Array = group["segment_indices"]
		local_transforms.append(mesh_instance.transform * Transform3D(Basis.IDENTITY.scaled(box.size), Vector3.ZERO))
		segment_indices.append(segment_index)
		group["local_transforms"] = local_transforms
		group["segment_indices"] = segment_indices
		_course_batch_groups[key] = group
		originals.append(mesh_instance)
	for original: MeshInstance3D in originals:
		segment.remove_child(original)
		original.free()


func _flush_course_batches() -> void:
	var batch_index := 0
	for key: Variant in _course_batch_groups:
		var group: Dictionary = _course_batch_groups[key]
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = box
		instances.instance_count = (group["local_transforms"] as Array).size()
		var node := MultiMeshInstance3D.new()
		node.name = "CourseBoxBatch%02d" % batch_index
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.multimesh = instances
		node.material_override = group["material"] as Material
		_course_batch_root.add_child(node)
		group["multimesh"] = instances
		_course_batch_groups[key] = group
		batch_index += 1
	_refresh_course_batches()


func _refresh_course_batches() -> void:
	for key: Variant in _course_batch_groups:
		var group: Dictionary = _course_batch_groups[key]
		var instances := group["multimesh"] as MultiMesh
		var local_transforms: Array = group["local_transforms"]
		var segment_indices: Array = group["segment_indices"]
		for instance_index in local_transforms.size():
			var segment_index: int = int(segment_indices[instance_index])
			instances.set_instance_transform(instance_index, _segments[segment_index].transform * (local_transforms[instance_index] as Transform3D))


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
		# A recessed side ribbon gives the road a visible layered edge at speed.
		# It is low and outboard, preserving the cyan rail as the lane boundary.
		if index % 2 == 1:
			var ribbon := _make_box(Vector3(0.30, 0.18, 3.1), _architecture_material)
			ribbon.position = Vector3(side * (outer_edge + 1.14), -0.05, 0.0)
			segment.add_child(ribbon)
			var ribbon_light := _make_box(Vector3(0.035, 0.045, 2.55), _sky_accent_material if side < 0.0 else _architecture_accent_material)
			ribbon_light.position = ribbon.position + Vector3(side * -0.17, 0.11, 0.0)
			segment.add_child(ribbon_light)
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


func _create_perimeter_frame(segment: Node3D, index: int) -> void:
	# Broken trapezoid frames establish a repeatable course language while their
	# open center stays outside every lane and gate aperture.  One warm datum per
	# frame supplies rhythm without turning amber into a gameplay signal.
	var outer_edge := lane_width * 1.5 + ROAD_MARGIN
	for side in [-1.0, 1.0]:
		var upright := _make_box(Vector3(0.24, 3.25, 0.30), _architecture_material)
		upright.position = Vector3(side * (outer_edge + 2.25), 1.44, -1.3)
		upright.rotation.z = side * -0.14
		segment.add_child(upright)
		var light_rail := _make_box(Vector3(0.045, 2.15, 0.055), _architecture_accent_material)
		light_rail.position = upright.position + Vector3(side * -0.13, 0.12, -0.19)
		light_rail.rotation.z = upright.rotation.z
		segment.add_child(light_rail)
		var shoulder_arm := _make_box(Vector3(1.25, 0.18, 0.30), _architecture_material)
		shoulder_arm.position = Vector3(side * (outer_edge + 1.72), 2.95, -1.3)
		shoulder_arm.rotation.z = side * 0.20
		segment.add_child(shoulder_arm)
		var arm_trim := _make_box(Vector3(0.86, 0.035, 0.055), _edge_material if side < 0.0 else _architecture_accent_material)
		arm_trim.position = shoulder_arm.position + Vector3(side * -0.10, 0.12, -0.18)
		arm_trim.rotation.z = shoulder_arm.rotation.z
		segment.add_child(arm_trim)
	# Alternating this single low-energy beacon avoids a metronomic glow wall.
	var datum := _make_box(Vector3(0.22, 0.08, 0.14), _warm_marker_material)
	datum.position = Vector3(outer_edge + 2.25, 0.62, -1.3) if index % 2 == 0 else Vector3(-outer_edge - 2.25, 0.62, -1.3)
	segment.add_child(datum)


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
	# A single inset slit preserves the pylon's matte silhouette while preventing
	# nearby structures from collapsing into featureless black wedges at the edge
	# of the chase camera.
	var slit := _make_box(Vector3(0.035, height * 0.58, 0.038), _sky_accent_material if index % 2 == 0 else _architecture_accent_material)
	slit.position = pylon.position + Vector3(side * -0.22, 0.02, -0.31)
	segment.add_child(slit)
	# Two shallow bands make the pylon read as a matte fabricated mass rather
	# than a black edge artifact, with no extra materials or runtime animation.
	for band_y in [-height * 0.18, height * 0.18]:
		var band := _make_box(Vector3(0.42, 0.045, 0.045), _road_inlay_material if index % 2 == 0 else _architecture_accent_material)
		band.position = pylon.position + Vector3(0.0, band_y, -0.31)
		segment.add_child(band)
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


func _unshaded_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _emissive_material(color, energy)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
