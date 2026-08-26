# Deadworld 2D/2.5D Isometric World

> Status: approved design
> Scope: layered sprite renderer, directional character views, procedural 2.5D world presentation, authoritative world expansion

## Goal

Replace the current technical 2D presentation with a coherent hybrid 2D/2.5D isometric style inspired by the readability principles of Zombix Online, without copying its assets or identity. The player, zombies and important props use complete eight-direction sprite views and layered compositing; depth comes from isometric tiles, occlusion, shadows, scale and deterministic sorting rather than complex 3D geometry.

## Decisions

- Renderer: Godot 2D `CanvasItem` pipeline; no `MeshInstance3D`, `Skeleton3D`, GLB or runtime 3D renderer.
- Camera: fixed orthographic-style isometric 2D camera with smooth follow and aim lookahead; no player-controlled orbit.
- Style: hybrid 2D; hand-painted/illustrated directional sprites for characters and hero props, procedural tileable materials and layered props for the environment.
- Character resolution: `96x128 px` per frame and direction, 8 directions, 6-8 frames per state.
- Character composition: separate body, clothing, weapon, backpack, shadow and effect layers with shared canvas/pivot/frame contract.
- Direction: eight separately authored views; no mirroring as a substitute for a missing direction.
- World: approximately 9x area, partitioned into 32 m cells and 8-10 districts.
- Authority: Nakama/TypeScript remains authoritative for position, collision, bounds, spawns, items, containers, zombies and persistence.
- Platform target: 60 FPS on desktop and modern mid-range Android/iPhone devices around Snapdragon 7 Gen 1 / Apple A15 or newer.
- Dependencies: no external runtime asset packs or runtime services.

## Visual Principles

Zombix Online is a reference for directional readability, isometric 2D/2.5D composition, clear silhouettes and layered equipment. Deadworld keeps its own grounded post-apocalyptic palette, procedural generation, world layout and UI language. The target is not a pile of PNGs: every sprite layer is authored for the same light direction, perspective, baseline, palette and material treatment.

The 30-second visual loop is: move through a readable space, identify a threat or resource, aim and act, read the result through animation/light/effects/UI, then choose whether to push deeper or retreat. [-> design-game-design-fundamentals] [-> Miyamoto: feel-first]

## Sprite Contract

### Directions and states

```text
N, NE, E, SE, S, SW, W, NW
idle, walk, run, attack, hit, death, interact
```

### Naming

```text
dw_<domain>_<asset>_<layer>_<state>_<direction>_<frame>.<ext>
```

Examples:

```text
dw_char_survivor_body_idle_ne_03.png
dw_char_survivor_weapon_pistol_attack_e_05.png
dw_zombie_runner_body_walk_sw_02.png
dw_prop_dumpster_base_idle_s_00.png
dw_tile_asphalt_wet_03.png
```

### Frame rules

- Character frame: `96x128 px`.
- Shared canvas size for every layer in a character set.
- Pivot: bottom-center at the feet contact point.
- Identical baseline, frame count and direction order across all layers.
- Atlas padding: minimum 2 px; no bleeding at tile boundaries.
- No unintended horizontal mirroring.
- No alpha halos, opaque background pixels or baked UI marks.
- Pixel filtering/import mode is set consistently by the project, not per asset.

### Layer order

```text
ground shadow
back equipment
body
rear clothing/arm
front clothing/arm
weapon
damage/status overlay
muzzle/hit effect
selection/health feedback
```

Equipment layers may be absent, but when present they must use the same frame geometry and pivot. Runtime compositing changes presentation only and never changes item ownership or authoritative state.

## 2.5D World Presentation

- World grid remains one gameplay metre per cell.
- Ground uses isometric tile variants with edge-aware transitions and deterministic texture variation.
- Walls have separate rear, top, front and shadow layers; front layers can occlude lower character pixels.
- Props are cohesive illustrated compositions with base, material detail, wear/damage, contact shadow and interaction highlight layers.
- Y-sort/depth sorting is deterministic using world position and stable entity ID tie-breakers.
- Foreground occluders fade or cut out only when they hide the controlled player, preserving navigation readability.
- Scale variation is bounded and driven by stable seed, never random per frame.
- Lighting is created with CanvasModulate, limited PointLight2D masks, shadow sprites and material value variation.
- Distant cells use reduced clutter and proxy layers; they do not create authoritative entities.

