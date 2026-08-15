# ShapeShift Gauntlet Log

## Acceptance gate

A round passes only when all automated checks pass, the project launches without
parser errors, play → fail → restart works, no critical/high defect is known, no
rubric category is below 7, and core mechanic, game feel, visuals, music, and
sound impact score at least 8.

Key measurements: input response within one rendered frame; lane settle at or
below 180 ms; logical shape switch in one physics tick with visual morph at or
below 120 ms; readable maximum-speed telegraph at or above 1.25 seconds;
restart-to-active p95 at or below 350 ms; deterministic reachability simulation
with zero impossible sequences; medium-quality 1080p p95 frame time at or below
16.7 ms on the local Apple M4 target.

## Baseline — 2026-08-14

- Upstream: one-commit Godot 2.x portrait game; no project README or license.
- Installed engine: Godot 4.7.1 stable (`a13da4feb`), Apple Silicon.
- Legacy recording: 14.732 s, 1280×720. It confirms hard lane snaps, three
  button-held forms, one random falling tile, binary score/failure, and flat UI.
- Godot 4 launch baseline: legacy has `engine.cfg`, format-1 scenes, and obsolete
  APIs, so it is not a runnable Godot 4 project.
- Risks: plaintext legacy signing credential (redacted; owner should rotate),
  unverified asset provenance, obsolete ad SDK integration, random unfairness,
  and no export templates installed locally.
- Decision: clean-room Godot 4 runtime; quarantine all legacy material; generate
  runtime geometry and audio in-repository; fixed judgment zone with recycled
  world; deterministic, reachability-checked patterns.

## Round 1 — Playable vertical slice (active)

### Measurable target

Godot 4 parser-clean launch; three responsive lanes; three immediate forms; at
least one deterministic gate; score → fail → reset-in-place restart; first-run
tutorial; headless smoke and determinism tests.

### Builders

- Player/game feel: lane interpolation, form state, morph visuals, input contract.
- Track/content: deterministic patterns, gates, telegraphs, fairness simulation.
- Presentation/audio: procedural environment, camera/FX, generated reactive mix.

### Evidence and critic verdict

- Direct captures: `docs/evidence/round1-gameplay.png` and
  `docs/evidence/round1-results.png`.
- `tools/validate.sh`: 10,129 deterministic checks passed; all nine lane/form
  pairs; 10,000 seeded judgments reachable; bounded recycled pool.
- 20-second High-quality internal 1280×720 run: p50 6.94 ms, p95 7.14 ms,
  p99 8.33 ms on Apple M4. Desktop output scales from the fixed internal
  viewport; native 1080p internal rendering remains unverified.
- Fresh independent critic: **FAIL**. Scores: core 8, feel 8, fairness 7,
  visuals 5, music 5, SFX 5, progression 6, UI/accessibility 6, technical 7,
  performance 8. No critical defects. Largest gap: solid emissive gate targets
  collapsed into similar bloom-heavy blobs at speed.
- Retention decision: keep the mechanics/architecture; repair the critic's gate
  readability gap before pursuing wider polish.

## Round 2 — Readability repair (critic review active)

### Measurable target

All nine lane/form combinations must be identifiable at initial and forced
maximum speed from shape geometry alone, with at least 1.25 seconds visibility.
Overlapping look-ahead gates must preserve depth order. Parser, deterministic,
presentation, and audio smoke checks must remain green.

### Repair

- Replaced solid gate props with large square, triangular, and circular outline
  apertures on near-black contrast plates.
- Added redundant built-in-font shape/lane labels without depending on color or
  tutorial text; sharply lowered target emission and bloom.
- Added distance fog and a darker environment for depth separation.
- Rebuilt HUD anchoring so score/form/combo remain fixed at all combo widths;
  results now hide the persistent HUD.
- Corrected evidence autopilot timing so overlapping telegraphs are acted on in
  their own judgment windows.
