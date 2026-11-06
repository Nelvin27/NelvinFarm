# Clover Patch World Builder

This is a separate Godot developer project. It shares the game's voxel scenery, world renderer and cottage interior scene, and opens the game's layout directly when both project folders are siblings.

1. Import this folder's `project.godot` in Godot and press **F5**.
2. The editor opens `world/clover_valley.json` in the sibling **Clover-Patch-3D** project automatically. If the projects are in different folders, use **Open JSON** to select the game's file.
3. Choose **Select**, **Place**, or **Move selected** and click the world. The list also selects existing entities, including small or overlapping props. Scroll to zoom and middle-drag to pan.
4. Use **Apply properties** to edit sign text, path and pond dimensions, or fence length and orientation. You can move the cottage, seed market, bakery, and player spawn. The game needs one of each.
5. Use **Save** and restart the game to load the changes.

Choose **Mountain** to shape block terrain. Set its width, depth, and height under **Apply properties**. Dirt paths follow the terraces. See the [world authoring guide](../AGENTS.md) for AI-assisted and headless edits.

**Cottage preview** opens the shared interior scene for inspection. **Repair preview** switches between damaged and repaired furnishings. The cottage's internal furniture is authored in `cottage_interior.tscn`.

If you previously saved additions in the in-game editor, use **Import old additions** and select the old `clover_world.cfg` file from the game's Godot user-data folder, then save the merged JSON layout. On macOS, the default folder is `~/Library/Application Support/Godot/app_userdata/Clover Patch 3D`.

Select **Resident house** to place a home. Set its **Resident ID** (the filename in `village/characters/` without `.json`), street name, roof and front-yard detail, then apply properties. The game uses the front doorstep for the resident’s animated entrance and exit; during home hours the resident stays inside. Keep an open approach in front of the house and put homes on level ground. Moving a house updates the home stop on the next game launch. Work and leisure stops are edited in the resident's character JSON.
