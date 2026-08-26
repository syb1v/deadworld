# Deadworld 3D Isometric World Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Deadworld from the current 2D presentation to a grounded low-poly 3D isometric client, create a deterministic Blender-to-GLB asset pipeline, expand the authoritative world to a streamed 9x map, and validate 60 FPS targets on modern desktop/mobile hardware.

**Architecture:** Build the 3D client as a parallel presentation layer first, with a strict adapter from authoritative Nakama snapshots to Godot 3D nodes. Compile a versioned cell-based world descriptor from shared source data so server collision/persistence and client streaming consume the same IDs. Generate hero and prop GLBs with pinned Blender Python scripts, validate them before Godot import, and keep the existing 2D client available until the 3D vertical slice passes functional and performance gates.

**Tech Stack:** Godot 4.7.1, GDScript, existing Nakama + TypeScript runtime, PostgreSQL persistence, Blender Python at build time, GLB/glTF, PNG/ORM/normal PBR maps, existing `gl_compatibility` renderer, Node test runner, TypeScript strict check.

**Spec:** `docs/superpowers/specs/2026-08-26-3d-isometric-world-design.md`

## Global Constraints

- `1 Godot unit = 1 metre`.
- `1 world grid cell = 1 metre`; streaming cell is `32 x 32` gameplay metres.
- Existing server X/Y maps to Godot X/Z; Godot Y is height.
- Camera is fixed orthographic isometric with no player orbit.
- Character uses one rigged model and eight sectors: `N, NE, E, SE, S, SW, W, NW`.
- Blender is build-time only; no external runtime asset packs or services.
- Server remains authoritative for position, collision, bounds, spawns, items, containers, zombies and persistence.
- Protocol version remains `1` unless a separately reviewed public contract change is unavoidable.
- Target is 60 FPS on desktop and modern mid-range Android/iPhone devices around Snapdragon 7 Gen 1 / Apple A15 or newer.
- Mobile budgets: 150k visible triangles, 4 dynamic lights, 1 shadow-casting local light, 24 visible materials, 256 MB scene textures.
- Desktop budgets: 300k visible triangles, 8 dynamic lights, 2 shadow-casting local lights, 40 visible materials, 512 MB scene textures.
- Release-bound changes must run `version-stamp`, `make version-check`, tests and the release/tag gate in `AGENTS.md` before push.

## File Map

- Create `tools/blender/`: deterministic Blender scene/model/material generators and GLB export entrypoints.
- Create `tools/assets/`: asset manifest, naming/scale/material/triangle validators and deterministic hash checks.
- Create `client/scripts/world3d/`: camera rig, cell streaming, coordinate conversion, world cell presentation and 3D relevance.
- Create `client/scripts/entities3d/`: player, zombie, item, container and animation presentation adapters.
- Create `client/scenes3d/`: 3D boot/world/player/zombie/prop scenes and materials.
- Modify `client/project.godot`: 3D renderer settings, scene selection flag and platform-safe display settings.
- Modify `client/data/world_map.json`: versioned schema v2, 9x bounds, cells, districts, POIs and authoritative geometry.
- Modify `server/src/world.ts`: schema v2 loading, cell indexing, expanded collision and safe spawn handling.
- Modify `server/src/persistence.ts`: schema migration and deterministic fallback for invalid old positions.
- Create `server/tests/world_cells.test.ts`: cell geometry, adjacency, bounds and spawn tests.
- Create `server/tests/world_migration.test.ts`: v1-to-v2 and persisted-position tests.
- Modify `scripts/generate_assets.py`: keep existing 2D generator only for UI compatibility and add manifest linkage where required.
- Modify `.github/workflows/ci-release.yml`: pinned asset validation and 3D headless import checks.
- Modify `docs/ART_DIRECTION.md`, `docs/ARCHITECTURE.md`, `docs/DEV_SETUP.md`, `docs/MVP.md`, `docs/ROADMAP.md`: document the accepted pipeline and gates.