## World And Districts

The expanded world is approximately 9x the current area and uses 32 m streaming cells. It contains 8-10 visually and mechanically distinct districts:

1. Safehouse district: orientation landmark, recovery route and low threat.
2. Residential blocks: narrow routes, interiors and domestic storytelling.
3. Clinic and pharmacy: medical loot identity and high-value risk.
4. Industrial yard: open sightlines, metal materials and exposure.
5. Fuel station and shops: landmark cluster and contested supplies.
6. Drainage canal and park: vegetation, water edge and alternate traversal.
7. Warehouse strip: large interiors, cover and visibility tension.
8. Damaged commercial center: dense props and high loot competition.
9. Outer settlement: lower density transition area.
10. Horde perimeter: high threat boundary and late-session pressure.

Every district has a landmark, golden path, optional detour, rest point, resource identity, threat profile and material family. Layout pacing follows introduction, development and twist beats; scale alone is not content. [-> design-level-design] [-> Miyazaki: environmental storytelling]

## Authoritative World Contract

The shared descriptor becomes a versioned cell-based schema:

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

The server indexes walls, spawns, items and containers by cell and remains the source of truth. The client receives authoritative snapshots, loads the relevant visual cell ring and may show adjacent proxy layers. Client loading cannot create entities, grant items or mutate collision. Existing persisted positions receive deterministic safehouse fallback when they are outside the new walkable bounds. [-> engineering-game-state-sync] [-> engineering-postgres-game-schema]

## Performance Budget

| Budget | Mobile | Desktop |
|---|---:|---:|
| Target frame rate | 60 FPS | 60 FPS |
| Active sprite layers | 180 | 360 |
| Visible animated characters | 32 | 64 |
| Active PointLight2D nodes | 4 | 8 |
| Visible texture memory | 256 MB | 512 MB |
| Active world cells | 9 | 25 |

The fallback reduces distant cell detail, clutter density, animation frame rate for non-critical entities, light count and texture resolution before reducing the frame target. Sprite atlases, pooling and no per-frame allocations are required. [-> godot-master]

## Asset Validation

The deterministic generator/validator must check:

- stable lowercase ASCII naming;
- expected `96x128` character dimensions;
- identical layer canvas/pivot/frame/direction contract;
- atlas padding and alpha integrity;
- no missing required directional view;
- no unintended mirrored direction;
- stable palette/material metadata;
- tile dimensions and edge compatibility;
- sprite/layer count and memory budgets;
- deterministic output hash for the same seed.

## Delivery Phases

1. Sprite contract, atlas validator and deterministic generation fixtures.
2. Complete survivor set: body, clothing, pistol, backpack, shadow and effects in eight directions.
3. Complete zombie set with idle/walk/attack/hit/death readability.
4. Runtime layered compositing and eight-sector animation selector.
5. 2.5D depth sorting, occlusion, wall layers, shadows and light masks.
6. One complete district with natural tile/material/prop treatment.
7. Authoritative schema v2, 9x bounds, cells, district metadata and persistence migration.
8. Client cell streaming and adjacent proxy ring.
9. Remaining 7-9 districts, landmarks, route pacing, clutter and resource/threat identity.
10. 60 FPS profiling, visual QA, desktop/mobile acceptance and default client switch.

## Acceptance Criteria

- Player, zombies and hero props use cohesive eight-direction 2D/2.5D sprites.
- Character layers align with identical pivot, baseline, frame count and direction order.
- Player is visually readable from all eight directions without mirrored substitutes.
- World depth is communicated through tiles, occlusion, shadows, scale and sorting, not complex 3D geometry.
- At least one district demonstrates natural material and prop treatment without arbitrary PNG stacking.
- World descriptor supports 9x bounds, cells, districts and POIs.
- Nakama remains authoritative for collision, bounds, spawns, entities and persistence.
- Old persisted positions/items survive migration or receive deterministic fallback.
- Asset validator rejects contract, naming, alpha, budget and determinism failures.
- Godot parse/import, server tests, visual captures and release checks pass.
- Hardware profiling documents the 60 FPS target on the agreed modern mid-range mobile tier.

## Review Gate

This approved design is implemented through the companion plan. The old 3D design and plan are obsolete and must not be used as implementation instructions.
