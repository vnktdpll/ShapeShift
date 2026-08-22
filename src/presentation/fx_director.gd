class_name ArcadeFxDirector
extends Node3D

## Uses a small bounded pool of runtime meshes, avoiding texture assets and
## keeping GL Compatibility performance predictable.

enum Quality { LOW, MEDIUM, HIGH }

@export var quality: Quality = Quality.HIGH
@export var reduced_flash: bool = false
@export var emission_anchor: Node3D
@export_group("Spark authoring")
@export var spark_template: PackedScene
@export var spark_profile: SparkFxProfile

var _events: GameEvents
var _active: Array[Dictionary] = []
var _free_sparks: Array[MeshInstance3D] = []
var _flash: ColorRect
var _rng := RandomNumberGenerator.new()
var _last_burst_origin_local := Vector3.ZERO
var _pool_capacity: int = 0
const FALLBACK_POOL_SIZE := 100


func _ready() -> void:
	_rng.seed = 4441
	_create_screen_feedback()
	_create_spark_pool()


func bind_events(events: GameEvents) -> void:
	_events = events
	_events.gate_judged.connect(_on_gate_judged)
	_events.run_failed.connect(_on_run_failed)
	_events.shape_changed.connect(_on_shape_changed)
	_events.combo_changed.connect(_on_combo_changed)


func set_quality(next_quality: Quality) -> void:
	quality = next_quality


func set_reduced_flash(enabled: bool) -> void:
	reduced_flash = enabled


func active_particle_count() -> int:
	return _active.size()


func particle_capacity() -> int:
	return _pool_capacity


func quality_particle_budget() -> int:
	if spark_profile == null:
		return 32 if quality == Quality.LOW else (64 if quality == Quality.MEDIUM else FALLBACK_POOL_SIZE)
	return spark_profile.capacity_for_quality(quality)


## Authoring probes keep resource-to-pool behavior deterministic and testable
## without making the pool implementation itself part of the public API.
func spark_mesh_dimensions() -> Vector2:
	var mesh := _pooled_sphere_mesh()
	return Vector2(mesh.radius, mesh.height) if mesh != null else Vector2.ZERO


func spark_mesh_segments() -> Vector2i:
	var mesh := _pooled_sphere_mesh()
	return Vector2i(mesh.radial_segments, mesh.rings) if mesh != null else Vector2i.ZERO


func spark_emission_energy() -> float:
	var material := _pooled_spark_material()
	return material.emission_energy_multiplier if material != null else 0.0


func emit_lane_trail(at: Vector3, direction: float) -> void:
	if quality == Quality.LOW:
		return
	_spawn_burst(at, Color("2ae8ff"), 6 if quality == Quality.MEDIUM else 10, 0.30, direction)


## World-space variant used by GameRoot so effects remain correct if the game
## root, player, or effects director is ever transformed.
func emit_lane_trail_world(at_world: Vector3, direction: float) -> void:
	emit_lane_trail(to_local(at_world), direction)


func emit_success(at: Vector3) -> void:
	_spawn_burst(at, Color("52ffce"), 18, 0.48, 0.0)


func emit_near_miss(at: Vector3) -> void:
	_spawn_burst(at, Color("ffbd45"), 14 if quality != Quality.HIGH else 22, 0.52, 0.0)
	_flash_screen(Color(1.0, 0.65, 0.12, 0.1), 0.08)


func emit_impact(at: Vector3) -> void:
	_spawn_burst(at, Color("ff3c7d"), 22 if quality != Quality.HIGH else 36, 0.64, 0.0)
	_flash_screen(Color(1.0, 0.04, 0.24, 0.19), 0.15)


func set_emission_anchor(anchor: Node3D) -> void:
	emission_anchor = anchor


func last_burst_origin_world() -> Vector3:
	return to_global(_last_burst_origin_local)


func _process(delta: float) -> void:
	for index in range(_active.size() - 1, -1, -1):
		var entry := _active[index]
		entry["age"] = float(entry["age"]) + delta
		var life := float(entry["life"])
		var mesh := entry["mesh"] as MeshInstance3D
		mesh.position += (entry["velocity"] as Vector3) * delta
		mesh.scale = Vector3.ONE * maxf(0.04, 1.0 - float(entry["age"]) / life)
		if float(entry["age"]) >= life:
			_retire_spark(mesh)
			_active.remove_at(index)
		else:
			_active[index] = entry
	if _flash.color.a > 0.001:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 3.5)


