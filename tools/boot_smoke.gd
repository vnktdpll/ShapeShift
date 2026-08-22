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
	if artwork.texture.get_width() != 960 or artwork.texture.get_height() != 720:
		_fail("flat boot artwork is not the expected 960x720 4:3 asset")
		return
	if artwork.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		_fail("boot artwork is not aspect-fit centered")
		return
	var backdrop := boot.get_node_or_null("Backdrop") as ColorRect
	var expected_blue := Color("3b88b2")
	if backdrop == null or not backdrop.color.is_equal_approx(expected_blue):
		_fail("boot backdrop does not match the uniform project blue")
		return
	if ProjectSettings.get_setting("display/window/size/viewport_width") != 960 \
			or ProjectSettings.get_setting("display/window/size/viewport_height") != 720:
		_fail("project viewport is not the required 4:3 960x720")
		return
	if not ProjectSettings.get_setting("application/boot_splash/show_image", false):
		_fail("engine boot must show the logo from the first frame")
		return
	if ProjectSettings.get_setting("application/boot_splash/image") != boot.artwork_path():
		_fail("engine boot and timed scene do not share the same flat logo artwork")
		return
	if ProjectSettings.get_setting("application/boot_splash/minimum_display_time", 0) < 800:
		_fail("engine logo can disappear before an editor current-scene launch becomes visible")
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
	print("BOOT_SPLASH_PASS artwork=960x720 immediate_logo=true minimum_ms=800 viewport=960x720 flat_blue=#3b88b2 destination=res://scenes/main.tscn")
	await current_scene._graceful_quit(0)


func _fail(message: String) -> void:
	push_error("BOOT_SPLASH " + message)
	quit(1)