## Task 1: Pin 3D Toolchain And Asset Contract

**Files:**
- Create: `tools/blender/README.md`
- Create: `tools/assets/asset_manifest.json`
- Create: `tools/assets/validate_assets.py`
- Create: `tools/assets/test_validate_assets.py`
- Modify: `docs/DEV_SETUP.md`
- Modify: `.github/workflows/ci-release.yml`

**Interfaces:**
- `validate_assets.py --manifest tools/assets/asset_manifest.json --root client/assets/3d` exits non-zero for invalid names, scale, axes, missing LOD/material channels or budget violations.
- Manifest entries contain `id`, `path`, `kind`, `scale_m`, `forward_axis`, `lods`, `materials`, `triangle_budget` and `texture_budget_kb`.

- [ ] Confirm Blender availability in local and CI environments; if absent locally, document the pinned CI/container path instead of silently generating production assets elsewhere.
- [ ] Write failing tests for lowercase ASCII naming, origin/scale limits, +Y up/+Z forward, required LOD/material maps, triangle limits and deterministic manifest hashes.
- [ ] Run `python3 -m unittest tools/assets/test_validate_assets.py` and verify the invalid fixtures fail.
- [ ] Implement the validator using only Python standard library plus optional `bpy` inspection in the Blender execution wrapper.
- [ ] Add a manifest entry for the first survivor, zombie, pistol, wall module and ground material.
- [ ] Run validator against fixtures and an empty asset root; expect explicit missing-asset failures.
- [ ] Add CI steps that run the validator and a Godot headless import scan once assets exist.
- [ ] Commit with `feat(assets): define deterministic 3d asset contract`.

## Task 2: Build Blender GLB Generator

**Files:**
- Create: `tools/blender/generate_deadworld_assets.py`
- Create: `tools/blender/materials.py`
- Create: `tools/blender/characters.py`
- Create: `tools/blender/props.py`
- Create: `tools/blender/export_glb.py`
- Create: `tools/blender/test_generation.py`
- Create: `client/assets/3d/generated/manifest.json`

**Interfaces:**
- `blender --background --python tools/blender/generate_deadworld_assets.py -- --output client/assets/3d/generated --seed 20260826` produces stable GLBs and texture sources.
- Generated asset IDs match Task 1 manifest and use `dw_<domain>_<asset>_<variant>_<lod>` naming.

- [ ] Write a deterministic generation test that runs the script twice in a temporary output directory and compares SHA256 manifests.
- [ ] Implement modular low-poly geometry for survivor, zombie, pistol, medical prop, crate, dumpster, wall, road segment and ground tile.
- [ ] Build material nodes for base color, roughness, metallic, normal and AO with sRGB/linear handling.
- [ ] Apply one metre scale, ground-contact origin, +Y up and +Z forward to every export.
- [ ] Generate LOD0/LOD1/LOD2 for repeated props and collision proxy meshes with `dw_col_` names.
- [ ] Generate one armature and eight directional idle/walk/attack clips for the survivor; include sockets `weapon_hand_r`, `backpack` and `head`.
- [ ] Export GLB with stable object/material/action ordering and write a manifest hash.
- [ ] Run Blender generator and validator; compare two output hashes.
- [ ] Commit with `feat(assets): generate deterministic low-poly glb library`.

## Task 3: Create Godot 3D Foundation

**Files:**
- Create: `client/scenes3d/World3D.tscn`
- Create: `client/scenes3d/CameraRig3D.tscn`
- Create: `client/scripts/world3d/CoordinateAdapter.gd`
- Create: `client/scripts/world3d/IsometricCameraRig.gd`
- Create: `client/scripts/world3d/World3DController.gd`
- Create: `client/tests/world3d_foundation_test.gd`
- Modify: `client/project.godot`

