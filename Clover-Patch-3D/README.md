# Clover Patch 3D

A small chibi farming game built in Godot 4 with the Compatibility renderer and a 1920 × 1080 (16:9) game viewport.

## 1. Open the farm

In the Godot Project Manager, select **Import**, pick this folder's `project.godot` and open it. Give Godot a moment to import the GLB models, then press **F5**. The main scene is built by script when the game starts.

## 2. Grow your first turnip

Walk with **WASD** or the **arrow keys** and orbit the camera with the **mouse**. Hold **Shift** to run. Face a nearby garden plot to highlight it. Press **E** (or **left-click**) to till it, again to plant the equipped seed, and again to water. The farmer picks up the right tool for each job: the **Hoe** for bare soil, the **Watering Can** for a planted crop, and the **Sickle** for spinach and fodder grass. Hold **E** while walking along a row to work each plot once as you pass it. A turnip planted and watered on Spring 1 is ready on Spring 5 if you water it every day. The plot tooltip shows the number of watered nights remaining.

The clock advances while you play. Follow the farm lane southwest to the cottage. Press **E** by the door to enter, and press **E** beside the bed after **18:00**, or earlier once fatigue reaches **65%**. Sleeping starts the next morning and advances watered crops. Use the doormat to leave. Press **E** near the outside repair sign to fix the roof and window for **10 coins**. The same upgrade replaces the damaged floorboard and adds a rug and curtains inside.

Fatigue stages are **Rested**, **Getting tired** (30%), **Tired** (65%), and **Exhausted** (90%). The food meter warns when you're **Hungry** (below 45%) or **Very hungry** (below 20%). Hunger and fatigue can slow walking. At 90% fatigue, farming, shopping, equipping seeds, and cottage repairs are blocked. You can still walk home, use the door, sleep, or eat. Bread reduces fatigue by 22 points. Edible crops reduce it by 14.

## 3. Trade at the seed market

You start with five turnip seeds, six coins, and two bread rations. Visit the striped stall by the home garden and press **E** to see the current season's seeds, first harvest days, and regrowth times. Buying a seed equips it. Select an in-season seed in the bag and choose **Equip seed**. Use **Sell harvest** to sell all the produce in your bag. Check the journal for deliveries before selling everything.

Spring, Summer, Fall, and Winter each last 30 days. Ordinary crops wilt when their planting season ends. Winter has no ordinary outdoor seeds, and fodder grass goes dormant. Fodder is an extra Clover Patch crop that grows without watering on a one-night timer.

