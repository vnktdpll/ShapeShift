extends SceneTree

## Proves the editor-authored spark primitive and profile drive the runtime
## pool, while every quality level remains bounded and reuses the same nodes.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var director_scene := load("res://scenes/presentation/arcade_fx_director.tscn") as PackedScene
	var template_scene := load("res://scenes/presentation/spark_template.tscn") as PackedScene
	var profile := load("res://assets/fx/spark_fx_profile.tres") as SparkFxProfile
	if director_scene == null or template_scene == null or profile == null:
		push_error("FX_AUTHORING_SMOKE authored FX scene, template, or profile could not load")
		quit(1)
		return

	var authored_director := director_scene.instantiate() as ArcadeFxDirector
	root.add_child(authored_director)
	await process_frame
	if authored_director.spark_template == null or authored_director.spark_profile == null:
		push_error("FX_AUTHORING_SMOKE director scene is not resource-bound")
		quit(1)
		return
	if authored_director.particle_capacity() != 100 \
			or authored_director.quality_particle_budget() != 100 \
			or authored_director.get_node("PooledSparks").get_child_count() != 100:
		push_error("FX_AUTHORING_SMOKE authored default capacity contract changed")
		quit(1)
		return
	authored_director.queue_free()
	await process_frame

	var custom_profile := profile.duplicate(true) as SparkFxProfile
	custom_profile.pool_size = 23
	custom_profile.low_capacity = 5
	custom_profile.medium_capacity = 11
	custom_profile.high_capacity = 17
	var authored_template_root := template_scene.instantiate() as MeshInstance3D
	var template_root := MeshInstance3D.new()
	template_root.name = "EditedSparkTemplate"
	var custom_mesh := authored_template_root.mesh.duplicate(true) as SphereMesh
	custom_mesh.radius = 0.091
	custom_mesh.height = 0.19
	custom_mesh.radial_segments = 12
	custom_mesh.rings = 6
	template_root.mesh = custom_mesh
	var custom_material := authored_template_root.material_override.duplicate(true) as StandardMaterial3D
	custom_material.emission_energy_multiplier = 5.4
	template_root.material_override = custom_material
	var custom_template := PackedScene.new()
	if custom_template.pack(template_root) != OK:
		push_error("FX_AUTHORING_SMOKE could not pack edited spark template")
		quit(1)
		return
	authored_template_root.free()
	template_root.free()

	var director := ArcadeFxDirector.new()
	director.spark_profile = custom_profile
	director.spark_template = custom_template
	root.add_child(director)
	await process_frame
	var pool := director.get_node("PooledSparks") as Node3D
	if director.particle_capacity() != 23 or pool.get_child_count() != 23:
		push_error("FX_AUTHORING_SMOKE edited pool size did not drive runtime allocation")
		quit(1)
		return
	if not director.spark_mesh_dimensions().is_equal_approx(Vector2(0.091, 0.19)) \
			or director.spark_mesh_segments() != Vector2i(12, 6) \
			or not is_equal_approx(director.spark_emission_energy(), 5.4):
		push_error("FX_AUTHORING_SMOKE edited primitive/material did not reach pooled sparks: dimensions=%s segments=%s emission=%.3f" % [director.spark_mesh_dimensions(), director.spark_mesh_segments(), director.spark_emission_energy()])
		quit(1)
		return

	director.set_quality(ArcadeFxDirector.Quality.HIGH)
	director.emit_impact(Vector3.ZERO)
	if director.quality_particle_budget() != 17 or director.active_particle_count() != 17 or pool.get_child_count() != 23:
		push_error("FX_AUTHORING_SMOKE high-quality budget was not bounded or reused")
		quit(1)
		return
	director.set_quality(ArcadeFxDirector.Quality.LOW)
	director.emit_success(Vector3.ZERO)
	if director.quality_particle_budget() != 5 or director.active_particle_count() != 5 or pool.get_child_count() != 23:
		push_error("FX_AUTHORING_SMOKE low-quality budget was not bounded or reused")
		quit(1)
		return

	# Direct script construction remains a safe focused-test fallback.
	var fallback := ArcadeFxDirector.new()
	root.add_child(fallback)
	await process_frame
	if fallback.particle_capacity() != 100 \
			or fallback.spark_mesh_segments() != Vector2i(8, 4) \
			or fallback.get_node("PooledSparks").get_child_count() != 100:
		push_error("FX_AUTHORING_SMOKE direct-instantiation fallback regressed")
		quit(1)
		return

	print("FX_AUTHORING_SMOKE_PASS pool=23 high=17 low=5 radius=0.091 height=0.190 segments=12 rings=6 emission=5.4 fallback=100")
	director.queue_free()
	fallback.queue_free()
	await process_frame
	quit(0)
