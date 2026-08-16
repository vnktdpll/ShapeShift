## Verifies that the branded boot scene uses the exact project artwork with an
## aspect-preserving TextureRect and resolves into the real game scene.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/boot_splash.tscn")
	if packed == null:
		_fail("could not load branded boot scene")
		return
	var boot := packed.instantiate() as BootSplash
	if boot == null:
		_fail("boot scene root is not BootSplash")
		return
	boot.automatic_transition = false
	root.add_child(boot)
	current_scene = boot
	await process_frame
	var artwork := boot.get_node_or_null("Artwork") as TextureRect
	if artwork == null or artwork.texture == null:
		_fail("boot artwork TextureRect is missing")
		return
	if artwork.texture.resource_path != boot.artwork_path():
		_fail("boot scene does not use the supplied project artwork")
		return
	if artwork.texture.get_width() != 1448 or artwork.texture.get_height() != 1086:
		_fail("supplied boot artwork is not the expected exact 1448x1086 4:3 asset")
		return
	if artwork.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		_fail("boot artwork is not aspect-fit centered")
		return
	if not ResourceLoader.exists(boot.main_scene_path(), "PackedScene"):
		_fail("boot destination does not resolve to a PackedScene")
		return
	var error := boot.transition_to_main()
	if error != OK:
		_fail("boot transition returned error %d" % error)
		return
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/main.tscn":
		_fail("boot did not transition to the real main scene")
		return
	print("BOOT_SPLASH_PASS artwork=1448x1086 aspect=4:3 destination=res://scenes/main.tscn")
	await current_scene._graceful_quit(0)


func _fail(message: String) -> void:
	push_error("BOOT_SPLASH " + message)
	quit(1)
