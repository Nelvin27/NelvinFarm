# Editing Clover Patch worlds

The valley map is `Clover-Patch-3D/world/clover_valley.json`, and it is generated. Change the layout in `tools/world/build_world.py`, run the script, and restart the game. Don't hand-edit the JSON; the next build overwrites it. [world/guide.md](Clover-Patch-3D/world/guide.md) describes the town, its anchors, and the story behind each neighborhood.

## Build, check, and preview

From the repository root:

```bash
python3 tools/world/build_world.py
cd Clover-Patch-3D
godot --headless --import
godot --headless --script ../tools/world/check_world.gd
godot --headless --script ../tools/world/audit_world.gd
godot --script ../tools/world/render_world.gd -- overview bread_lane council_row
godot --headless --script res://tests/valley_life_smoke.gd
```

- `build_world.py` writes the map deterministically and reports Python-side problems, such as a fence or path on a slope.
- `check_world.gd` loads the real game and checks level ground for flat objects, routes from spawn to every landmark and picnic table, and each resident's walk from home to work, leisure, story stop, and back. It exits non-zero on failure.
- `audit_world.gd` walks the map in 5×5 cells and lists visual problems: trees or props straddling block ledges, canopies pushed into terrain walls, trees clipping each other or buildings, flowers and lanterns on paths or in ponds, and dead-end paths. It exits non-zero on any finding. Add `-- --verbose` for a per-cell list.
- `render_world.gd` needs a window. It saves PNG previews to `tools/world/renders/` (ignored by git). Pass named views or a custom `x,z,distance,pitch,yaw`, plus `--hour`, `--season`, and `--rain` to preview night, the seasons, and weather.

## Layout rules

- `bounds` is `[min_x, min_z, width, depth]`. Each entity has a `kind` and `position` in `[x, y, z]` order. The authored Y is an offset above terrain.
- A mountain has a center, `size: [width, depth]`, and `height` in `(0, 16]`. Terrain rises in whole-block steps; overlapping mountains use the higher column. An optional `falloff` (0.5–4, default 2) shapes the profile: lower values give broad shoulders and wide summits. The outer range is built in the builder's "Mountain range" section from crest, ridge, and foothill layers, and pieces that would lift ground the town needs flat are skipped. Wall faces above height 7 render as stone, and tops at 11 and above as snow. `elevation()` in the builder mirrors `world_layout.gd`. If you change one, change both.
- Keep one `spawn`, `cottage`, `seed_market`, and `bakery`. Never move farm plots: crop saves use their grid coordinates. Plot centers have half-integer X and integer Z.
- Put paths, ponds, houses, fences, picnic tables, and plots on level ground. Villagers only walk level, unobstructed tiles.
- Houses face positive Z. Keep `[x, z + 2]` clear for the door. A house with an empty `resident` is allowed and stays empty.
- A `pond` takes `fish` (`perch`, `trout`, or `carp`) and an optional `rare` Moonfin chance. Its dock is built on the north bank.
- A `forage` spot takes `item` (`berries`, `mushroom`, or `shell`). Seasons and daily refills are handled in `farm.gd`. Put spots on level ground the villagers' grid can reach; `check_world.gd` tests each one.
- `bush`, `rock`, and `tuft` are batched ground cover with optional `scale`, `yaw`, and (tufts) `color`. The builder's fill pass adds them to any bare 5×5 cell.
- A `stream` is a water strip (`size`) that blocks movement. A `bridge` fills a gap between two stream segments and takes `axis` (`x` or `z`, the walking direction) and `water` (the size of the water drawn under it).
- `well` and `bell` are the wishing well and town bell; keep one of each. A `dig` is a buried-find spot; four are active each day. A `landmark` is an invisible named place with `name` and `radius` that the player discovers by walking in.
- A `sign` takes `text`, shown when the player reads it. Text starting with `@` makes it a petition board with the daily notice. The interactions themselves live in `valley_interactions.gd`.
- A `ruin` is a flooded cottage foundation (optional `yaw`), and `floodgate` sits across a `stream`. Both are solid.
- A 1×1 `mountain` makes a single raised column. The standing stones use this.
- New entity kinds need a validator entry in `world_layout.gd` and rendering in `farm_scenery.gd`.
- Keep the 3D world free of text labels. A sign's `label` is only a note in the JSON.

## Authoring villager routines

- Give each resident one `resident_house` whose `resident` matches their character JSON filename. Use `street` for journal directions and `style` (0–3), `color`, `trim`, and `detail` for appearance.
- Read `character.backstory` and `character.connections` before choosing neighbors. Store the reason for the home in `routine.home_context`. `depart`, `break_at`, and `home` are ascending clock hours. `work`, `leisure`, and the optional `story_stop.at` are `[x, z]` points on level, connected ground with a recognizable place name for the journal.
- When a road, house, or landmark moves, update the affected routine coordinates and journal text, then run `check_world.gd`.