**Interfaces:**
- `CoordinateAdapter.to_world3d(Vector2) -> Vector3` maps authoritative X/Y to X/Z.
- `CoordinateAdapter.to_authoritative(Vector3) -> Vector2` is the inverse within epsilon.
- `IsometricCameraRig.follow_target: Node3D`, `zoom_level: float`, `set_world_bounds(Rect2)` and `set_aim(Vector2)` are presentation-only.

- [ ] Add failing coordinate round-trip tests for origin, negative/positive coordinates and cell boundaries.
- [ ] Implement typed coordinate conversion and explicit metres/unit constants.
- [ ] Create fixed orthographic camera with pitch/yaw constants, smooth follow, aim lookahead and bounds clamp.
- [ ] Add a 32 m test cell with directional light, environment, fog/visibility baseline and one imported GLB prop.
- [ ] Add a runtime toggle so the existing 2D boot remains available until the 3D vertical slice is accepted.
- [ ] Run `godot --headless --path client --editor --quit` and foundation tests.
- [ ] Commit with `feat(client): add fixed isometric 3d foundation`.

## Task 4: Implement Rigged Character Presentation

**Files:**
- Create: `client/scripts/entities3d/Character3D.gd`
- Create: `client/scripts/entities3d/DirectionalAnimationSelector.gd`
- Create: `client/scenes3d/Character3D.tscn`
- Create: `client/tests/directional_animation_test.gd`
- Modify: `client/scripts/world3d/World3DController.gd`

**Interfaces:**
- `DirectionalAnimationSelector.sector_for_vector(Vector2) -> StringName` returns one of eight fixed sectors.
- `Character3D.apply_snapshot(position: Vector2, velocity: Vector2, aim: Vector2, state: StringName, event_id: int) -> void` updates presentation only.

- [ ] Write tests for all eight cardinal/diagonal vectors, zero-vector fallback and boundary angles.
- [ ] Implement nearest-45-degree sector selection with deterministic tie-breaking.
- [ ] Import survivor GLB, wire `Skeleton3D`, `AnimationPlayer`/`AnimationTree`, sockets and movement/attack state transitions.
- [ ] Add zombie variant using the same contract with a separate model/material.
- [ ] Add fixed-camera smoke captures for all eight sectors and reject missing clips/T-pose.
- [ ] Run Godot parse, directional tests and visual smoke render.
- [ ] Commit with `feat(client): add eight-direction rigged characters`.

## Task 5: Add Natural 3D Props And Materials

**Files:**
- Create: `client/scripts/entities3d/Prop3D.gd`
- Create: `client/scripts/entities3d/WorldItem3D.gd`
- Create: `client/scripts/entities3d/Container3D.gd`
- Create: `client/scenes3d/Prop3D.tscn`
- Create: `client/scenes3d/WorldItem3D.tscn`
- Create: `client/scenes3d/Container3D.tscn`
- Create: `client/scripts/world3d/MaterialVariantLibrary.gd`
- Modify: `client/scripts/data/ItemIcons.gd`

**Interfaces:**
- `MaterialVariantLibrary.material_for(district_id: StringName, family: StringName, variant_seed: int) -> Material` returns stable material variants.
- `WorldItem3D.apply_item(item: Dictionary) -> void` resolves a GLB by definition ID and does not mutate item ownership.

- [ ] Test stable material variant selection for equal seeds and bounded family IDs.
- [ ] Implement district-aware material families, vertex-color variation and roughness variation without baked shadows in albedo.
- [ ] Add prop placement with contact shadows, correct pivots, LOD switching and interaction highlight.
- [ ] Replace world item billboard presentation in 3D mode with model/icon fallback only when an asset is unavailable.
- [ ] Add container meshes with open/closed state and preserve existing server-authoritative transfer flow.
- [ ] Capture a representative scene and manually inspect that materials read as surfaces rather than layered flat images.
- [ ] Commit with `feat(client): add natural 3d prop presentation`.

