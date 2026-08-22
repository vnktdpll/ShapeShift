class_name ReactiveAudioEngine
extends Node

## ShapeShift's repository-owned score and effects synthesizer.  It deliberately
## uses no samples: a small bounded voice allocator renders the same authored
## arrangement in real time and in the deterministic evidence renderer.

## Evidence remains a full-bandwidth 44.1 kHz render.  The live generator uses
## 24 kHz: plenty for this deliberately electronic score, and it halves the
## amount of main-thread synthesis work on ordinary hardware.
const SAMPLE_RATE := 44100.0
const RUNTIME_SAMPLE_RATE := 24000.0
const BPM := 136.0
const BEATS_PER_BAR := 4.0
const TAU_F := 6.28318530718
const MAX_VOICES := 30
const SAFE_PEAK := 0.86 # -1.31 dBFS before the bus safety compressor.
const ROOTS := [55.0, 65.406, 73.416, 61.735, 55.0, 65.406, 82.407, 73.416]
const ARP_RATIOS := [8.0, 10.079, 11.986, 10.079, 8.0, 11.986, 15.08, 11.986]

# Fixed-score pan laws are constants instead of per-sample trig calls.
const PAN_CENTER_L := 0.707106781
const PAN_CENTER_R := 0.707106781
const PAN_SNARE_L := 0.661311865
const PAN_SNARE_R := 0.750111070
const PAN_HAT_LEFT_L := 0.917754626
const PAN_HAT_LEFT_R := 0.397147891
const PAN_HAT_RIGHT_L := 0.397147891
const PAN_HAT_RIGHT_R := 0.917754626
const PAN_BASS_L := 0.750111070
const PAN_BASS_R := 0.661311865
const PAN_STAB_LEFT_L := 0.946085359
const PAN_STAB_LEFT_R := 0.323917418
const PAN_STAB_RIGHT_L := 0.323917418
const PAN_STAB_RIGHT_R := 0.946085359
const PAN_PULSE_L := 0.509041416
const PAN_PULSE_R := 0.860742027
const PAN_LEAD_LEFT_L := 0.868631514
const PAN_LEAD_LEFT_R := 0.495458668
const PAN_LEAD_RIGHT_L := 0.495458668
const PAN_LEAD_RIGHT_R := 0.868631514
const PAN_RIDE_L := 0.294040325
const PAN_RIDE_R := 0.955793015

@export_range(-36.0, 0.0, 0.1) var music_volume_db: float = -10.0
@export_range(-36.0, 0.0, 0.1) var effects_volume_db: float = -7.0
@export var muted: bool = false

var _events: GameEvents
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _sfx_playback: AudioStreamGeneratorPlayback
var _music_time := 0.0
var _target_intensity := 0.18
var _active_intensity := 0.18
var _pending_intensity := 0.18
var _section := 0
var _last_bar := -1
var _duck := 0.0
var _paused := false
var _voices: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:

	_rng.seed = 90210
	_create_players()
	apply_mix()


func _exit_tree() -> void:
	shutdown_audio()


func shutdown_audio() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	if is_instance_valid(_sfx_player):
		_sfx_player.stop()
		_sfx_player.stream = null
	_music_playback = null
	_sfx_playback = null
	_voices.clear()


func bind_events(events: GameEvents) -> void:
	_events = events
	_events.run_started.connect(_on_run_started)
	_events.run_restarted.connect(_on_run_restarted)
	_events.run_paused.connect(_on_run_paused)
	_events.run_failed.connect(_on_run_failed)
	_events.lane_changed.connect(_on_lane_changed)
	_events.shape_changed.connect(_on_shape_changed)
	_events.gate_judged.connect(_on_gate_judged)
	_events.combo_changed.connect(_on_combo_changed)
	_events.speed_changed.connect(_on_speed_changed)


func set_music_volume_db(value: float) -> void:
	music_volume_db = clampf(value, -36.0, 0.0)
	apply_mix()


func set_effects_volume_db(value: float) -> void:
	effects_volume_db = clampf(value, -36.0, 0.0)
	apply_mix()


