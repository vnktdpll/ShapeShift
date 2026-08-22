# Scene authoring map

Open these scenes directly in Godot to tune one subsystem without expanding the
entire game tree:

- `gameplay/player/player.tscn`: cube, four-sided pyramid, sphere, hitbox,
  form anchor, shift rings, and trail primitives.
- `gameplay/track/track_course.tscn`: course settings and the exported reusable
  `target_gate.tscn` pool template.
- `presentation/arcade_camera_rig.tscn`: the gameplay `Camera3D` and camera feel
  exports.
- `presentation/arcade_fx_director.tscn`: screen-flash and bounded spark-pool
  authoring groups. Its `spark_template.tscn` exposes the `SphereMesh` radius,
  height, segments, rings, material, and emission; the editable
  `../assets/fx/spark_fx_profile.tres` owns total pool size and per-quality
  capacity budgets.
- `presentation/neon_environment.tscn`: city profile and environment root.
- `audio/reactive_audio_engine.tscn`: separate procedural Music and SFX players.
- `ui/hud.tscn`: HUD controller with the reusable neon popover and theme.

`main.tscn` instances these scenes as stable, named children of `ShapeShift`.
Scripts bind authored nodes by name and only construct fallbacks when instantiated
directly by a focused test, so running the main scene never duplicates subsystems.