## Task 6: Compile And Test World Schema v2

**Files:**
- Create: `server/src/world_cells.ts`
- Create: `server/tests/world_cells.test.ts`
- Create: `server/tests/world_migration.test.ts`
- Modify: `client/data/world_map.json`
- Modify: `server/src/world.ts`
- Modify: `server/src/persistence.ts`
- Modify: `docs/PROTOCOL.md`

**Interfaces:**
- `WorldDescriptorV2` contains `schemaVersion`, `worldId`, `cellSize`, `bounds`, `cells`, `districts`, `walls`, `spawnPoints` and `pointsOfInterest`.
- `getCellId(x: number, y: number): string` is deterministic.
- `getCellDescriptor(id: string): WorldCell | undefined` returns authoritative geometry metadata.
- `isWalkable(position: Point, radius: number): boolean` remains the authoritative collision query.

- [ ] Add failing tests for cell ID boundaries, adjacent cell lookup, expanded bounds, district membership, wall connectivity, safe spawns and old schema loading.
- [ ] Generate a 9x descriptor with 8-10 districts, landmarks, golden paths, optional routes, rest points and threat/resource identity.
- [ ] Implement schema v1 reader compatibility and v2 normalization with deterministic safehouse fallback for invalid persisted positions.
- [ ] Index walls, spawns, items and containers by cell without changing ownership/transaction semantics.
- [ ] Verify protocol remains version 1 unless payload size forces a documented review.
- [ ] Run `npm --prefix server run check`, `npm --prefix server test` and targeted world tests.
- [ ] Commit with `feat(server): add authoritative streamed world schema`.

## Task 7: Implement Client Cell Streaming

**Files:**
- Create: `client/scripts/world3d/WorldPartition3D.gd`
- Create: `client/scripts/world3d/WorldCell3D.gd`
- Create: `client/scripts/world3d/CellProxy3D.gd`
- Create: `client/tests/world_streaming_test.gd`
- Modify: `client/scripts/world3d/World3DController.gd`

**Interfaces:**
- `WorldPartition3D.set_descriptor(descriptor: Dictionary) -> void` loads static metadata.
- `WorldPartition3D.update_relevance(authoritative_position: Vector2) -> void` activates a camera cell ring and proxy ring.
- `WorldPartition3D.is_cell_loaded(cell_id: String) -> bool` is presentation state only.

- [ ] Test load/unload hysteresis, adjacent-cell ring, proxy ring and no duplicate activation.
- [ ] Implement cell resource loading by stable cell ID and relevance radius around authoritative position.
- [ ] Keep one adjacent proxy ring for orientation while unloading far render cells.
- [ ] Ensure unloaded client cells cannot create authoritative entities or mutate server state.
- [ ] Add loading placeholders and a safe transition when snapshots arrive before a cell finishes loading.
- [ ] Run headless streaming tests and a capture crossing at least four cell boundaries.
- [ ] Commit with `feat(client): stream 3d world cells by relevance`.

## Task 8: Expand District Content And Gameplay Readability

**Files:**
- Create: `client/assets/3d/generated/districts/`
- Modify: `client/data/world_map.json`
- Modify: `client/scripts/world3d/WorldCell3D.gd`
- Modify: `docs/ART_DIRECTION.md`
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- District descriptors provide stable `id`, `material_family`, `landmark`, `resource_profile`, `threat_profile`, `golden_path`, `detours` and `rest_points`.

- [ ] Create modular residential, clinic, industrial, fuel, park/canal, warehouse, commercial and perimeter kits.
- [ ] Place landmarks and route beats so each district has introduction, development and twist pacing.
- [ ] Add district-specific clutter, signs, damage, vegetation and material variants using the same asset contract.
- [ ] Add safe/unsafe visual language and colorblind-readable interaction/danger cues.
- [ ] Validate all cells for walkability, spawn safety, adjacency, visible landmarks and no empty traversal zones.
- [ ] Run a fixed-camera district capture suite and server world tests.
- [ ] Commit with `feat(world): expand districts and environmental storytelling`.