func set_muted(enabled: bool) -> void:
	muted = enabled
	apply_mix()


## Menu navigation sits outside the gameplay event contract.
func play_menu_action() -> void:
	_cue_layers(520.0, 0.06, 0.055, 150.0, -0.18, 1)


func play_restart() -> void:
	_cue_layers(330.0, 0.14, 0.13, 280.0, 0.0, 3)
	_add_voice(660.0, 0.26, 0.035, -90.0, 0.38, 1, 0.075, 2)


func apply_mix() -> void:
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, music_volume_db)
		AudioServer.set_bus_mute(music_bus, muted)
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, effects_volume_db)
		AudioServer.set_bus_mute(sfx_bus, muted)


func _process(_delta: float) -> void:
	if _music_playback:
		_fill_music()
	if _sfx_playback:
		_fill_sfx()


func _create_players() -> void:
	_music_player = _generator_player(&"Music", "ProceduralMusic", get_node_or_null("ProceduralMusic") as AudioStreamPlayer)
	_sfx_player = _generator_player(&"SFX", "ProceduralSfx", get_node_or_null("ProceduralSfx") as AudioStreamPlayer)
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_sfx_playback = _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _generator_player(bus: StringName, node_name: String, authored: AudioStreamPlayer = null) -> AudioStreamPlayer:
	var player := authored if authored != null else AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus
	var stream := player.stream as AudioStreamGenerator
	if stream == null:
		stream = AudioStreamGenerator.new()
	stream.mix_rate = RUNTIME_SAMPLE_RATE
	stream.buffer_length = 0.16
	player.stream = stream
	if player.get_parent() == null:
		add_child(player)
	player.play()
	return player


func _fill_music() -> void:
	var frames: int = mini(_music_playback.get_frames_available(), 2048)
	for _frame in frames:
		_music_playback.push_frame(_music_frame(RUNTIME_SAMPLE_RATE))


func _fill_sfx() -> void:
	var frames: int = mini(_sfx_playback.get_frames_available(), 2048)
	for _frame in frames:
		_sfx_playback.push_frame(_sfx_frame(RUNTIME_SAMPLE_RATE))


