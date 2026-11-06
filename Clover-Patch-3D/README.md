# Clover Patch 3D

A small chibi farming game built in Godot 4 with the Compatibility renderer and a 1920 × 1080 (16:9) game viewport.

## 1. Open the farm

In the Godot Project Manager, select **Import**, pick this folder's `project.godot` and open it. Give Godot a moment to import the GLB models, then press **F5**. The main scene is built by script when the game starts.

## 2. Grow your first turnip

Walk with **WASD** or the **arrow keys** and orbit the camera with the **mouse**. Face a nearby garden plot to highlight it. Press **E** with the **Hoe** equipped to till. Press **E** again to plant the equipped seed, then press **3** to equip the **Watering Can** and press **E** to water. The **Sickle** is required to harvest spinach and fodder grass. Pick other ripe crops with **E**, regardless of the tool you are holding. A turnip planted and watered on Spring 1 is ready on Spring 5 if you water it every day. The plot tooltip shows the number of watered nights remaining.

The clock advances while you play. Follow the farm lane southwest to the cottage. Press **E** by the door to enter, and press **E** beside the bed once fatigue reaches **65%**. Sleeping starts the next morning and advances watered crops. Use the doormat to leave. Press **E** near the outside repair sign to fix the roof and window for **10 coins**. The same upgrade replaces the damaged floorboard and adds a rug and curtains inside.

Fatigue stages are **Rested**, **Getting tired** (30%), **Tired** (65%), and **Exhausted** (90%). The food meter warns when you're **Hungry** (below 45%) or **Very hungry** (below 20%). Hunger and fatigue can slow walking. At 90% fatigue, farming, shopping, equipping seeds, and cottage repairs are blocked. You can still walk home, use the door, sleep, or eat. Bread reduces fatigue by 22 points. Edible crops reduce it by 14.

## 3. Trade at the seed market

You start with five turnip seeds, six coins, and two bread rations. Visit the striped stall by the home garden and press **E** to see the current season's seeds, first harvest days, and regrowth times. Buying a seed equips it. Select an in-season seed in the bag and choose **Equip seed**. Use **Sell harvest** to sell all the produce in your bag. Check the journal for deliveries before selling everything.

Spring, Summer, Fall, and Winter each last 30 days. Ordinary crops wilt when their planting season ends. Winter has no ordinary outdoor seeds, and fodder grass goes dormant. Fodder is an extra Clover Patch crop that grows without watering on a one-night timer.

