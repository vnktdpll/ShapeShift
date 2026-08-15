extends SceneTree

## Offline, deterministic evidence capture for the in-engine audio score.
## Run: Godot --headless --path . --script res://tools/audio_evidence.gd

const OUT_DIR := "res://docs/evidence"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var audio := ReactiveAudioEngine.new()
	root.add_child(audio)
	var results: Array[Dictionary] = []
	results.append(audio.render_evidence_wav(ProjectSettings.globalize_path(OUT_DIR + "/audio-low-drift.wav"), "low", 7.0))
	results.append(audio.render_evidence_wav(ProjectSettings.globalize_path(OUT_DIR + "/audio-mid-drive.wav"), "mid", 7.0))
	results.append(audio.render_evidence_wav(ProjectSettings.globalize_path(OUT_DIR + "/audio-high-apex.wav"), "high", 7.0))
	results.append(audio.render_evidence_wav(ProjectSettings.globalize_path(OUT_DIR + "/audio-fail-restart.wav"), "fail_restart", 6.0))
	for result in results:
		assert(not result.has("error"))
		assert(float(result["peak_dbfs"]) <= -1.0)
		assert(float(result["rms_dbfs"]) < -8.0)
		assert(float(result["stereo_difference_rms"]) > 0.004)
	var report := {
		"renderer": "ReactiveAudioEngine deterministic 16-bit stereo PCM",
		"sample_rate": 44100,
		"bpm": 136,
		"sections": ["0 Drift: sparse broken-beat / bass / wide pad", "1 Drive: stabs and pulse", "2 Apex: 16th hats, arpeggio and ride"],
		"events": ["lane", "morph cube/pyramid/sphere", "perfect", "milestone", "near miss", "crash", "menu", "restart"],
		"peak_limit_dbfs": -1.0,
		"captures": results,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR + "/audio-metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	audio.shutdown_audio()
	audio.queue_free()
	await process_frame
	await process_frame
	# Give AudioStreamGenerator's mixer thread one safety buffer to release.
	await create_timer(0.25).timeout
	print("AUDIO_EVIDENCE_PASS ", JSON.stringify(results))
	quit(0)
