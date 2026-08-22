class_name BootSplash
extends Control

## Keeps the supplied 4:3 VN Games artwork visible long enough to read on a
## normal launch, then hands off to the game without distorting the image.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const ARTWORK_PATH := "res://assets/branding/splash-flat-4x3.png"
const SOURCE_ARTWORK_PATH := "res://assets/branding/splash-4x3.png"
const NORMAL_HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.22

@export var automatic_transition := true

var _evidence_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_user_arguments()
	if not _evidence_path.is_empty():
		call_deferred("_capture_evidence")
	elif automatic_transition:
		call_deferred("_run_boot_sequence")


func _run_boot_sequence() -> void:
	if not _should_skip_hold():
		await get_tree().create_timer(NORMAL_HOLD_SECONDS, true).timeout
		var fade := create_tween()
		fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
		await fade.finished
	transition_to_main()


func transition_to_main() -> Error:
	return get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func artwork_path() -> String:
	return ARTWORK_PATH


func main_scene_path() -> String:
	return MAIN_SCENE_PATH


func _parse_user_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-splash="):
			_evidence_path = argument.trim_prefix("--evidence-splash=")


func _capture_evidence() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.request_frame_drawn_callback(func() -> void:
		var absolute := _evidence_path if _evidence_path.is_absolute_path() else ProjectSettings.globalize_path("res://" + _evidence_path)
		var error := get_viewport().get_texture().get_image().save_png(absolute)
		print("SPLASH_EVIDENCE path=%s error=%d" % [absolute, error])
		get_tree().quit(0 if error == OK else 1)
	)


func _should_skip_hold() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--autopilot" or argument == "--max-speed":
			return true
		if argument.begins_with("--benchmark=") or argument.begins_with("--restart-benchmark="):
			return true
		if argument.begins_with("--evidence=") or argument == "--evidence-results" or argument == "--evidence-controls":
			return true
	return false
