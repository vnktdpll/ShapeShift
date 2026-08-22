# UI authoring

- Open `hud.tscn` to assign the HUD controller's reusable scene and theme.
- Open `neon_popover.tscn` to edit the shared glass frame, centered header,
  divider, and cyan/magenta edge primitives. Keep the unique `Title`, `Subtitle`,
  and `Content` node names; runtime menu content is inserted at those anchors.
- Open `../../assets/ui/neon_popover_theme.tres` to tune panel glass, button
  typography, hover/focus contrast, sliders, and shared spacing without editing
  gameplay code.

The score and touch targets deliberately remain outside the popover theme so the
active-play HUD stays restrained. Repeated controls and binding rows are pooled
as runtime children because their values come from the current profile, while
their frame and style remain editor-authored resources.