func _spawn_burst(at: Vector3, color: Color, count: int, life: float, direction: float) -> void:
	_last_burst_origin_local = at
	if reduced_flash:
		# Accessibility mode retains the interaction cue while making it shorter
		# and markedly less dense than the default high-energy burst.
		count = mini(count, 6)
		life *= 0.72
	var limit := quality_particle_budget()
	count = mini(count, limit)
	while _active.size() + count > limit:
		var old: Dictionary = _active.pop_front()
		_retire_spark(old["mesh"] as MeshInstance3D)
	for index in count:
		if _free_sparks.is_empty():
			var oldest: Dictionary = _active.pop_front()
			_retire_spark(oldest["mesh"] as MeshInstance3D)
		var spark: MeshInstance3D = _free_sparks.pop_back()
		var material := spark.material_override as StandardMaterial3D
		material.albedo_color = color
		material.emission = color
		spark.position = at + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25))
		spark.scale = Vector3.ONE
		spark.visible = true
		var velocity := Vector3(_rng.randf_range(-3.2, 3.2) + direction * 2.4, _rng.randf_range(0.3, 4.2), _rng.randf_range(-2.4, 2.4))
		_active.append({"mesh": spark, "velocity": velocity, "age": 0.0, "life": life})


func _create_spark_pool() -> void:
	var pool_root := get_node_or_null("PooledSparks") as Node3D
	if pool_root == null:
		pool_root = Node3D.new()
		pool_root.name = "PooledSparks"
		add_child(pool_root)
	_pool_capacity = maxi(1, spark_profile.pool_size) if spark_profile != null else FALLBACK_POOL_SIZE
	for index: int in range(_pool_capacity):
		var spark := _instantiate_spark()
		spark.name = "PooledSpark%03d" % index
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.visible = false
		pool_root.add_child(spark)
		_free_sparks.append(spark)


func _instantiate_spark() -> MeshInstance3D:
	var spark: MeshInstance3D
	if spark_template != null:
		spark = spark_template.instantiate() as MeshInstance3D
	if spark == null:
		spark = MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.068
		mesh.height = 0.14
		mesh.radial_segments = 8
		mesh.rings = 4
		spark.mesh = mesh
		spark.material_override = _spark_material(Color.WHITE)
	else:
		# Burst colors are per particle. Duplicate only the authored material;
		# every pooled instance safely shares the immutable authored mesh.
		var authored_material := spark.material_override as StandardMaterial3D
		if authored_material != null:
			var instance_material := authored_material.duplicate(true) as StandardMaterial3D
			# StandardMaterial3D's engine-level duplicate can omit the energy value
			# in headless builds, so retain this authored field explicitly.
			instance_material.emission_energy_multiplier = authored_material.emission_energy_multiplier
			spark.material_override = instance_material
		else:
			spark.material_override = _spark_material(Color.WHITE)
	return spark


func _pooled_sphere_mesh() -> SphereMesh:
	if _free_sparks.is_empty() and _active.is_empty():
		return null
	var spark: MeshInstance3D = _free_sparks[0] if not _free_sparks.is_empty() else _active[0]["mesh"] as MeshInstance3D
	return spark.mesh as SphereMesh


func _pooled_spark_material() -> StandardMaterial3D:
	if _free_sparks.is_empty() and _active.is_empty():
		return null
	var spark: MeshInstance3D = _free_sparks[0] if not _free_sparks.is_empty() else _active[0]["mesh"] as MeshInstance3D
	return spark.material_override as StandardMaterial3D


func _retire_spark(spark: MeshInstance3D) -> void:
	if not is_instance_valid(spark) or _free_sparks.has(spark):
		return
	spark.visible = false
	_free_sparks.append(spark)


func _spark_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.2
	return material


func _create_screen_feedback() -> void:
	var layer := get_node_or_null("ScreenFeedback") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "ScreenFeedback"
		layer.layer = 8
		add_child(layer)
	_flash = layer.get_node_or_null("Flash") as ColorRect
	if _flash == null:
		_flash = ColorRect.new()
		_flash.name = "Flash"
		layer.add_child(_flash)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color.TRANSPARENT


func _flash_screen(color: Color, alpha: float) -> void:
	if reduced_flash or _flash == null:
		return
	_flash.color = color
	_flash.color.a = minf(0.2, alpha)


func _on_gate_judged(kind: GameEvents.JudgmentKind, _points: int) -> void:
	if not is_inside_tree():
		return
	if kind == GameEvents.JudgmentKind.PERFECT:
		emit_success(_anchor_position())
	elif kind == GameEvents.JudgmentKind.NEAR_MISS:
		emit_near_miss(_anchor_position())
	else:
		# The first miss is terminal, but its impact burst still fires immediately
		# before the results transition.
		emit_impact(_anchor_position())


func _on_run_failed(_score: int, _high_score: int) -> void:
	if not is_inside_tree():
		return
	emit_impact(_anchor_position())


func _on_shape_changed(_shape: GameEvents.ShapeKind) -> void:
	if not is_inside_tree():
		return
	_spawn_burst(_anchor_position(), Color("b67aff"), 10, 0.28, 0.0)


func _on_combo_changed(combo: int, _multiplier: int) -> void:
	if combo > 0 and combo % 10 == 0:
		_flash_screen(Color(0.1, 0.95, 1.0, 0.1), 0.09)


func _anchor_position() -> Vector3:
	if not is_instance_valid(emission_anchor):
		return Vector3.ZERO
	var anchor_world := emission_anchor.global_position
	if emission_anchor.has_method("interaction_world_position"):
		anchor_world = emission_anchor.call("interaction_world_position") as Vector3
	return to_local(anchor_world)
