# 2D/2.5D Visual QA

## Automated Gates

- `python3 scripts/generate_sprite_sets.py --output /tmp/deadworld-sprites-a --seed 20260826`
- Repeat into `/tmp/deadworld-sprites-b` and compare directories byte-for-byte.
- `python3 scripts/validate_sprite_assets.py --manifest client/assets/generated/characters/manifest.json --root client/assets/generated`
- `godot --headless --path client --editor --quit`
- `godot --headless --path client --script tests/directional_sprite_test.gd`
- `godot --headless --path client --script tests/depth_2d_test.gd`
- `godot --headless --path client --script tests/performance_budget_test.gd`
- `godot --headless --path client --script tests/world_streaming_test.gd`

## Directional Review

Run `tests/sprite_preview.tscn` in the desktop editor and inspect all eight columns:

- [ ] N, NE, E, SE, S, SW, W and NW are separate authored views.
- [ ] No direction is an accidental horizontal mirror.
- [ ] Feet share one baseline and remain grounded while frames change.
- [ ] Body, clothing, weapon, backpack and shadow layers stay aligned.
- [ ] Weapon points in the aim direction.
- [ ] Backpack reads behind the body in rear sectors.
- [ ] No alpha fringe, opaque background or atlas bleeding is visible.
- [ ] Survivor and zombie silhouettes are distinguishable at gameplay zoom.

## World Review

- [ ] Ground tiles have edge-compatible transitions and no visible seams.
- [ ] Props have a cohesive base, detail, wear and contact-shadow treatment.
- [ ] Wall front layers can occlude lower character pixels without hiding the player.
- [ ] Depth order is stable when two entities share the same Y coordinate.
- [ ] Highlight and health feedback remain readable without debug labels.
- [ ] Cell transitions do not duplicate or remove authoritative entities.
- [ ] Touch controls do not overlap the hotbar or status panel.

## Performance Review

Record minimum, average and p95 frame time during 60 seconds of movement, combat and four cell-boundary crossings on:

- Desktop Linux x86_64.
- Modern mid-range Android, approximately Snapdragon 7 Gen 1 or newer.
- iPhone with Apple A15 or newer.

The target is 60 FPS. If a device misses the target, first reduce distant cell detail, clutter, active light masks, animation density and texture resolution. Do not alter server simulation or silently change the normal target to 30 FPS.

## Headless Limitation

The current headless `gl_compatibility` environment may not expose a readable `SubViewport.get_texture().get_image()` result. A failed offscreen image read is not evidence that sprite import failed. Directional composition and material quality therefore require the desktop editor/manual capture gate until a renderer-compatible CI capture backend is available.
