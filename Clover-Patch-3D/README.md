# Clover Patch 3D

A small chibi farming game built in Godot 4 with the Compatibility renderer and a 1920 × 1080 (16:9) game viewport.

## 1. Open the farm

In the Godot Project Manager, select **Import**, pick this folder's `project.godot` and open it. Give Godot a moment to import the GLB models, then press **F5**. The main scene is built by script when the game starts.

## 2. Grow your first turnip

Walk with **WASD** or the **arrow keys** and orbit the camera with the **mouse**. Face a nearby garden plot to highlight it. Press **E** with the **Hoe** equipped to till. Press **E** again to plant the equipped seed, then switch to the **Watering Can** and press **E** to water. The **Sickle** is required to harvest spinach and fodder grass. Pick other ripe crops with **E**, regardless of the tool you are holding. A turnip planted and watered on Spring 1 is ready on Spring 5 if you water it every day. The plot tooltip shows the number of watered nights remaining.

The clock advances while you play. Follow the farm lane southwest to the cottage. Press **E** by the door to enter, and press **E** beside the bed once fatigue reaches **65%**. Sleeping starts the next morning and advances watered crops. Use the doormat to leave. Press **E** near the outside repair sign to fix the roof and window for **10 coins**. The same upgrade replaces the damaged floorboard and adds a rug and curtains inside.

Fatigue stages are **Rested**, **Getting tired** (30%), **Tired** (65%), and **Exhausted** (90%). The food meter warns when you're **Hungry** (below 45%) or **Very hungry** (below 20%). Hunger and fatigue can slow walking. At 90% fatigue, farming, shopping, equipping seeds, and cottage repairs are blocked. You can still walk home, use the door, sleep, or eat. Bread reduces fatigue by 22 points. Edible crops reduce it by 14.

## 3. Trade at the seed market

You start with five turnip seeds, six coins, and two bread rations. Visit the striped stall by the home garden and press **E** to see the current season's seeds, first harvest days, and regrowth times. Buying a seed equips it. Select an in-season seed in the bag and choose **Equip seed**. Use **Sell harvest** to sell all the produce in your bag. Keep some food back by eating it before you sell.

Spring, Summer, Fall, and Winter each last 30 days. Ordinary crops wilt when their planting season ends. Winter has no ordinary outdoor seeds, and fodder grass goes dormant. Fodder is an extra Clover Patch crop that grows without watering on a one-night timer. Fruit trees are scenery.

Crop timing reference: [Spring](https://fogu.com/sos3/farm/spring_crops.html), [Summer](https://fogu.com/sos3/farm/summer_crops.html), [Fall](https://fogu.com/sos3/farm/fall_crops.html). The reference counts planting as day 1. Clover Patch uses its own coin prices, offers seasonal seeds without the source game's unlock requirements, and uses original simple crop models.

## 4. Food shop, inventory, and testing

- Visit the **Valley Bakery** southeast of the home garden and press **E** by its stall. Bread costs **2 coins** and restores 35 food when eaten.
- Press **I** to open your bag. Drag stacks between slots on the current page. Matching stacks merge up to 64, and different items swap positions. Select an illustrated item slot to equip a tool or seed, or eat that item. Select the equipped tool again to put it away. Stacks hold up to 64 items, and more pages appear as your bag fills.
- Press **F7** to open or close the test menu. It can add coins, set food and fatigue levels, set the clock to night, advance one day, or take you directly to the cottage interior.
- **E** prompts appear only within reach of the current plot, shop, door, bed, or repair sign.

## 5. Pause and settings

Press **Esc** during play to pause the world, including the clock, hunger, and fatigue. Select **Settings** to change mouse sensitivity, invert vertical look, adjust brightness, or switch fullscreen on or off. Open **Graphics** for 720p, 900p, or 1080p 3D rendering, Off/2×/4× MSAA, sun shadows, and VSync. The HUD keeps its 1080p base layout. Open **Audio** to set Master, Music, and Sound Effects volume independently. Settings apply immediately and are saved locally. Press **Esc** again or choose **Resume** to return to the farm.

## 6. Explore Clover Valley

- Follow Market Lane east past the seed stall and bakery to find 24 more plots in the East Garden.
- Take the north branch from Market Lane to the Apple Orchard.
- Take the south branch to Willow Pond. Its path continues east to Clover Meadow.

## 7. Edit the world with the developer tool

The standalone **Clover Patch World Builder** project edits this game's `world/clover_valley.json`. The tool opens that file automatically when both project folders are siblings. Edit, save, and restart the game to test the result. The game reads this layout at startup and has no editor in its menus.

If exporting the game from Godot, include `*.json` in the export preset's non-resource file filter so the world layout is packaged.

## 8. Make a small change

Open `farm.gd` and change `GOAL` from 5 to 3. The HUD and harvest message will both pick up the new goal when you run the game again.

To change the look, try a different hat color in `_build_farmer()`. The hat brim uses the color `#f3cd79`. Trees and flowers come from imported models in `assets/`.

## Asset audit

| Asset group | Clover Patch treatment |
| --- | --- |
| Terrain, soil, paths, and water | Original 16 × 16 repeating textures with nearest filtering. The valley layout and its functional plot grid are shared with the World Builder. |
| Trees, flowers, and orchard fruit | Original stepped block models replace the earlier imported models. |
| Cottage, shops, fences, and signs | Block-built props, pixel-textured timber, and a stepped cottage roof with separate damaged and repaired states. |
| Farmer, tools, and crops | Block silhouettes retain the farmer's straw hat and walk animation. Crop shapes distinguish leafy crops, flowers, and produce. |
| Inventory and menus | Fifty original item icons are redrawn on a 16 × 16 pixel grid. Menus use squared panel corners. |
| Audio | Original Clover Patch music and sound effects carry over from the previous build. |
