# Deadworld Art Direction

## Identity

Deadworld is a readable isometric/2.5D survival game about making risky decisions in a dark, persistent city. The visual language must communicate three things before decoration: where the player can move, what can be interacted with, and what is dangerous.

The project uses a hybrid 2D pipeline: illustrated/generated directional PNG sprites for characters and hero props, plus procedural tileable surfaces and layered 2.5D world elements. External art packs and runtime dependencies are out of scope.

## World

- Camera: fixed orthographic-style isometric 2D view with a restrained lookahead toward aim direction.
- Layout: tile/grid-based surfaces with explicit walls, roads, debris and points of interest.
- Materials: wet asphalt, stained concrete, rusted metal, dirty plaster and desaturated vegetation.
- Silhouettes: walls and interactive objects use stronger value separation than decorative ground clutter.
- Depth: wall rear/top/front layers, contact shadows, occlusion and deterministic entity sorting provide 2.5D volume without complex 3D geometry.

## Lighting And Visibility

- The base scene is darkened with `CanvasModulate`.
- Local illumination uses Godot `PointLight2D` nodes and generated light textures.
- Light is gameplay-readable: the player, important rooms and interaction targets receive priority.
- Corners remain darker, but the player and nearby threats must never disappear into black.
- Flicker is subtle and reserved for unstable light sources; it must not impair target readability.

## Palette

Runtime colors live in `client/scripts/data/Palette.gd`. New visual code should use that palette instead of introducing isolated colors.

- Surfaces: charcoal green, concrete gray, dead olive and muted blue-gray.
- Danger: oxidized red and restrained blood red.
- Interaction: warm amber, used sparingly for target highlights and action feedback.
- Player: pale cold green so the controlled character remains readable against the world.
- UI: near-black panels, thin desaturated borders and high-contrast text.

## Entities And Items

- Player and zombies use 8 separately authored directional sprite views, not mirrored substitutes or rotated 3D models.
- Character frame standard is `96x128 px`, with shared bottom-center pivot, baseline, frame count and direction order across body/equipment layers.
- Character layers are composed in this order: shadow, back equipment, body, rear clothing, front clothing, weapon, status/effects and feedback.
- Zombies use posture, tint and state motion to distinguish idle, chase, attack and death.
- Hero props use cohesive base, material detail, wear, contact-shadow and highlight layers; they are not arbitrary PNGs stacked at runtime.
- World items use generated sprites/icons from `ItemIcons.gd`; the world sprite and UI icon share definition identity without requiring identical presentation.
- Quantity and weapon magazine state are secondary labels. The icon and silhouette carry primary recognition.
- Health bars, target rings and blood pools are feedback, not decoration; keep them short-lived and spatially close to the source.

## Interface

- The HUD is decision-oriented: health, ammunition, selected slot and immediate interaction are visible without opening a menu.
- Container inventory uses icon grids instead of debug text lists. Server-confirmed state remains explicit in the feedback line.
- Touch controls own the lower screen area on mobile. Hotbar and status panels must respect safe areas and avoid the virtual sticks.
- Menus use the same dark palette and restrained amber/green accents as the world. Avoid generic bright sci-fi panels, gradients and unrelated icon styles.
- Debug information must not be part of the player-facing HUD unless it is deliberately formatted as a gameplay status.

## Constraints

- Presentation-only camera and lighting changes must not alter authoritative Nakama world bounds, walls or collision semantics.
- Keep assets deterministic and generated/validated by `scripts/generate_assets.py`, `scripts/generate_sprite_sets.py` and `scripts/validate_sprite_assets.py`.
- Validate visuals with the headless smoke render, then manually check desktop and mobile profiles before release.
- Prefer readable contrast and stable frame time over extra particles, lights or post-processing.
