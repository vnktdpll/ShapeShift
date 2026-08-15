# Round 4 audio evidence

Run `tools/audio_evidence.gd` with Godot headless to regenerate the original,
repository-owned 44.1 kHz stereo WAV captures and `audio-metrics.json`.

- `audio-low-drift.wav` demonstrates the low-intensity Drift arrangement plus
  lane, morph, perfect, and combo-milestone cues.
- `audio-mid-drive.wav` demonstrates the middle-intensity Drive arrangement
  (off-beat stabs and pulse) with the same responsive game cues.
- `audio-high-apex.wav` demonstrates the high-intensity Apex arrangement plus
  lane, morph, perfect, milestone, and near-miss cues.
- `audio-fail-restart.wav` demonstrates near miss, crash ducking, restart, a
  fresh morph, and a renewed perfect cue.

The renderer uses the same deterministic synthesis methods and fixed seed as
runtime. It emits 16-bit PCM directly, measures frame peak/RMS and L/R
difference energy, and asserts a peak at or below -1 dBFS before the Music/SFX
bus compressors. The Music and SFX buses retain separate safety compression in
`audio/default_bus_layout.tres`.
