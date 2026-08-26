# Deadworld 3D Isometric World

> Status: design proposal for review
> Scope: renderer migration, generated 3D assets, character presentation, world expansion, authoritative world partition

## Goal

Replace the current 2D presentation with a grounded low-poly 3D renderer that presents a persistent, varied survival city through a fixed orthographic isometric camera. The player character must remain readable from all eight movement/aim sectors, and the world must expand to approximately nine times its current area without creating a client-only simulation.

## Decisions

- Renderer: Godot 4.7.1 3D using the existing `gl_compatibility` renderer.
- Camera: fixed orthographic isometric camera; no player-controlled orbit.
- Style: grounded low-poly; realistic proportions and material response with restrained geometry.
- Asset pipeline: deterministic Blender Python generators exporting GLB, with Godot import validation.
- Character: one rigged model with eight directional clips for idle, locomotion, attack, hit and death states.
- World: approximately 9x area, partitioned into 32 m cells and 8-10 districts.
- Authority: Nakama/TypeScript remains authoritative for position, collision, bounds, spawns, items, containers, zombies and persistence.
- Platform target: 60 FPS target on desktop and modern mid-range Android/iPhone devices around Snapdragon 7 Gen 1 / Apple A15 or newer. Older devices may use a reduced-quality fallback.
- Dependencies: no external runtime asset packs or runtime services. Blender is a build-time asset generator.

## Non-goals

- Free camera orbit or arbitrary camera pitch.
- Replacing Nakama with Godot multiplayer APIs.
- Rebuilding gameplay systems not required by the world/renderer milestone.
- AAA photorealism, motion capture or a large hand-authored asset library.
- Changing protocol semantics without a separate protocol review.

## Player Experience

The 30-second visual loop is: move through a readable space, identify a threat or resource, aim and act, read the result through animation/light/sound/UI, then choose whether to push deeper or retreat. Visual complexity must support this decision loop rather than obscure it. The primary design lenses are Miyamoto's feel-first principle, Miyazaki's environmental storytelling, and Ueda's restraint.

The first expanded world contains these district identities:

1. Safehouse district: low threat, orientation landmark and recovery route.
2. Residential blocks: narrow routes, interiors and domestic environmental storytelling.
3. Clinic and pharmacy: medical loot identity and high-value risk.
4. Industrial yard: open sightlines, metal materials and zombie exposure.
5. Fuel station and shops: landmark cluster and contested supplies.
6. Drainage canal and park: vegetation, water-adjacent materials and alternate traversal.
7. Warehouse strip: large interiors, cover and sound/visibility tension.
8. Damaged commercial center: dense props and high loot competition.
9. Outer settlement: lower density and transition into the perimeter.
10. Horde perimeter: high threat boundary and late-session pressure.

Every district has a landmark, golden path, optional detour, rest point, resource identity, threat profile and visual material family. The layout uses introduction, development and twist beats rather than empty scale. [-> design-level-design] [-> Miyazaki: environmental storytelling]

## Technical Architecture

### Godot scene structure

```text
World3D
├── WorldPartition
│   ├── Cell_<x>_<y>
│   ├── Cell_<x>_<y>
│   └── CellProxy_<x>_<y>
├── WorldEnvironment
├── DirectionalLight3D
├── CameraRig3D
├── Players3D
├── Zombies3D
├── Props3D
└── Effects3D
```

Presentation systems consume authoritative snapshots and cell descriptors. A missing client cell may hide or proxy a location, but cannot invent a player, item, collision surface or world state. The server owns world identity and simulation; the client owns rendering, interpolation, animation selection and visibility. [-> engineering-game-state-sync]

### Coordinate contract

- `1 Godot unit = 1 metre`.
- `1 world grid cell = 1 metre` for gameplay coordinates.
- Streaming cell = `32 x 32` gameplay metres.
- Every model uses the ground contact point as origin and a +Y up axis.
- Forward is +Z in Blender/Godot export; facing conversion is tested at import.
- Existing server X/Y coordinates map to Godot X/Z; Godot Y is height.
- Visual mesh collision proxies are never authoritative unless the matching server geometry is explicitly generated from the same source data.

### Camera and direction

The camera uses orthographic projection, fixed yaw, fixed pitch in the range 35-45 degrees, smooth follow, aim lookahead and loaded-cell bounds. The presentation layer quantizes movement/aim angle to the nearest 45-degree sector:

```text
N, NE, E, SE, S, SW, W, NW
```

The camera never rotates, so directional clips remain stable and predictable on desktop and touch platforms.

## Character And Animation Standard

Each character GLB contains one armature, one skeleton, modular mesh sockets and named clips:

```text
idle_<sector>
walk_<sector>
run_<sector>
attack_<sector>
hit_<sector>
death_<sector>
```

The initial production asset must include all eight sectors for idle, walk and attack; hit/death may share mirrored clips only after readability QA proves no silhouette ambiguity. Weapon and backpack meshes attach to named sockets. Animation state is selected from authoritative velocity, alive state, confirmed combat event and aim vector. No client animation result becomes gameplay truth.

Acceptance checks:

- silhouette remains identifiable at gameplay zoom in all eight sectors;
- feet contact the ground without visible sliding during walk;
- weapon socket does not detach during attack;
- transition from movement to idle completes without a one-frame T-pose;
- death animation is triggered only by authoritative dead state/event.

## Asset And Material Standards

### Naming

```text
dw_<domain>_<asset>_<variant>_<lod>.<ext>
```

Examples: `dw_char_survivor_a_lod0.glb`, `dw_prop_dumpster_rusted_lod1.glb`, `dw_mat_asphalt_wet_01`. Files use lowercase ASCII, no spaces and stable IDs.

### Texture and material rules