## Task 9: Performance, Mobile Fallback And Visual QA

**Files:**
- Create: `client/scripts/world3d/PerformanceTier3D.gd`
- Create: `client/tests/performance_budget_test.gd`
- Create: `docs/3D_VISUAL_QA.md`
- Modify: `client/scripts/world3d/WorldPartition3D.gd`
- Modify: `client/scripts/world3d/MaterialVariantLibrary.gd`
- Modify: `.github/workflows/ci-release.yml`

**Interfaces:**
- `PerformanceTier3D.detect() -> StringName` returns `mobile`, `desktop` or `fallback`.
- `PerformanceTier3D.apply(tier: StringName) -> void` changes LOD, shadows, clutter density and local-light count without gameplay changes.

- [ ] Add budget tests that count visible meshes, triangles, lights, materials and texture bytes in a deterministic test scene.
- [ ] Implement mobile/desktop tiers with the exact global budget values and a compatibility fallback for older devices.
- [ ] Add frame-time instrumentation and capture minimum/average/p95 frame time during cell traversal and combat.
- [ ] Tune LOD distances, MultiMesh clutter, light shadows, fog and texture resolution without reducing normal target to 30 FPS.
- [ ] Write manual QA checklist for eight directions, camera bounds, mobile touch overlap, materials, loading seams, combat, death and reconnect.
- [ ] Run Godot headless checks plus physical desktop, Android and iPhone profiling where hardware is available.
- [ ] Commit with `perf(client): enforce 3d mobile and desktop budgets`.

## Task 10: Switch Default Client And Complete Release Gate

**Files:**
- Modify: `client/project.godot`
- Modify: `client/scenes/Boot.tscn`
- Modify: `client/scenes3d/World3D.tscn`
- Modify: `docs/MVP.md`
- Modify: `docs/DEV_SETUP.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `README.md`

**Interfaces:**
- Default boot starts the 3D client only after all acceptance criteria pass; a documented debug flag can launch the 2D fallback during migration.

- [ ] Run full parse/import, server typecheck, 40+ unit tests, admin tests, integration tests with Nakama running, asset validation and release matrix checks.
- [ ] Verify server and client use the same world descriptor hash in a test environment.
- [ ] Verify two clients see the same authoritative players, zombies, items and containers while crossing cells.
- [ ] Verify persistence restart, reconnect, pickup race and stale container version across cell boundaries.
- [ ] Run manual desktop and mobile QA checklist; record frame time and memory against the target tier.
- [ ] Update version using `python3 scripts/version.py stamp`, run `make version-check`, create the next prerelease tag and publish only after assets are verified with `gh release view`.
- [ ] Commit with `feat(client): enable 3d isometric world by default`.

## Rollback

- Keep the existing 2D scene and renderer behind a debug launch flag until Task 10 passes.
- Revert the client default independently from server schema migration if 3D presentation fails.
- Keep the v1 world descriptor reader and old persisted position repair for at least one release cycle.
- Do not delete old assets or persistence fields during the migration.
- If mobile performance fails, apply the performance tier fallback before reducing the 60 FPS target.

## Plan Self-Review

- Spec coverage: renderer, fixed camera, eight-direction rig, Blender/GLB pipeline, material standards, 9x world, 8-10 districts, authoritative cells, persistence migration, streaming, budgets, validation and mobile QA are covered by Tasks 1-10.
- Placeholder scan: no unresolved implementation placeholders are used; all commands, interfaces and expected checks are specified.
- Type consistency: coordinate adapter, directional selector, world descriptor, partition and performance tier interfaces are defined before their consumers.
- Known environment constraint: Blender is not installed in the current workspace; Task 1 explicitly requires pinning/provisioning it before production GLB generation.