## Arrangement sections are selected only when a new bar begins: Drift
## (low), Drive (mid), and Apex (high).  This preserves musical transitions
## while intensity can still react immediately at the next quantized bar.
func _music_frame(sample_rate: float = SAMPLE_RATE) -> Vector2:
	var time := _music_time
	_music_time += 1.0 / sample_rate
	var beats := time * BPM / 60.0
	var bar := int(floor(beats / BEATS_PER_BAR))
	if bar != _last_bar:
		_last_bar = bar
		_active_intensity = _pending_intensity
		_section = _section_for_intensity(_active_intensity)
	_duck = move_toward(_duck, 0.0, 0.00010)
	if _paused:
		return Vector2.ZERO

	var beat := fmod(beats, 1.0)
	var half := fmod(beats * 2.0, 1.0)
	var sixteenth := fmod(beats * 4.0, 1.0)
	var root := _root_for_bar(bar)
	var left := 0.0
	var right := 0.0
	var kick_env := _decay(beat, 0.19)
	var kick := (_sine(50.0 + 98.0 * kick_env, time) + _sine(44.0, time) * 0.42) * kick_env * 0.24
	left += kick * PAN_CENTER_L
	right += kick * PAN_CENTER_R

	# The backbeat opens up as the arrangement develops.
	if int(floor(beats)) % 2 == 1:
		var snare_env := _decay(fmod(beats + 0.5, 1.0), 0.13)
		var snare := (_noise(int(time * sample_rate) + 41) * 0.72 + _sine(185.0, time) * 0.28) * snare_env * (0.042 + _active_intensity * 0.042)
		left += snare * PAN_SNARE_L
		right += snare * PAN_SNARE_R
	var hat_divisor := 2.0 if _section == 0 else 4.0
	var hat_phase := fmod(beats * hat_divisor, 1.0)
	var hat_env := _decay(hat_phase, 0.027 if _section < 2 else 0.036)
	var hat := _noise(int(time * sample_rate) + 137) * hat_env * (0.010 + _active_intensity * 0.020)
	if int(floor(beats * hat_divisor)) % 2 == 0:
		left += hat * PAN_HAT_LEFT_L
		right += hat * PAN_HAT_LEFT_R
	else:
		left += hat * PAN_HAT_RIGHT_L
		right += hat * PAN_HAT_RIGHT_R

	var bass_gate := 0.28 + 0.72 * _decay(beat, 0.55)
	var bass := (_saw(root, time) * 0.68 + _sine(root * 0.5, time) * 0.55) * bass_gate * (0.070 + _active_intensity * 0.070)
	left += bass * PAN_BASS_L
	right += bass * PAN_BASS_R

	# Wide fifth/minor color pad: slight channel detuning makes genuine stereo.
	var chord_amp := 0.009 + _active_intensity * 0.016
	var pad_l := _sine(root * 2.0, time) + _sine(root * 2.996, time) + _sine(root * 2.378, time)
	var pad_r := _sine(root * 2.006, time + 0.004) + _sine(root * 3.004, time + 0.006) + _sine(root * 2.384, time + 0.009)
	left += pad_l * chord_amp
	right += pad_r * chord_amp

	if _section >= 1:
		var stab_env := _decay(half, 0.18)
		var stab := (_square(root * 4.0, time) * 0.46 + _sine(root * 5.99, time) * 0.54) * stab_env * 0.035
		if int(floor(beats * 2.0)) % 2 == 0:
			left += stab * PAN_STAB_LEFT_L
			right += stab * PAN_STAB_LEFT_R
		else:
			left += stab * PAN_STAB_RIGHT_L
			right += stab * PAN_STAB_RIGHT_R
		var pulse_note := root * (4.0 if int(floor(beats * 2.0)) % 4 < 2 else 5.993)
		var pulse := _triangle(pulse_note, time) * _decay(sixteenth, 0.075) * 0.026
		left += pulse * PAN_PULSE_L
		right += pulse * PAN_PULSE_R
	if _section >= 2:
		var step := int(floor(beats * 2.0)) % 8
		var lead_note: float = root * float(ARP_RATIOS[step])
		var lead := (_sine(lead_note, time) + _triangle(lead_note * 2.0, time) * 0.30) * _decay(half, 0.19) * 0.048
		if step % 2 == 0:
			left += lead * PAN_LEAD_LEFT_L
			right += lead * PAN_LEAD_LEFT_R
		else:
			left += lead * PAN_LEAD_RIGHT_L
			right += lead * PAN_LEAD_RIGHT_R
		var ride := _noise(int(time * sample_rate) + 311) * _decay(sixteenth, 0.019) * 0.018
		left += ride * PAN_RIDE_L
		right += ride * PAN_RIDE_R

	var duck_gain := 1.0 - _duck * 0.72
	return _safe_stereo(left * duck_gain, right * duck_gain, 1.28)


func _sfx_frame(sample_rate: float = SAMPLE_RATE) -> Vector2:
	var left := 0.0
	var right := 0.0
	for index in range(_voices.size() - 1, -1, -1):
		var voice := _voices[index]
		voice["time"] = float(voice["time"]) + 1.0 / sample_rate
		var age: float = voice["time"]
		var duration: float = voice["duration"]
		if age >= duration:
			_voices.remove_at(index)
			continue
		var audible_age := age - float(voice["delay"])
		if audible_age >= 0.0:
			var local_duration := maxf(0.01, duration - float(voice["delay"]))
			var env := pow(maxf(0.0, 1.0 - audible_age / local_duration), 1.75 + float(voice["layer"]) * 0.55)
			var frequency: float = voice["frequency"]
			var sweep: float = voice["sweep"]
			var wave := _voice_wave(int(voice["wave"]), frequency + sweep * (1.0 - audible_age / local_duration), audible_age, int(voice["seed"]), sample_rate)
			var value := wave * env * float(voice["amplitude"])
			left += value * float(voice["pan_left"])
			right += value * float(voice["pan_right"])
		_voices[index] = voice
	return _safe_stereo(left, right, 1.10)