Crop timing reference: [Spring](https://fogu.com/sos3/farm/spring_crops.html), [Summer](https://fogu.com/sos3/farm/summer_crops.html), [Fall](https://fogu.com/sos3/farm/fall_crops.html). The reference counts planting as day 1. Clover Patch uses its own coin prices, offers seasonal seeds without the source game's unlock requirements, and uses original simple crop models.

## 4. Food shop, inventory, and testing

- Visit the **Valley Bakery** southeast of the home garden and press **E** by its stall. Bread costs **2 coins** and restores 35 food when eaten.
- **E** or **left-click** works the highlighted plot or uses the nearby object. **F** or **right-click** uses the selected hotbar item. You can still pick a tool yourself with **1** (empty hands), **2** (Hoe), **3** (Watering Can), and **4** (Sickle).
- **Shift + mouse wheel** zooms the camera in and out.
- When the equipped seed runs out, the farmer switches to another in-season seed from the bag.
- Press **Tab** to free the cursor. Click a hotbar slot, Bag, Journal, Pause, or the nearby action prompt. Press **Tab** again or click the world to return to camera control.
- The hotbar mirrors the first 12 slots of the Farm Bag. Scroll the mouse wheel or click a slot to select it. Selecting a tool or seed equips it when available. Press **F** to use the selected item. Drag stacks in the bag to reorder the hotbar.
- The backpack starts with 12 slots. Buy expansions in the Farm Bag to unlock 24 slots for **30 coins**, then 36 slots for **80 coins**. Older stacks beyond the unlocked rows and guaranteed rewards that exceed capacity remain accessible on the Reserve page.
- Press **I** to open your bag. Drag stacks between slots on the current page. Matching stacks merge up to 64, and different items swap positions. Select an illustrated item slot to equip a tool or seed, or eat that item. Select the equipped tool again to put it away. **Right-click** or **double-click** a slot to use it at once, and press **Sort bag** to merge split stacks and put tools and seeds first. Stacks hold up to 64 items, and more pages appear as your bag fills.
- Press **F7** to open or close the Test menu. **Resident testing** lets you set exact favor, try the date and partnership thresholds, reset the selected resident’s romance or daily gift state, and stock their favorite and disliked gifts. You can open dialogue without earning the daily visit bonus, jump to the resident during work hours, or watch them leave home. The main menu still has the farm, time, and cottage shortcuts.
- **E** prompts appear only within reach of something you can use, such as a plot, shop, door, bed, sign, or tree.

## 5. Pause and settings

Press **Esc** during play to pause the world, including the clock, hunger, and fatigue. Select **Settings** to change mouse sensitivity, invert vertical look, adjust brightness, or switch fullscreen on or off. Open **Graphics** for 720p, 900p, or 1080p 3D rendering, Off/2×/4× MSAA, sun shadows, and VSync. The HUD keeps its 1080p base layout. Open **Audio** to set Master, Music, and Sound Effects volume independently. Settings apply immediately and are saved locally. Choose **Save farm** to save immediately, or sleep to autosave at dawn. The game loads your last save on launch. Press **Esc** again or choose **Resume** to return to the farm.

## 6. Explore Clover Valley

- Follow Market Lane east through the market square and past the fenced East Garden with 24 more plots. The main street carries on east over Highwater Brook to Reedmere Walk.
- Take Council Row north out of the square. A short walk up is the plaza with the petition boards and the town bell, and Iona's house stands at its head under the hill.
- The orchard aisle leads east from the plaza into the fenced Apple Orchard. In fall, look for red apples on trees and press **E** nearby to pick one. Different trees bear fruit each morning. Eat the apples from your bag, sell them at the market, or ship them.
- The Hilltop Trail leaves the plaza, loops behind the orchard, and comes back down to the main street.
- Pond Lane runs from the cottage past Willow Pond to the bakery. At the dock on the pond's north bank, press **E** to cast. Wait for the bite cue, then press **E** or choose **Reel in** before the meter empties. Pond Perch goes into your bag and can be eaten, cooked, sold, or shipped.
- Bread Lane continues east from the bakery to the Village Commons, with its great oak, bunting, and picnic tables. Mara's house is the first on the lane. Clover Meadow opens to the south.
- Highwater Brook comes down from the Highbank hills, crosses the main street, and empties into Clover Lake. It can only be crossed at its four bridges. The clinic stands on its west bank. On the east bank, the Old Gate Route follows the water north to the old floodgate, and the foundations of three cottages lost to the flood stand beside Reedmere Walk.
- Reedmere Walk leads from the east end of the main street to Clover Lake and Reedmere pond, each with its own fishing dock. A path loops all the way around Clover Lake.
- Follow the lantern trail north from the home farm to the summit lookout on the north peak, where a table and lanterns overlook the valley, or take the short trail onto the east knoll. Walk toward a higher block to hop up, or walk off a ledge to drop to the lower terrace.
- Not every place has a path. Look for a quiet glade deep in the northern woods, a ring of standing stones in the south meadow, and a hidden pond in the southern woods.

### Things to touch

Press **E** when the prompt appears. Plots, shops, residents, and fishing docks take priority when they are also in reach.

- **Signs** can be read. The petition boards on Council Row post a daily notice: tomorrow's weather, a rumor about a buried find, and a fishing tip.
- **Trees** can be shaken. Once a day each tree may drop berries (spring and summer), a chanterelle or apple (fall), or a few coins. Bushes rustle as you brush past.
- **Ducks** take bread from any pond bank. The first feeding of the day raises the Moonfin chance to 35% everywhere until morning.
- **The wishing well** in Market Square takes one coin, once a day. A wish may pay coins back, bring fishing luck, hint at a buried find, or ease fatigue.
- **The town bell** on Council Row rings and tells the time.
- **Buried finds** sparkle in four places each day. Dig them up with the Hoe for coins, a River Shell, seeds, or a lost coin purse.
- **Places** are discovered by walking into them. Each of the 16 pays 2 coins, and finding them all pays 25 more. The Collection page keeps count.

Shaking trees and digging are tiring work and are blocked when you are exhausted. Everything here is saved with the farm and resets each morning, except discovered places.

### Foraging and fishing

- Wild Berries grow on bushes at grove edges in spring and summer, Chanterelles come up in shady woods in fall, and River Shells wash up on pond banks until winter. Press **E** beside a find to gather it. About half the spots refill each morning, and each gives one find per day.
- Each pond has its own catch: Pond Perch at Willow Pond, Lake Trout at Clover Lake, and Reed Carp at Reedmere. The rare Moonfin bites at dusk and in the rain, and more often at the hidden pond.

### Night and weather

Each season has its own music, and the theme changes on the first morning of a new season. Lanterns pool warm light on the paths from dusk to dawn, and fireflies drift over Clover Meadow on clear summer nights. Rain leaves puddles on the roads. Leaves turn orange in fall, and winter frosts the trees and settles snow on the roofs.

## 7. Change the world

`world/clover_valley.json` is generated by `tools/world/build_world.py` at the repository root. Change the layout in that script, run it, and restart the game; the game reads the layout at startup. Saved crops follow their plot coordinates, so moving or deleting a plot removes its crop from the next save. See the [world authoring guide](../AGENTS.md) for the build, check, and preview commands.

If exporting the game from Godot, include `*.json` in the export preset's non-resource file filter so the world layout is packaged.

## 8. Forecasts and valley deliveries

Open the **Valley Journal** with **J**. It shows today's weather, tomorrow's forecast, and three deliveries for the current season. Select an available delivery to trade the listed quantity directly from your bag for coins. Deliveries can be completed once per season and reset when the season changes.

Rain waters planted crops for the coming night, including seeds you plant that day. Winter snow is visual. The save keeps your crop growth, inventory slots, equipment, cottage repairs, delivery progress, and location. It lives in the local Godot user data folder as `farm.cfg`.

The journal also offers one-time rewards at **5, 20, and 50 total crops harvested**. Claim them in order for 8, 18, and 35 coins. Harvests from existing saves count.

Buy **Watering Can +** from the journal for **25 coins**. Equip it with **3** as usual. When you water a dry crop, the upgraded can also waters eligible crops on the four plots directly beside it. The upgrade and claimed rewards are saved with the farm.

The **Shipping Bin** stands to the left of the cottage door. Press **E**, choose a kind of produce, and send it to the bin. The menu shows the expected payout, and you can return the shipment to your bag before sleeping. Shipments sell at the same prices as the market and pay the next morning. Pending shipments survive a manual save.

## 9. Cook at the cottage

After repairing the cottage, press **E** near the stove. Garden Stew uses turnip and bread, Orchard Toast uses apple and bread, and Pan-Seared Perch uses a fish from Willow Pond. Meals are eaten as soon as you cook them and restore more food and fatigue than their raw ingredients.

See the [mechanics comparison](MECHANICS.md) for the Stardew Valley and Back to Nature systems that informed Clover Patch and the work that remains.

## 10. Collection and skills

Press **J** and choose **Collection and skills**. The collection has nine specimens. Donate the three valley classics, a Pond Perch, a Moondrop Flower, and an Orchard Apple, for **18 coins**, then fill the board with the other fish and forage finds for a **40-coin** bonus. Each specimen can be donated once.

Successful plot work, fish catches, and prepared meals build their own skills. Higher Farming levels reduce fatigue from plot work. Fishing levels widen the reel window. Cooking levels make meals relieve more fatigue. The journal shows your progress, and both the collection and skills are saved with the farm.

## 11. Meet the village

Press **E** near a resident to talk. Visit Market Lane, the west bank of Willow Pond, the orchard edge, and Clover Meadow to meet all 32. Residents move within their districts as the day progresses. Talk regularly, or choose bread or produce from your bag as a gift. Each resident has their own taste.

Press **J** and choose **Village and story** for witness locations and the supper schedule. The farmer's choices shape the supper and the flood hearing. Ask residents about either event to hear their reactions. Six adults have optional romance routes as your favor grows. See the [story and character guide](village/STORY.md) for story spoilers and character editing.

Starting on day 2, **Village and story** lists a random town event and its host each morning. Talk to that resident and pick one of two responses before going to bed. Either response earns 3 favor. The game rotates through 32 events before repeating them.

Press **E** beside a picnic table to spend 30 in-game minutes recovering up to 12 fatigue. Look for tables by the bakery, in the meadow and orchards, and along the ponds. The trail west of the cottage leads to the old pass, where a rockslide closed the way through the ridge.

## 12. Project layout

`farm.tscn` is the main scene. Its node tree holds the environment, sun, follow camera, player, garden plots, cottage interior, effects, audio, pause screens, and every menu, and their signals are connected in the scene. `farm.gd` owns the game state and handles those signals.

- `player/`: the farmer model (`player.tscn`), its movement and animation (`player.gd`), and the orbit camera (`follow_camera.gd`).
- `ui/`: the HUD, the menus (each one inherits `action_menu.tscn`), the inventory grid, the pause and settings screens, and the menu and HUD themes (`menu_theme.tres`, `hud_theme.tres`).
- `effects/`: the garden plot, bobber, plot marker, and audio scenes.

The valley scenery, terrain, villagers, and houses are still built in code from `world/clover_valley.json` and the village data, so rebuilding the map with `tools/world/build_world.py` needs no scene changes.

## 13. Test the game

From this folder, run `godot --headless --import` followed by `godot --headless --script res://tests/valley_life_smoke.gd`. The smoke test uses a temporary save.

## Asset audit

| Asset group | Clover Patch treatment |
| --- | --- |
| Terrain, soil, paths, and water | Original 16 × 16 repeating textures with nearest filtering. The valley layout and its functional plot grid come from `tools/world/build_world.py`. |
| Trees, flowers, and orchard fruit | Original stepped block models replace the earlier imported models. |
| Cottage, shops, fences, and signs | Block-built props, pixel-textured timber, and a stepped cottage roof with separate damaged and repaired states. |
| Farmer, tools, and crops | Block silhouettes retain the farmer's straw hat and walk animation. Crop shapes distinguish leafy crops, flowers, and produce. |
| Inventory and menus | Fifty original item icons are redrawn on a 16 × 16 pixel grid. Menus use squared panel corners. |
| Audio | Four original seasonal themes and all sound effects are synthesized by the scripts in `tools/audio/`, as a small pastoral band: flute or accordion lead, guitar, marimba, upright bass, and soft strings. No samples or existing melodies are used. |

Villagers go inside their houses during home hours. Their doors open as they leave for scheduled stops and when they return. Resident interiors are reserved for future visits; players cannot enter them yet.
