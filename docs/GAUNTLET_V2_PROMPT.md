# ShapeShift refinement gauntlet

Improve the existing Godot 4 game in this repository. Preserve the working core,
reactive audio, deterministic fairness, restart speed, accessibility options,
and performance gates. Work autonomously on local in-scope files and tests. Do
not push, publish, purchase assets, copy reference art, or overwrite unrelated
user changes.

## Product requirements

1. **Quiet gameplay HUD**
   - During active gameplay, the only persistent visible text is the numeric
     score. Menus may contain necessary labels.
   - Remove active-play text for form, combo, multiplier, speed, instructions,
     judgments, milestones, latency, and debug state.
   - Communicate shape, lane, combo, danger, success, and tutorial information
     through geometry, color, animation, icons, audio, and haptics where
     available. Never depend on color alone.
   - Pause, results, settings, and control-remapping screens are menus. Keep
     their copy terse and legible.
   - A miss is immediately terminal. Restart resets the one-attempt run in
     place; do not show or maintain a lives counter.

2. **Touch, keyboard, controller, and remapping**
   - Touch must feel deliberate on phones/tablets in landscape and portrait-safe
     layouts: large safe-area-aware targets, multi-touch lane and form input,
     no text required on gameplay buttons, and no interference with menus.
   - Keyboard and controller must remain responsive and navigable.
   - Add an in-game controls menu supporting keyboard and controller rebinding
     for lane left/right, the three forms, pause, restart, and relevant menu
     actions. Include capture/cancel, conflict detection or explicit swap,
     reset-to-defaults, readable device labels, persistence, and recovery from
     unusable bindings.
   - Touch layout may be customizable if practical, but touch must always have
     a safe built-in fallback. Controls and settings must be operable using
     mouse/touch, keyboard, and controller.
   - Add deterministic tests for binding serialization, conflict resolution,
     reset defaults, and input-to-action behavior. Do not require physical
     hardware for the automated suite; supplement with direct manual evidence.

3. **Original neon cohesion pass**
   - Study `/tmp/shapeshift-neon-refs-20260815/ref1.jpg` and `ref2.webp` through
     `ref5.webp` only for visual principles. Do not copy their compositions,
     meshes, branding, or assets.
   - Translate the principles into ShapeShift's own language: dark indigo void,
     cyan/magenta emissive edges, selective warm accents, bold repeated geometric
     frames, layered depth, matte dark structures, readable silhouettes, and
     controlled bloom.
   - Maintain gate readability at initial and maximum speed. The actionable
     aperture and player form must dominate the hierarchy. Decorative neon may
     never disguise lane boundaries, hazards, or depth order.
   - Improve composition, material separation, course rhythm, and landmark
   moments without regressing the existing 16.7 ms p95 performance gate.

4. **Round 4 — standalone targets and cyberpunk depth**
   - Replace rectangular gate frames with one large, standalone target shape.
     At any instant, exactly one target shape may be visible and actionable;
     the player matches that form and passes through it.
   - Add bounded, pooled particle feedback for successful passes and damaging
     collisions/misses. Reduced-flash must remain respected.
   - Use the supplied cyberpunk city reference only for principles: layered
     industrial architecture, cyan/magenta/warm contrast, atmospheric depth,
     and abstract light panels. Keep the composition original, use no readable
     world text, and preserve the central decision cone.
   - The touch shape HUD contains only triangle and circle hold controls. When
     neither is held, the player defaults to square/cube. Keyboard/controller
     bindings and remapping remain supported.

5. **Round 5 — one life and an enclosing illuminated city**
   - Remove the lives system and lives HUD. The player has exactly one attempt:
     any miss immediately ends the run, and restart creates a fresh run in
     place. Active play now permits only score text. Preserve the HUD system,
     touch controls, score, and all menu/remapping screens; remove only the
     lives concept and lives-specific card/feedback.
   - Pull the procedural city into the near and midground so architecture,
     façades, abstract screens, cables, and industrial fixtures surround the
     platform like a cyberpunk street canyon. Keep the central target/lane cone
     unambiguous and do not copy reference assets or readable signage. The
     second city reference reinforces dense near/mid/far tower layering,
     stacked illuminated panels/window grids, overhead cables/bridges, and
     rain-haze sparkle—not literal signs, characters, or compositions.
   - Add bounded illuminated environmental sources such as street lamps and
     façade fixtures. Prefer emissive meshes with a small fixed real-light
     budget and prove there is no runtime light/node growth.
   - Make interaction particle feedback visibly legible for passes and misses,
     and add restrained bounded atmospheric particles if performance permits.
     Reduced-flash remains mandatory.
   - The close city must visibly scroll/recycle with the course rather than
     remaining fixed while the platform moves. Its geometry, fixtures, light
     pools, and atmosphere must stay coherent and bounded during recycling.
     Recycle close blocks independently with course segments; never wrap the
     entire visible city hierarchy at once or allow synchronized popping.
   - Every building layer must move with the running course. Use slower,
     depth-scaled parallax for mid/far buildings if useful, but no visible city
     building may remain world-stationary while foreground façades move.
     Increase architectural density through darker silhouette massing and
     restrained emissive repetition; keep the central player/target/lane cone
     brighter and simpler so the denser city never becomes distracting.
   - Spawn gameplay interaction particles at the player's actual lane/world
     position. Never emit every burst from the center lane.
   - Render the player as clean solid cube, pyramid, or sphere silhouettes with
     no internal cage/ring/line decoration obscuring the form.
   - Align the pause control horizontally with the score card on the top HUD row.