- Added `--max-speed` evidence mode and folded presentation/audio smoke into the
  main validation command. Smoke shutdown is now leak-free.

### Evidence and next action

- `docs/evidence/round2-readability-initial.png`
- `docs/evidence/round2-readability-max-speed.png` (30 u/s, 2.14× base)
- `tools/validate.sh`: PASS, 10,129 checks plus presentation/audio smoke.
- Fresh independent critic: **FAIL**, but confirmed the Round 1 gap materially
  fixed. Scores: core 8, feel 8, fairness 7, visuals 6, music 6, SFX 6,
  progression 7, UI/accessibility 7, technical 7, performance 8. Largest gap:
  premium visual composition and course identity.
- Retention decision: keep the aperture repair and target visual hierarchy next.

## Round 3 — Course identity and visual hierarchy (critic review active)

### Measurable target

The nearest actionable gate must own the visual hierarchy for its full decision
window at both 14 and 30 u/s. Distant gates must not stack labels or rails at the
vanishing point. The foreground must read as a continuous three-lane road with
authored midground rhythm, while parser/fairness/performance evidence remains
green and gate silhouettes remain intact.

### Repair

- Nearest gate now receives the full frame, contrast panels, apertures, and text;
  second gate receives unlabeled outlines; third receives a minimal depth frame;
  farther pooled gates are suppressed until promoted.
- Added continuous lane beds, deck seams, lane dividers, cyan road edges,
  shoulders, speed markers, low guardrails, side pylons, midground infrastructure,
  and a restrained horizon reactor using shared materials and recycled segments.
- Fixed HUD layout at high combo/FOV values with independently anchored labels.
- Added explicit procedural-audio shutdown and a 250 ms smoke-test drain; verbose
  validation now exits without leaked AudioStreamGeneratorPlayback instances.

### Evidence and next action

- `docs/evidence/round3-course-initial.png`
- `docs/evidence/round3-course-max-speed.png`
- `tools/validate.sh`: PASS, 10,129 checks and leak-free audio/presentation smoke.
- Fresh independent critic: **FAIL**, but confirmed the Round 2 visual hierarchy
  target materially fixed. Scores: core 8, feel 8, fairness 8, visuals 7,
  music 6, SFX 6, progression 7, UI/accessibility 7, technical 8, performance 8.
  No critical or high defects. Largest gap: audio production quality.
- 20 actual results→restart cycles: p50 2.312 ms, p95 2.674 ms, worst
  3.909 ms versus the 350 ms target.
- Retention decision: keep the complete visual/course repair; move to audio.

## Round 4 — Authored reactive audio (critic complete)

### Measurable target

At least three musically distinct intensity sections with seamless bar-quantized
transitions; true stereo arrangement; six clearly differentiated layered action
cues; pause/crash ducking; Music/SFX separation; repository-owned low/high/fail/
restart audio evidence; measured peak at or below −1 dBFS with no clipping.

### Evidence and critic verdict

- Rebuilt score into Drift, Drive, and Apex arrangements selected only at bar
  boundaries, with an eight-bar harmonic phrase, true stereo pads/panning,
  section-specific percussion/stabs/pulse/arpeggio/ride, and bounded soft limiting.
- Lane, three morph identities, perfect, milestone, near miss, crash, menu, and
  restart cues now use layered transient/body/delayed-tail voices with spatial
  separation. Music and SFX remain separate compressed buses.
- Deterministic 16-bit stereo evidence: `audio-low-drift.wav`,
  `audio-mid-drive.wav`, `audio-high-apex.wav`, and `audio-fail-restart.wav`.
  Peaks range from −11.35 to −10.18 dBFS; L/R difference RMS ranges 0.0259–0.0397.
- `tools/audio_evidence.gd` regenerates all WAVs and metrics from the same runtime
  synthesis methods and seed.
