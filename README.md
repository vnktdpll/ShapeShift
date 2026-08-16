# ShapeShift: Neon Gauntlet

A clean Godot 4 reimagining of the original ShapeShift mechanic: read the
approaching standalone target, move across three lanes, and instantly morph
between cube, pyramid, and sphere. Accurate matches build combo and multiplier while the
course, camera, effects, and procedural electronic score intensify.

The active game is entirely procedural. It loads none of the quarantined Godot
2 art, fonts, sounds, ad integrations, or export credentials.

## Launch

Tested with Godot 4.7.1 stable on Apple Silicon. Open `project.godot` in Godot
and run the project, or launch directly:

```sh
"/Users/vnktdpl/Downloads/Godot 2.app/Contents/MacOS/Godot" --path .
```

Normal launches open on the supplied 4:3 VN Games artwork, preserve its aspect
ratio on any window shape, and then transition automatically into the game.
Automated test, benchmark, and evidence flags skip the timed hold so validation
remains deterministic.

The application bundle happens to be named `Godot 2.app`, but its executable is
Godot 4.7.1. Any compatible stable Godot 4.7 executable can be substituted.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Shift lane | A / D or Left / Right | D-pad Left / Right |
| Cube | 1 or J | X / West face button |
| Pyramid | 2 or K | Y / North face button |
| Sphere | 3 or L | B / East face button |
| Pause / resume | P or Escape | Start |
| Instant restart | R | Right shoulder / R1 |
| Mute | M | Settings menu also available |

The left analog stick also changes lanes. During play, touch devices expose
large icon-only targets for lane movement, triangle, circle, and pause. Triangle
and circle are hold overrides; releasing the last held form returns the player
to the neutral square/cube. Targets support simultaneous touches and stay inside
the gameplay safe area.

Open **Controls** from the main, pause, or results menu to rebind keyboard and
controller actions. The capture flow supports cancel, explicit conflict swaps,
reset-to-defaults, and automatic recovery from an empty required action.
Bindings persist in `user://shapeshift_profile.json`.

The pause and results screens expose separate music/effects volume, mute,
reduced motion, reduced flash, and Low/Medium/High quality settings. Settings and
high score persist in `user://shapeshift_profile.json`.

## Rules and difficulty

- Match both the target lane and its single displayed 3D form for a Perfect
  judgment. Only the nearest target is visible and actionable.
- Only an exact lane-and-form match survives. Any mismatch immediately ends the
  one-attempt run; restart restores a fresh run in place.
- The first six targets teach center match, left/right movement, and both
  non-default forms through play.
- Every five consecutive successful judgments raises the multiplier, up to ×8.
- Speed follows a smooth deterministic escalation from 14 to 30 world units/s.
- Three pacing families are selected from a seeded schedule, but each step has
  exactly one lane/form target. Telegraphs never fall below 1.25 seconds.

## Architecture

`GameRoot` composes typed, independent systems at runtime:

- `PlayerController`: immediate logical form state, solid cube/pyramid/sphere
  meshes, 108 ms morph, and 156 ms anticipated/eased three-lane motion.
- `TrackCourse`: fixed judgment plane, ten recycled standalone targets,
  deterministic schedule, onboarding, speed curve, and judgment contract.
- `TrackFairnessSolver`: pure reachability checks used by the 10,000-gate test.
- `ScoreSystem` and `ProfileStore`: score/combo/multiplier and JSON persistence.
- `NeonCourseEnvironment`, `ArcadeCameraRig`, and `ArcadeFxDirector`: independently
  recycled close/mid/far city belts with pane windows and articulated towers,
  four bounded street lights, 36 rain/haze particles, bounded FOV/bank/shake,
  and lane-correct pooled interaction bursts.
- `BootSplash`: aspect-fitted 4:3 VN Games artwork, deterministic test/evidence
  bypasses, and an automatic transition into the real main scene.
- `ReactiveAudioEngine`: original real-time percussion, bass, harmony, pulse, and
  lead synthesis plus event SFX on separate compressed Music/SFX buses.
- `HUDController`: score-only gameplay HUD, icon-only touch controls, menus, audio,
  accessibility, and control-remapping UI.
- `InputBindingStore`: persistent device-neutral bindings with safe recovery.

The original project is preserved under `legacy/original/` and excluded from the
Godot resource scanner by `legacy/.gdignore`. See `legacy/README.md` for the
credential and asset-provenance migration notes.

## Validation

Run the complete parser/import and deterministic gameplay suite:

```sh
tools/validate.sh
```

Individual useful commands:

```sh
# Audio/presentation smoke
"/Users/vnktdpl/Downloads/Godot 2.app/Contents/MacOS/Godot" \
  --headless --path . --script res://tools/audio_smoke.gd

# Automated course run and performance evidence
"/Users/vnktdpl/Downloads/Godot 2.app/Contents/MacOS/Godot" \
  --path . -- --autopilot --max-speed --benchmark=60

# Results-state reset benchmark
"/Users/vnktdpl/Downloads/Godot 2.app/Contents/MacOS/Godot" \
  --path . -- --restart-benchmark=20

# Direct gameplay capture (opens a window and quits automatically)
"/Users/vnktdpl/Downloads/Godot 2.app/Contents/MacOS/Godot" \
  --path . -- --autopilot --evidence=docs/evidence/gameplay.png
```

Seeds are fixed for tests (`7719`) and derived deterministically on each in-game
restart. The test runner exits nonzero on failure.

## Export

Install the matching Godot 4.7 export templates, open **Project → Export**, add a
desktop preset, choose a path under `builds/`, and export. The local machine did
not have export templates during validation, so executable export creation is not
part of the automated gate. No obsolete Android custom templates or ad modules
are included.