6. **Round 6 — credible façades, exact lane feedback, strict one-attempt play,
   and branded startup**
   - Replace thin façade light strokes with recognizable window modules: bounded
     panes or small grids with visible width and height, restrained emissive
     interiors, and non-uniform occupancy. Improve the second and third building
     columns with setbacks, roof/crown silhouettes, façade divisions, and window
     rhythm so they read as actual buildings rather than blank grey blocks.
     Preserve three moving depth belts, staggered recycling, the central decision
     cone, subdued background hierarchy, and the existing performance gate.
   - The short white platform light shown on a correct match must appear in the
     exact matched/player lane. It may never default to the center lane. Prove
     left, center, and right origins under translated hierarchies.
   - One attempt means every incorrect target result is immediately terminal.
     There is no hidden near-miss life and no sequence of multiple mistakes before
     results. A correct exact match is the only survivable judgment.
   - Show the supplied 4:3 VN Games artwork every time the application opens.
     Use the project-local `assets/branding/splash-4x3.png`, preserve its 4:3
     composition without distortion, and transition automatically into the game.
     Command-line test/evidence paths must remain deterministic.

7. **Round 7 — spatially clean city, cohesive popovers, neutral controls,
   uniform splash, and editor-authorable scenes**
   - Prevent buildings from occupying or visibly interpenetrating the same city
     footprint. Close, mid, and far belts must use explicit lateral/depth zones,
     minimum separation rules, and deterministic validation so a distant tower
     never grows through a nearer one. Preserve dense enclosure, pane windows,
     all-layer movement, staggered recycling, and the central decision cone.
   - Redesign every centered popover (ready, pause, results, settings, controls)
     as one cohesive neon UI system. Center-align titles, copy, controls, rows,
     and buttons; use consistent cyan/magenta hierarchy, dark glass panels,
     restrained glow/accent primitives, spacing, and controller focus states.
   - Neutral input is center lane plus cube. Left/right and pyramid/sphere are
     hold-to-steer overrides across keyboard, controller, and touch; releasing
     the last relevant input returns immediately to center/cube. Simultaneous
     inputs resolve deterministically and automated/autopilot commands remain
     available without being overwritten by idle physical input.
   - The branded splash background must render as one uniform blue field without
     mismatched side bars or visible color seams, while preserving the VN Games
     lockup, aspect, normal boot hold/fade, and automated bypasses.
   - Replace the root-only/runtime-only authoring structure with modular Godot
     scenes and reusable assets. Main must expose meaningful child systems;
     player, track/target, environment, FX/camera/audio, and HUD/popovers should
     each be openable as individual `.tscn` scenes. Use typed nodes and primitive
     mesh/UI resources with stable names, editable exported parameters, and
     documented ownership. Procedural pooling may remain where it is required for
     performance, but its authoring templates/profiles must be project resources.

## Gauntlet protocol

Use a bounded builder -> integration -> fresh critic -> repair loop. Builders
may work on independent areas, but one integration owner must resolve cohesion.
Never let a builder judge its own work. Each critic receives only this brief,
the runnable artifact, the reference images, and direct evidence.

For every round:

1. State the measurable target and baseline.
2. Run the actual game and relevant tests.
3. Capture direct gameplay/menu/touch/remapping/max-speed evidence.
4. Have a fresh critic score the frozen artifact.
5. Fix the single largest meaningful gap.
6. Re-run regression, fairness, restart, audio, and performance checks.
7. Keep changes only if the artifact or objective evidence improves.
8. Append evidence, verdict, and retention decision to `GAUNTLET.md`.

Run at most four major rounds for this refinement. Stop earlier after two
consecutive fresh critics find no material gap and all gates pass. If two rounds
stall on the same issue, change strategy.

## Acceptance gates

- Active gameplay has no persistent text except numeric score.
- No transient gameplay prose appears; non-text feedback replaces it.
- Touch, keyboard, and controller each complete start -> play -> pause -> resume
  -> fail -> restart.
- Rebindings persist across relaunch; conflicts, cancel, defaults, and recovery
  are tested.
- Menus are usable with touch, keyboard, and controller focus.
- Initial- and maximum-speed captures retain clear player/gate/lane silhouettes.
- No copyrighted or downloaded reference assets enter the repository.
- Parser/import, deterministic fairness, audio smoke, restart benchmark, and
  existing automated checks pass.
- High-quality 960x720 4:3 p95 frame time remains at or below 16.7 ms on the local
  benchmark target.
- No critical/high defect remains.

Critics score 1-10: HUD restraint, touch, keyboard, controller, remapping,
visual fidelity/originality, gameplay readability, technical quality, and
performance. Every category must be at least 8.

## Deliverables

- Working implementation and tests.
- Updated `README.md`, `GAUNTLET.md`, and control documentation.
- Direct evidence for gameplay HUD, touch layout, controls/remapping menu,
  maximum-speed readability, test results, restart, and performance.
- Final scorecard, remaining limitations, and most valuable next improvement.

Begin by inspecting the dirty worktree and preserving unrelated changes. Build
on the current game rather than restarting it. Continue through implementation,
direct inspection, independent criticism, repair, and verification until a
bounded stopping condition is reached.
