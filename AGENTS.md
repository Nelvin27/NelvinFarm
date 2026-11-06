# Editing Clover Patch worlds

World Builder is the authoring tool for Clover Patch. Open `Clover-Patch-World-Builder/project.godot` in Godot 4.7 and run it with F5. It opens the game's shared `Clover-Patch-3D/world/clover_valley.json` automatically when the projects are siblings. Save in World Builder and restart the game to load the updated map.

## Build in World Builder

1. Use **Select** to inspect an object, **Place** to add one from the palette, and **Move selected** to reposition it. The entity list also selects things hidden under props. Scroll to zoom and middle-drag to pan.
2. Select **Mountain** in the palette and place its center. Select it and set **Width**, **Depth**, and **Height**, then choose **Apply properties**. Terrain columns are one unit wide, one unit deep, and rise in whole-block steps. Broad footprints give more walkable terraces.
3. Add overlapping dirt path strips to connect existing routes to the foothills and lookout. Place trees and other small props on individual terraces. Put ponds, large buildings, fences, and groups of farm plots on level ground because those objects have flat footprints.
4. Use **Undo** to back out a placement or property change. Save and check the route in-game from spawn. Keep navigation readable with paths, silhouettes, and props. Keep the 3D world free of text labels. Editor list names and on-screen interaction prompts are fine.

## Edit the same map data headlessly

When the editor is unavailable, edit the shared JSON directly and verify that World Builder can reopen it. The game and editor validate the same version-1 layout.

- `bounds` is `[min_x, min_z, width, depth]`. Each entity has a `kind` and `position` in `[x, y, z]` order. The authored Y is an offset above terrain. Use 0 for mountains and plot centers.
- A mountain has `kind: "mountain"`, a center `position`, `size: [width, depth]`, and `height` in `(0, 16]`. For example, `{"kind":"mountain","position":[-13.5,0,-26],"size":[23,23],"height":8}`. Overlapping mountains use the higher column.
- Keep one `spawn`, `cottage`, `seed_market`, and `bakery`. Preserve existing plot coordinates unless the task calls for moving them. Crop saves use those grid coordinates. Plot centers have half-integer X and integer Z.
- For new entity kinds or terrain rules, update the game and builder copies of `world_layout.gd` and the relevant rendering code together.

From the repository root, verify with the same Godot 4.7 executable used to run the game:

```powershell
godot --headless --path Clover-Patch-3D --import
godot --headless --path Clover-Patch-3D --script res://tests/valley_life_smoke.gd
godot --headless --path Clover-Patch-World-Builder --import
godot --headless --path Clover-Patch-World-Builder --quit-after 3
```

## Authoring villager routines

- Place one `resident_house` per character, with a unique `resident` matching the character JSON filename. The house faces positive Z; keep the area around `[x, z + 2]` walkable and connect the lot to the surrounding town. Use `street` for journal directions and `style` (0–3), `color`, `trim`, and `detail` for appearance.
- Read the resident's `character.backstory` and `character.connections` before choosing their neighbors. Store the reason for their home location in `routine.home_context`. In `routine`, set `depart`, `break_at`, and `home` as ascending decimal clock hours. The `work` and `leisure` stops are `[x, z]` points on level, connected ground. Give each stop an activity and a recognizable location in the journal. An optional `story_stop` can replace leisure after that resident's testimony or after the hearing.
- If a road, house, or landmark moves, update any affected routine coordinates and journal directions, then run the village route smoke checks.