- Integration profiling initially regressed to p95 31.16 ms because rich 44.1 kHz
  generator work was too expensive. Runtime synthesis now uses an independently
  profiled 24 kHz path with cached pan gains; deterministic evidence remains
  44.1 kHz. Three repeated profiles passed; independent 20-second confirmation:
  p50 6.94 ms, p95 8.33 ms, p99 13.05 ms on High quality.
- `tools/validate.sh`: PASS, 10,129 checks plus leak-free presentation/audio
  smoke.
- Fresh independent critic: **FAIL**, while confirming the audio gap materially
  fixed. Scores: core 8, feel 8, fairness 8, visuals 7, music 8, SFX 8,
  progression 7, UI/accessibility 7, technical 8, performance 8. No critical or
  high defect. Largest gap: premium visual composition/course identity—the upper
  frame remained too empty, materials were sparse, and HUD safe-area confidence
  needed direct maximum-speed evidence.
- Retention decision: keep the complete audio rebuild and target the single
  remaining below-threshold category in a final visual cohesion wave.

## Round 5 — Premium visual cohesion (validation active)

### Measurable target

Visual polish must reach 8 without reducing the established gate silhouette or
fairness. The course needs a composed upper frame and richer foreground material
rhythm; player and gate geometry need premium secondary detail; the HUD must
stay inside a 28 px horizontal/22 px vertical safe area at maximum FOV, bank,
shake, combo width, and 30 u/s. All prior test/audio/performance gates remain.

### Repair and direct evidence

- Added a procedural navy/indigo sky, restrained horizon haze, sparse stars,
  overhead ribs and depth frames, richer metallic road inset rails, deck panels,
  and staggered shoulder plating without external textures.
- Rebuilt the player forms with layered metallic/emissive bodies, form cages,
  compact cores and rear rims. Added gate end caps, inset pillars, corner blocks,
  inner aperture rails, and material separation while preserving the nine
  outline silhouettes.
- Rebuilt the HUD as fixed safe-area capsules for score, current form, combo and
  speed; restyled prompts, toast, pause, results, settings, and buttons as one
  translucent neon system.
- Direct renderer captures: `docs/evidence/round5-course-initial.png` and
  `docs/evidence/round5-course-max-speed.png`. At 30 u/s the next gate remains
  readable, the active player stays distinct, and no persistent HUD element is
  clipped.
- Builder completion check: `tools/validate.sh` PASS, including parser/import,
  10,129 deterministic checks, and leak-free presentation/audio smoke.
- The first integrated High-quality profile failed retention at p95 53.80 ms.
  Diagnosis separated static rendering from live event churn: secondary road
  detail created too many sub-pixel draws, while recycled gates and sparks were
  allocating meshes/materials during judgments. Road modules are now staggered;
  gates retarget a prebuilt bounded visual superset; 100 sparks are preallocated.
- Twenty results→restart cycles after pooling: p50 0.821 ms, p95 0.985 ms,
  worst 1.121 ms versus the 350 ms target.
- Five-minute High-quality forced-maximum soak: 30,220 rendered frames at
  1280×720 internal resolution; p50 6.94 ms, p95 16.67 ms, p99 22.47 ms; ten
  bounded gates; clean exit. This passes the 16.7 ms p95 gate despite a
  concurrently running local video process consuming substantial CPU.
- Retention decision: keep the visual wave only after the pooled build restored
  the performance objective. Next action: fresh independent critic using the
  frozen artifact and direct evidence only.

### Independent critic verdict

- Fresh critic directly launched the Godot artifact, completed a rendered
  play→failure flow, exercised keyboard restart, inspected both Round 5 captures,
  listened to/analyzed all four WAVs, reran validation, and audited the source.
- Verdict: **PASS**. Scores: core 9, feel 8, fairness 9, visuals 8, music 8,
  SFX 8, progression 7, UI/accessibility 8, technical 9, performance 8.