- PBR maps: base color, roughness, metallic, normal and AO when needed.
- Base color is sRGB; data maps are linear.
- No baked shadow in base color.
- No arbitrary transparent PNG stacking for ordinary surfaces.
- Decals are reserved for localized blood, signs, cracks and stains.
- Target texel density: 256 px/m desktop, 128 px/m mobile tier.
- Master texture sizes: 2048 for hero assets, 1024 for common props, atlas/tile sets for repeated environment materials.
- Material variation uses vertex color, UV variation and controlled shader parameters.
- Each district has 3-5 related material families rather than unique materials per object.

### Geometry

- LOD0 hero mesh, LOD1 gameplay mesh, LOD2 proxy mesh for every repeated or distant prop.
- Pivots sit at the world contact point; modular building pieces snap to the grid.
- Collision meshes use `dw_col_<asset>` naming and are generated separately from render meshes.
- Small repeated clutter uses MultiMesh where it does not affect interaction.
- Hero assets receive manual silhouette review; procedural generation does not excuse unreadable forms.

## World Partition And Persistence

The shared world descriptor becomes a versioned schema. The migration must preserve existing persisted positions and repair invalid positions deterministically.

```json
{
  "schemaVersion": 2,
  "worldId": "deadworld-main",
  "cellSize": 32,
  "bounds": {"minX": 0, "minY": 0, "maxX": 0, "maxY": 0},
  "cells": [],
  "districts": [],
  "walls": [],
  "spawnPoints": [],
  "pointsOfInterest": []
}
```

The server loads authoritative cell geometry and indexes walls/spawns/items by cell. The client requests or receives relevant cell descriptors based on the server-approved player snapshot and keeps a small adjacent proxy ring for navigation readability. Disconnect/reconnect, stale snapshots, two-player pickup races and persisted positions must be tested across cell boundaries. [-> engineering-postgres-game-schema] [-> security-and-hardening]

Migration notes:

- retain `schemaVersion: 1` reader compatibility during the migration window;
- map old coordinates into the new bounds without teleporting valid players unexpectedly;
- place invalid/obsolete positions at a deterministic safehouse fallback;
- do not delete old item/container records during visual migration;
- roll back by retaining the previous descriptor and migration flag until integration tests pass.

## Performance Budget

Initial budgets are measurable targets, not promises:

| Budget | Mobile | Desktop |
|---|---:|---:|
| Target frame rate | 60 FPS | 60 FPS |
| Visible geometry | 150k triangles | 300k triangles |
| Visible dynamic lights | 4 | 8 |
| Shadow-casting local lights | 1 | 2 |
| Visible unique materials | 24 | 40 |
| Scene texture memory | 256 MB | 512 MB |
| Active animated characters | 32 | 64 |

Streaming, LOD and lighting changes require measured frame-time evidence. The fallback reduces shadow quality, material variants, clutter density and far-cell detail before reducing resolution or frame target. [-> godot-master]

## Build And Validation Pipeline

1. Blender Python generator creates deterministic GLB meshes, rigs, animations and PBR texture sources.
2. Asset validator checks naming, scale, origin, forward axis, material channels, LOD presence and triangle budgets.
3. Godot imports GLB assets in a headless project scan.
4. World compiler validates cell adjacency, bounds, wall connectivity, spawn walkability and district metadata.
5. Visual smoke test renders fixed camera captures for all eight character sectors and representative districts.
6. Server tests validate schema migration, cell collision, spawn safety, persistence and cross-cell interactions.
7. Hardware checklist measures 60 FPS, memory, load time and thermal behavior on one modern Android and one iPhone.

## Phased Delivery

### Phase 1: 3D foundation

One test cell, camera rig, one survivor GLB with eight sectors, one zombie, one weapon, one prop family, material importer and frame-time instrumentation.

### Phase 2: complete vertical slice

One finished district with 10-15 props, three material families, lighting, fog, collisions, combat presentation, LOD and desktop/mobile smoke captures.

### Phase 3: authoritative migration

World schema v2, 9x bounds, cell indexing, spawn/collision migration, persistence repair, reconnect and cross-cell race tests.

### Phase 4: world expansion

8-10 districts, modular buildings, interiors, district-specific props, loot/spawn identity, cell streaming and proxy ring.

### Phase 5: polish and acceptance

Animation transitions, material variation, decals, light tuning, accessibility/readability pass, performance tuning and physical mobile acceptance.

## Acceptance Criteria

- Player is rendered as a rigged 3D model and readable in all eight sectors.
- Camera is orthographic, fixed and stable on desktop and mobile.
- At least one complete district demonstrates grounded low-poly materials without stacked flat PNG presentation.
- World descriptor supports 9x bounds, cells and district metadata.
- Nakama remains authoritative for position, collision, bounds, spawns, items and persistence.
- Old persisted positions and items survive the migration or receive deterministic safe fallback.
- Client cannot create authoritative entities by loading a cell.
- Asset validator rejects wrong scale, missing LOD, invalid material channels and over-budget meshes.
- Headless Godot parse/import, server tests and release checks pass.
- Hardware profiling documents 60 FPS target results on the agreed modern mid-range mobile tier.

## Open Risks

- Blender availability and GLB export determinism must be verified in CI or pinned build tooling.
- Godot 4.7.1 compatibility of the required 3D animation/import path must be tested before removing the 2D fallback.
- Ninefold world expansion may require a protocol/state payload review if cell descriptors become too large.
- 60 FPS on both Android and iPhone may require aggressive local-light and shadow restrictions.
- A procedurally generated model library can become visually repetitive; district-specific composition and manual hero-asset review are required.

## Review Gate

This document must be approved before implementation. After approval, create an implementation plan that decomposes the work into independently verifiable milestones. Do not begin the renderer migration, generate production assets, alter the world schema or change server authority before that plan exists.
