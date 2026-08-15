# Legacy ShapeShift snapshot

`original/` contains the 2018 Godot 2.x source material fetched from the linked
upstream repository. It is excluded from Godot 4 resource scanning by
`legacy/.gdignore` and is not part of the new runtime.

The original mechanic was inspected from source and the included 14.7-second
recording: a player selects one of three lanes and one of three shapes to match a
falling tile. Useful concepts are reimplemented cleanly in the Godot 4 project.

The legacy export configuration contained a plaintext release-keystore password.
That value is redacted in this working tree. The associated Android signing key
should be considered compromised and replaced. Ad SDK identifiers and obsolete
Android module references remain only inside this quarantined historical folder.

The provenance of the old fonts, images, and audio is incomplete. None of those
assets are loaded or shipped by the new game.