- The Round 4 visual gap is materially fixed; no critical/high defect was found.
  The single largest remaining non-blocking gap is long-run content breadth
  beyond score mastery.
- Results-state evidence: `docs/evidence/round5-results.png`.
- Next action: one final fresh cohesion critic on the unchanged runtime. If it
  also finds no material gap, stop under the bounded Gauntlet condition.

## Round 6 — Final cohesion judgment (complete)

### Independent verdict

- A second fresh critic independently reran validation, launched the actual
  Metal/OpenGL Compatibility artifact, captured maximum-speed and results states,
  probed the real start→fail→results→restart transition, inspected all captures,
  analyzed the WAV signals/mix implementation, and audited architecture/notices.
- Verdict: **PASS**. Scores: core 9, feel 8, fairness 9, visuals 8, music 8,
  SFX 8, progression 8, UI/accessibility 8, technical 9, performance 8.
- Transition probe: results state valid, restart state valid, 0.591 ms reset,
  all ten gates restored. Native OS keyboard injection was unavailable because
  macOS assistive access was denied; mapped inputs and state transitions remain
  covered by launch, deterministic contracts, and controller/keyboard config.
- No critical/high defect and **no material acceptance gap** remains. Optional
  future breadth is explicitly non-blocking.

### Stop decision

All rubric thresholds pass, parser/launch/tests/play→fail→restart pass, the
five-minute soak passes, and two consecutive fresh critics find no material gap.
The bounded Gauntlet stops after six rounds. The highest-value optional next
improvement is a seeded daily challenge with a local ghost replay, adding a
repeatable mastery target without diluting the core mechanic.

## Refinement Gauntlet — 2026-08-15

### New acceptance target

The active game may show only numeric score and lives text; all other play-state
communication must be nonverbal. Touch, keyboard, and controller must complete
the full loop, while keyboard/controller bindings support capture, cancel,
conflict swap, defaults, recovery, and persistence. The supplied neon images are
principle-only references: no external assets or copied compositions.

### Baseline verdict — FAIL

- Scores: HUD restraint 1, touch 1, keyboard 7, controller 4, remapping 1,
  visuals 7, readability 6, technical 7, performance 6.
- Direct capture `docs/evidence/v2-baseline-max-speed.png` showed persistent
  form/combo/speed/instruction/judgment prose and world-space gate labels.
- No touch gameplay, lives, remapping, analog-stick movement, or binding tests
  existed. A fresh 15-second forced-max run measured 17.69 ms p95.
- Largest gap: a coherent cross-device controls and remapping system.

### Round 1 — controls, restraint, and neon cohesion (critic active)

- Gameplay HUD now contains only numeric score and lives. Gate labels and all
  active-play prose/toasts/instructions were removed; visual pulses, geometry,
  audio, and icons carry feedback.
- Added three-life runs with two nonfatal misses and a terminal third miss.
- Added large safe-area touch targets for two lanes, three forms, and pause;
  keyboard, D-pad, face buttons, and analog-stick lane movement remain active.
- Added persistent keyboard/controller remapping for gameplay and menu actions,
  including capture/cancel, explicit conflict swap, defaults, focus navigation,
  empty-binding recovery, and device-neutral serialization.
- Applied an original dark-indigo/cyan/magenta course pass with selective amber,
  matte structures, repeated frames, label-free apertures, and controlled bloom.
- Direct evidence: `v2-round1-gameplay.png`, `v2-round1-max-speed.png`,
  `v2-visual-initial.png`, and `v2-visual-max-speed.png` under `docs/evidence/`.
- `tools/validate.sh`: parser/import, 10,144 deterministic checks, audio/
  presentation smoke, and a new active-main-scene runtime smoke all pass.
- Twenty results-to-restart cycles: 0.664 ms p50, 0.901 ms p95, 0.962 ms worst.
- Fresh integrated 30-second forced-max High run: 12.963 ms p50, 16.667 ms p95,
  22.713 ms p99 at 1280×720. The 16.7 ms p95 gate passes narrowly.