func _cue_layers(frequency: float, duration: float, amplitude: float, sweep: float, pan: float, color: int) -> void:
	# Every cue gets a click/transient, pitched body, and delayed tail.  Color
	# selects waveform families, keeping the seven gameplay cues unmistakable.
	var transient_wave := 4 if color % 2 == 0 else 3
	var body_wave := 1 if color < 3 else 2
	_add_voice(frequency * 2.2, duration * 0.24, amplitude * 0.38, sweep * 1.8, pan * 0.65, transient_wave, 0.0, 0)
	_add_voice(frequency, duration, amplitude, sweep, pan, body_wave, 0.0, 1)
	_add_voice(frequency * (1.498 if color != 5 else 0.749), duration * 1.75, amplitude * 0.31, -sweep * 0.18, -pan * 0.72, 0, 0.042, 2)


func _add_voice(frequency: float, duration: float, amplitude: float, sweep: float, pan: float, wave: int, delay: float, layer: int) -> void:
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	var clamped_pan := clampf(pan, -1.0, 1.0)
	_voices.append({
		"time": 0.0, "duration": duration + delay, "frequency": frequency,
		"amplitude": amplitude, "sweep": sweep,
		"pan_left": _pan_left(clamped_pan), "pan_right": _pan_right(clamped_pan),
		"wave": wave, "delay": delay, "layer": layer, "seed": _rng.randi(),
	})


func _set_intensity(value: float) -> void:
	_target_intensity = clampf(value, 0.12, 1.0)
	_pending_intensity = _target_intensity


func _section_for_intensity(value: float) -> int:
	if value < 0.42:
		return 0
	if value < 0.74:
		return 1
	return 2


func _root_for_bar(bar: int) -> float:
	# Two four-bar phrases: D minor tension resolves to a brighter turnaround.
	return float(ROOTS[bar % ROOTS.size()])


func _decay(phase: float, length: float) -> float:
	return maxf(0.0, 1.0 - phase / length) if phase < length else 0.0


func _sine(frequency: float, time: float) -> float:
	return sin(TAU_F * frequency * time)


func _saw(frequency: float, time: float) -> float:
	return fmod(frequency * time + 0.5, 1.0) * 2.0 - 1.0


func _square(frequency: float, time: float) -> float:
	return 1.0 if sin(TAU_F * frequency * time) >= 0.0 else -1.0


func _triangle(frequency: float, time: float) -> float:
	return absf(fmod(frequency * time + 0.25, 1.0) * 4.0 - 2.0) - 1.0


func _voice_wave(kind: int, frequency: float, time: float, seed: int, sample_rate: float) -> float:
	match kind:
		1:
			return _saw(frequency, time)
		2:
			return _triangle(frequency, time)
		3:
			return _noise(int(time * sample_rate) + seed)
		4:
			return _noise(int(time * sample_rate * 1.7) + seed) * 0.82 + _square(frequency, time) * 0.18
		_:
			return _sine(frequency, time)


func _noise(index: int) -> float:
	var value := float((index * 1103515245 + 12345) & 0x7fffffff) / 1073741824.0
	return value - 1.0


func _safe_stereo(left: float, right: float, drive: float) -> Vector2:
	return Vector2(clampf(tanh(left * drive) * SAFE_PEAK, -SAFE_PEAK, SAFE_PEAK), clampf(tanh(right * drive) * SAFE_PEAK, -SAFE_PEAK, SAFE_PEAK))