Crop timing reference: [Spring](https://fogu.com/sos3/farm/spring_crops.html), [Summer](https://fogu.com/sos3/farm/summer_crops.html), [Fall](https://fogu.com/sos3/farm/fall_crops.html). The reference counts planting as day 1. Clover Patch uses its own coin prices, offers seasonal seeds without the source game's unlock requirements, and uses original simple crop models.

## 4. Food shop, inventory, and testing

- Visit the **Valley Bakery** southeast of the home garden and press **E** by its stall. Bread costs **2 coins** and restores 35 food when eaten.
- Use **1** for empty hands, **2** for the Hoe, **3** for the Watering Can, and **4** for the Sickle. **E** works the highlighted plot or uses the nearby object.
- Press **Tab** to free the cursor. Click a tool slot, Bag, Journal, Pause, or the nearby action prompt. Press **Tab** again or click the world to return to camera control.
- Press **I** to open your bag. Drag stacks between slots on the current page. Matching stacks merge up to 64, and different items swap positions. Select an illustrated item slot to equip a tool or seed, or eat that item. Select the equipped tool again to put it away. Stacks hold up to 64 items, and more pages appear as your bag fills.
- Press **F7** to open or close the Test menu. **Resident testing** lets you set exact favor, try the date and partnership thresholds, reset the selected resident’s romance or daily gift state, and stock their favorite and disliked gifts. You can open dialogue without earning the daily visit bonus, jump to the resident during work hours, or watch them leave home. The main menu still has the farm, time, and cottage shortcuts.
- **E** prompts appear only within reach of the current plot, shop, door, bed, or repair sign.

## 5. Pause and settings

Press **Esc** during play to pause the world, including the clock, hunger, and fatigue. Select **Settings** to change mouse sensitivity, invert vertical look, adjust brightness, or switch fullscreen on or off. Open **Graphics** for 720p, 900p, or 1080p 3D rendering, Off/2×/4× MSAA, sun shadows, and VSync. The HUD keeps its 1080p base layout. Open **Audio** to set Master, Music, and Sound Effects volume independently. Settings apply immediately and are saved locally. Choose **Save farm** to save immediately, or sleep to autosave at dawn. The game loads your last save on launch. Press **Esc** again or choose **Resume** to return to the farm.

## 6. Explore Clover Valley

- Follow Market Lane east past the seed stall and bakery to find 24 more plots in the East Garden.
- Take the north branch from Market Lane to the Apple Orchard. In fall, look for red apples on trees and press **E** nearby to pick one. Different trees bear fruit each morning. Eat the apples from your bag, sell them at the market, or ship them.
- Take the south branch to Willow Pond. At the dock on the north bank, press **E** to cast. Wait for the bite cue, then press **E** or choose **Reel in** before the meter empties. Pond Perch goes into your bag and can be eaten, cooked, sold, or shipped. The path continues east to Clover Meadow.
- Follow the trail north from the home farm or past the orchard to climb the two block peaks. Walk toward a higher block to hop up, or walk off a ledge to drop to the lower terrace.

## 7. Edit the world with the developer tool

The standalone **Clover Patch World Builder** project edits this game's `world/clover_valley.json`. The tool opens that file automatically when both project folders are siblings. Edit, save, and restart the game to test the result. The game reads this layout at startup. Saved crops follow their plot coordinates, so moving or deleting a plot removes its crop from the next save. See the [world authoring guide](../AGENTS.md) for terrain and map editing.

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

Press **J** and choose **Collection and skills**. Donate one Pond Perch, one Moondrop Flower, and one Orchard Apple from your bag to fill the collection and earn **18 coins**. Each specimen can be donated once.

Successful plot work, fish catches, and prepared meals build their own skills. Higher Farming levels reduce fatigue from plot work. Fishing levels widen the reel window. Cooking levels make meals relieve more fatigue. The journal shows your progress, and both the collection and skills are saved with the farm.

## 11. Meet the village

Press **E** near a resident to talk. Visit Market Lane, the west bank of Willow Pond, the orchard edge, and Clover Meadow to meet all 32. Residents move within their districts as the day progresses. Talk regularly, or choose bread or produce from your bag as a gift. Each resident has their own taste.

Press **J** and choose **Village and story** for witness locations and the supper schedule. The farmer's choices shape the supper and the flood hearing. Ask residents about either event to hear their reactions. Six adults have optional romance routes as your favor grows. See the [story and character guide](village/STORY.md) for story spoilers and character editing.

Starting on day 2, **Village and story** lists a random town event and its host each morning. Talk to that resident and pick one of two responses before going to bed. Either response earns 3 favor. The game rotates through 32 events before repeating them.

Press **E** beside a picnic table to spend 30 in-game minutes recovering up to 12 fatigue. Look for tables by the bakery, in the meadow and orchards, and along the ponds. The trail west of the cottage leads to the old pass, where a rockslide closed the way through the ridge.

## 12. Test the game

From this folder, run `godot --headless --import` followed by `godot --headless --script res://tests/valley_life_smoke.gd`. The smoke test uses a temporary save.

## Asset audit

| Asset group | Clover Patch treatment |
| --- | --- |
| Terrain, soil, paths, and water | Original 16 × 16 repeating textures with nearest filtering. The valley layout and its functional plot grid are shared with the World Builder. |
| Trees, flowers, and orchard fruit | Original stepped block models replace the earlier imported models. |
| Cottage, shops, fences, and signs | Block-built props, pixel-textured timber, and a stepped cottage roof with separate damaged and repaired states. |
| Farmer, tools, and crops | Block silhouettes retain the farmer's straw hat and walk animation. Crop shapes distinguish leafy crops, flowers, and produce. |
| Inventory and menus | Fifty original item icons are redrawn on a 16 × 16 pixel grid. Menus use squared panel corners. |
| Audio | Original Clover Patch music and sound effects carry over from the previous build. |

Villagers go inside their houses during home hours. Their doors open as they leave for scheduled stops and when they return. Resident interiors are reserved for future visits; players cannot enter them yet.