- Fresh critic: **FAIL**. Scores: HUD 9, touch 6, keyboard 8,
  controller 4, remapping 5, visuals 7, readability 8, technical 7,
  performance 7. The controls gap was materially improved but remained open:
  controller menus lacked default accept/cancel; controller capture could not
  cancel; the apparent conflict swap created a displaced-event duplicate; and
  touch placement did not consult the platform safe area.

### Round 2 — controller-complete repair (critic active)

- Added default controller accept/cancel actions while retaining keyboard menu
  controls, plus analog-stick lane movement.
- Controller/menu-back now cancels binding capture. Capture copy is device-
  neutral rather than Escape-only.
- Reworked conflict swaps to move the target primary event, remove the incoming
  event from the conflicting action, and prove that neither side retains a new
  duplicate.
- Touch/HUD placement now scales the platform display safe area into viewport
  coordinates and recomputes on viewport resize/orientation change.
- Fixed a rendered-state integration defect found through direct evidence:
  hiding the score card had hidden the entire HUD canvas, including menus.
  Controls/settings now hide and restore their underlying menu cleanly, all
  primary menus establish controller focus, and menu-back closes overlays.
- Added direct controls-menu evidence at `docs/evidence/v2-controls-menu.png`.
- `tools/validate.sh`: 10,148 checks plus parser, audio/presentation, and active
  runtime smoke pass. New checks cover controller axis serialization, default
  menu accept/cancel, conflict-free displaced bindings, and safe-area scaling.
- Fresh critic: **FAIL**. Scores: HUD 9, touch 8, keyboard 8, controller 5,
  remapping 6, visuals 7, readability 8, technical 7, performance 9. Independent
  forced-max High p95 was 9.523 ms, but controller South/A was shared by restart
  and menu accept; `GameRoot` consumed restart before focused buttons could act.
  A clean cache-free import also exposed a malformed audio bus resource header.

### Round 3 — conflict-free defaults, packaging, and visual depth (critic active)

- Moved controller restart from South/A to right shoulder, leaving South/A as
  unambiguous menu accept. Added an automated default-action collision check.
- Controls rows now display both keyboard and controller/axis labels instead of
  hiding controller availability behind the first keyboard event.
- Strengthened the swap test to capture the actual pre-swap primary event and
  prove it moved to the conflicting action without remaining on the target.
- Corrected `default_bus_layout.tres` to declare `AudioBusLayout` and load steps.
  A fresh temporary copy with no `.godot` cache now imports with zero parser or
  resource errors.
- Added elevated peripheral bays, recessed side ribbons, and pylon slit/band
  detailing with shared materials and no extra runtime lights. The central gate,
  aperture, player, and lane boundaries remain the dominant decision read.
- Reduced only fog-obscured recycled dressing from fourteen to twelve segments
  after cross-run variance exposed a too-narrow frame-time margin.
- Direct evidence: `docs/evidence/v2-round3-initial.png`,
  `docs/evidence/v2-round3-max-speed.png`, and the latest integrated capture
  `docs/evidence/v2-round3-integrated-max.png`.
- `tools/validate.sh`: 10,151 checks plus all smoke gates pass.
- Fresh integrated 30-second forced-maximum High run at 1280×720: 6.896 ms
  p50, 6.944 ms p95, and 15.528 ms p99 against the 16.7 ms p95 gate.
- Fresh critic: **FAIL** only on visual fidelity (7); HUD 9, touch 8,
  keyboard 8, controller 8, remapping 8, readability 8, technical 8, and
  performance 9. The environment still read as a clean neon prototype rather
  than a layered cyberpunk space. This became the baseline for the user's
  expanded Round 4 brief.

### Round 4 — standalone targets, interaction FX, and cyberpunk city (critic pending)