func _pan_left(pan: float) -> float:
	return cos((clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25)


func _pan_right(pan: float) -> float:
	return sin((clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25)


func _on_run_started(_seed: int) -> void:
	_paused = false
	_set_intensity(0.22)
	_last_bar = -1
	_cue_layers(220.0, 0.16, 0.12, 240.0, 0.0, 1)


func _on_run_restarted(_seed: int) -> void:
	_paused = false
	_set_intensity(0.20)
	_last_bar = -1
	play_restart()


func _on_run_paused(paused: bool) -> void:
	_paused = paused
	_duck = 0.72
	_cue_layers(180.0 if paused else 260.0, 0.10, 0.07, 110.0, 0.0, 2)


func _on_run_failed(_score: int, _high_score: int) -> void:
	_set_intensity(0.14)
	_duck = 1.0
	_cue_layers(64.0, 0.48, 0.23, -52.0, 0.0, 5)
	_add_voice(43.0, 0.72, 0.12, -18.0, -0.30, 3, 0.08, 2)


func _on_lane_changed(lane: int) -> void:
	_cue_layers(410.0 + float(lane) * 24.0, 0.055, 0.060, 150.0, -0.58 if lane == 0 else 0.58, 0)


func _on_shape_changed(shape: GameEvents.ShapeKind) -> void:
	var notes := [380.0, 494.0, 604.0]
	_cue_layers(float(notes[int(shape)]), 0.105, 0.078, 310.0, 0.20 * float(int(shape) - 1), 2)


func _on_gate_judged(kind: GameEvents.JudgmentKind, _points: int) -> void:
	if kind == GameEvents.JudgmentKind.PERFECT:
		_cue_layers(660.0, 0.13, 0.12, 410.0, 0.26, 3)
		_add_voice(990.0, 0.22, 0.045, 90.0, -0.42, 0, 0.028, 2)
	elif kind == GameEvents.JudgmentKind.NEAR_MISS:
		_cue_layers(190.0, 0.19, 0.095, 620.0, -0.50, 4)
	else:
		_cue_layers(82.0, 0.26, 0.18, -34.0, 0.0, 5)


func _on_combo_changed(combo: int, multiplier: int) -> void:
	_set_intensity(0.22 + minf(0.72, float(combo) * 0.028 + float(multiplier) * 0.04))
	if combo > 0 and combo % 10 == 0:
		_cue_layers(880.0, 0.19, 0.14, 510.0, 0.0, 3)
		_add_voice(1320.0, 0.30, 0.045, 80.0, 0.48, 2, 0.050, 2)


func _on_speed_changed(_speed: float, normalized_intensity: float) -> void:
	_set_intensity(maxf(_target_intensity, 0.2 + normalized_intensity * 0.64))


## Deterministic offline capture used by tools/audio_evidence.gd. It mirrors
## runtime synthesis and writes 16-bit stereo PCM without importing assets.
func render_evidence_wav(path: String, mode: String, seconds: float = 8.0) -> Dictionary:
	var old_time := _music_time
	var old_active := _active_intensity
	var old_pending := _pending_intensity
	var old_target := _target_intensity
	var old_section := _section
	var old_bar := _last_bar
	var old_duck := _duck
	var old_paused := _paused
	var old_voices := _voices.duplicate(true)
	_music_time = 0.0
	_last_bar = -1
	_duck = 0.0
	_paused = false
	_voices.clear()
	_rng.seed = 90210
	var evidence_intensity := 0.22 if mode == "low" else (0.58 if mode == "mid" else 0.90)
	_set_intensity(evidence_intensity)
	_active_intensity = _pending_intensity
	_section = _section_for_intensity(_active_intensity)
	var frame_count := int(seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(44 + frame_count * 4)
	_write_wav_header(data, frame_count)
	var peak := 0.0
	var energy := 0.0
	var difference_energy := 0.0
	var channel_product := 0.0
	for frame in frame_count:
		_trigger_evidence_events(frame, mode)
		var mixed := _music_frame() + _sfx_frame()
		mixed = _safe_stereo(mixed.x, mixed.y, 0.94)
		peak = maxf(peak, maxf(absf(mixed.x), absf(mixed.y)))
		energy += mixed.x * mixed.x + mixed.y * mixed.y
		difference_energy += (mixed.x - mixed.y) * (mixed.x - mixed.y)
		channel_product += mixed.x * mixed.y
		_write_pcm16(data, 44 + frame * 4, mixed.x)
		_write_pcm16(data, 46 + frame * 4, mixed.y)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "Unable to open " + path}
	file.store_buffer(data)
	file.close()
	var rms := sqrt(energy / float(frame_count * 2))
	_music_time = old_time
	_active_intensity = old_active
	_pending_intensity = old_pending
	_target_intensity = old_target
	_section = old_section
	_last_bar = old_bar
	_duck = old_duck
	_paused = old_paused
	_voices = old_voices
	return {"mode": mode, "duration_seconds": seconds, "frames": frame_count, "peak": peak, "peak_dbfs": linear_to_db(maxf(peak, 0.000001)), "rms": rms, "rms_dbfs": linear_to_db(maxf(rms, 0.000001)), "stereo_difference_rms": sqrt(difference_energy / float(frame_count)), "stereo_correlation": channel_product / maxf(energy * 0.5, 0.000001), "section": _section_for_intensity(evidence_intensity)}


func _trigger_evidence_events(frame: int, mode: String) -> void:
	var at := func(seconds: float) -> bool: return frame == int(seconds * SAMPLE_RATE)
	if mode == "low":
		if at.call(0.70): _on_lane_changed(0)
		if at.call(1.20): _on_shape_changed(GameEvents.ShapeKind.CUBE)
		if at.call(2.10): _on_gate_judged(GameEvents.JudgmentKind.PERFECT, 100)
		if at.call(3.20): _on_combo_changed(10, 2)
	elif mode == "mid":
		if at.call(0.65): _on_lane_changed(1)
		if at.call(1.15): _on_shape_changed(GameEvents.ShapeKind.SPHERE)
		if at.call(1.85): _on_gate_judged(GameEvents.JudgmentKind.PERFECT, 100)
		if at.call(2.85): _on_combo_changed(12, 3)
	elif mode == "high":
		if at.call(0.45): _on_lane_changed(2)
		if at.call(0.82): _on_shape_changed(GameEvents.ShapeKind.PYRAMID)
		if at.call(1.20): _on_gate_judged(GameEvents.JudgmentKind.PERFECT, 100)
		if at.call(2.00): _on_combo_changed(20, 4)
		if at.call(3.10): _on_gate_judged(GameEvents.JudgmentKind.NEAR_MISS, 25)
	elif mode == "fail_restart":
		if at.call(0.50): _on_gate_judged(GameEvents.JudgmentKind.NEAR_MISS, 25)
		if at.call(1.45): _on_run_failed(0, 0)
		if at.call(3.20): play_restart()
		if at.call(3.65): _on_shape_changed(GameEvents.ShapeKind.SPHERE)
		if at.call(4.20): _on_gate_judged(GameEvents.JudgmentKind.PERFECT, 100)


func _write_wav_header(data: PackedByteArray, frames: int) -> void:
	var values := [82, 73, 70, 70, 36 + frames * 4, 87, 65, 86, 69, 102, 109, 116, 32, 16, 1, 2, int(SAMPLE_RATE), int(SAMPLE_RATE) * 4, 4, 16, 100, 97, 116, 97, frames * 4]
	var offsets := [0, 1, 2, 3, 4, 8, 9, 10, 11, 12, 13, 14, 15, 16, 20, 22, 24, 28, 32, 34, 36, 37, 38, 39, 40]
	for index in values.size():
		var bytes := 1
		if index == 4 or index == 14 or index == 16 or index == 17 or index == 24:
			bytes = 4
		elif index == 15 or index == 18 or index == 19:
			bytes = 2
		for byte_index in bytes:
			data[offsets[index] + byte_index] = (int(values[index]) >> (8 * byte_index)) & 0xff


func _write_pcm16(data: PackedByteArray, offset: int, value: float) -> void:
	var signed_value := int(clampf(value, -SAFE_PEAK, SAFE_PEAK) * 32767.0)
	var raw := signed_value & 0xffff
	data[offset] = raw & 0xff
	data[offset + 1] = (raw >> 8) & 0xff
