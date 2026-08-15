class_name ProfileStore
extends RefCounted

const SAVE_PATH := "user://shapeshift_profile.json"

var high_score: int = 0
var music_volume: float = 0.72
var sfx_volume: float = 0.82
var muted: bool = false
var reduced_motion: bool = false
var reduced_flash: bool = false
var quality: int = 2

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	high_score = maxi(0, int(data.get("high_score", 0)))
	music_volume = clampf(float(data.get("music_volume", 0.72)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.82)), 0.0, 1.0)
	muted = bool(data.get("muted", false))
	reduced_motion = bool(data.get("reduced_motion", false))
	reduced_flash = bool(data.get("reduced_flash", false))
	quality = clampi(int(data.get("quality", 2)), 0, 2)

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var data := {
		"high_score": high_score,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"muted": muted,
		"reduced_motion": reduced_motion,
		"reduced_flash": reduced_flash,
		"quality": quality,
	}
	file.store_string(JSON.stringify(data, "\t"))

func register_score(value: int) -> bool:
	if value <= high_score:
		return false
	high_score = value
	save_profile()
	return true