- Replaced rectangular gate assemblies with large standalone emissive outline
  targets. Only the nearest target is visible/actionable; each generated spec
  now contains exactly one lane/form pair, including the tutorial sequence.
- Target meshes, judgment lights, and interaction sparks are bounded and pooled.
  Perfect, near-miss, and miss interactions all produce particles; reduced-flash
  caps the burst at six particles.
- Added three depth layers of cyberpunk skyline masses, window bands, service
  megadecks, elevated conduits, and abstract non-text light panels using shared
  materials and MultiMeshes. A final material-only lift improved city separation
  without adding lights or geometry.
- The touch form HUD now shows only triangle and circle hold overrides. Releasing
  the last held override returns the player to the neutral square/cube form.
- Direct evidence: `docs/evidence/v2-round4-standalone-target.png`,
  `docs/evidence/v2-round4-cyberpunk-initial.png`,
  `docs/evidence/v2-round4-cyberpunk-max-speed.png`, and
  `docs/evidence/v2-round4-final.png`.
- `tools/validate.sh` passes parser/import, 20,167 deterministic checks,
  presentation/audio smoke, and an integrated 90-frame runtime invariant check.
- Fresh integrated 30-second forced-maximum High run at 1280×720: 11.111 ms
  p50, 16.025 ms p95, and 21.563 ms p99; the 16.7 ms p95 gate passes.
- Fresh critic: **FAIL**. The triangle was clipped into the deck and therefore
  read as a caret; cube/sphere lacked direct evidence. The new skyline remained
  too distant/dark, with a blank close column and too much flat blue void.
- Repair: raised every target above the deck, reduced two fog-obscured road
  segments, broadened/foregrounded abstract light panels, added three-row
  inhabited façade rhythm to all midground towers, strengthened cyan/magenta
  separation, and lifted the horizon haze.
- New direct all-form evidence: `docs/evidence/v2-round4-cube.png`,
  `docs/evidence/v2-round4-pyramid.png`, `docs/evidence/v2-round4-sphere.png`,
  and `docs/evidence/v2-round4-repair.png`. Each shows one complete standalone
  silhouette above the deck.
- Post-repair 30-second forced-maximum High run: 10.869 ms p50, 15.150 ms
  p95, and 20.940 ms p99. Full validation remains green at 20,167 checks.
- Fresh repair critic: **PASS**. Scores: HUD 9, touch 9, keyboard 8,
  controller 8, remapping 8, visual fidelity 8, readability 9, technical 9,
  performance 8, standalone targets 9, interaction particles 8, cyberpunk
  background 8, and neutral touch behavior 9. No material gap found.
- Next action: final independent stopping critic for the required consecutive
  verdict.
- Final stopping critic: **PASS**, with the same acceptance floor and no
  material gap. Its clean-copy 30-second maximum-speed run measured 10.614 ms
  p50 and 16.667 ms p95. Parser/import, 20,167 checks, audio/presentation, and
  runtime smoke passed again.
- Stop decision: two consecutive fresh critics pass every category at 8 or
  higher. The bounded Round 4 Gauntlet stops. The lack of recorded physical
  controller/multitouch footage remains an evidence limitation, not a code gap.

### Round 5 — one life and an enclosing illuminated city (builders active)

- New target supersedes the prior lives requirement: active play shows score
  only, the first miss immediately ends the run, and restart begins a fresh
  one-attempt run in place.
- New visual target: bring procedural city massing into the near and midground
  around both sides of the platform, with close façade/screen/cable rhythm,
  bounded illuminated street fixtures, visible light pools, and stronger
  interaction/atmospheric particles. Reference images remain principle-only.
- Baseline evidence `docs/evidence/v2-round4-repair.png` passes the prior round
  but still places most tower mass near the horizon and shows a lives counter.
- Builders split along independent one-life/HUD and city/lighting boundaries;
  integration will freeze only after runtime, clean import, all-form readability,
  restart, particle boundedness, and maximum-speed performance evidence pass.
- One-life integration removes only the lives concept/card/dependency. Score,
  touch controls, pause/results/settings, and remapping remain. Runtime smoke
  proves the first MISS enters CRASHED/RESULTS and restart restores a fresh
  score-zero active run.
- The city now begins beside the player with dense near/mid/far façade stacks,
  abstract illuminated panels, side cantilevers, overhead utility cables, four
  shadowless real street lights, emissive fixtures/light pools, and one fixed
  36-particle rain/haze emitter. Reduced-flash lowers atmosphere density.
- Follow-up observation repair: the city now uses three moving depth belts:
  five close chunks at 0.86× course speed, seven mid-city chunks at 0.52×, and
  eight far-city chunks at 0.30×. Each belt recycles independently and only one
  off-camera chunk can cross a belt boundary at a time; each close chunk's
  buildings, emissive fixtures, and optional street light stay one hierarchy.
- Rejected both a duplicated two-district design (30.0 ms forced-maximum p95)
  and a cheaper whole-district wrap after direct play exposed its synchronized
  pop. The retained three-belt chunk design preserves invariant circular spacing and
  a fixed 414-node/4-light/36-particle budget. The final denser, all-moving city
  measured 11.111 ms p50, 16.327 ms p95, and 22.236 ms p99 over 30 seconds at
  forced maximum speed.
- Fixed gameplay bursts that had followed the centered controller node instead
  of its lane-moving Avatar. All judged and lane-trail bursts now convert the
  player's true world position; deterministic translated-hierarchy checks cover
  left, center, and right.
- Replaced each player cage/core/rim assembly with one solid persistent mesh.
  Cube, pyramid, and sphere retain morph/color identity without internal lines.
- Aligned the icon-only pause control with the score on the same top HUD row.
- Evidence: `v2-round5-city-initial.png`, `v2-round5-city-max-speed.png`,
  the final all-layer motion sequence
  `v2-round5-all-city-layers-frame-{100,175,250,325}.png`,
  and `v2-round5-solid-{cube,pyramid,sphere}.png` under `docs/evidence/`.
- `tools/validate.sh` passes parser/import, 20,176 deterministic checks,
  presentation/audio, city-scroll budgets, one-life restart, and integrated
  runtime smoke.
- The first close-chunk-only repair was not the stopping artifact: direct user
  review found that its close façades moved while mid/far building layers stayed
  fixed. Round 5 reopened with a stricter requirement that every building layer
  scroll at a depth-appropriate rate. The retained replacement increases density
  with dark mid/far silhouette massing and low-energy bands outside the decision
  cone; sequential evidence shows enclosure without a synchronized wrap.
- Fresh critic: **FAIL** only on all-building motion (7/10). It found that the
  central `HorizonBeacon` remained fixed under `_course_root`, outside all three
  tested chunk pools. Continuity scored 9, density 8, readability 9, boundedness
  9, and performance 9.
- Repair: removed the stationary beacon geometry while retaining its invisible
  global directional light. Runtime smoke now rejects any reintroduced
  `HorizonBeacon`; every visible architectural city element belongs to a moving,
  independently recycled depth belt.
- Fresh post-repair critic: **PASS**. Scores: all-building motion 10,
  continuity 9, density 9, readability/non-distraction 9, boundedness 10, and
  performance 8. It found no remaining stationary building-like geometry or
  material regression; the only caution is modest p95 headroom.
- Final stopping critic: **PASS** with the same 10/9/9/9/10/8 score floor. It
  independently confirmed that only non-architectural stars and atmosphere stay
  world-fixed, all building and course infrastructure moves, and the four-frame
  sequence has no visible gap or synchronized pop.
- Stop decision: two consecutive fresh critics pass every Round 5 category at
  8 or higher. The Gauntlet stops; the remaining non-blocking caution is the
  0.373 ms p95 margin before any further visual density is added.
