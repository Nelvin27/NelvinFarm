# Clover Patch 3D: game design

This is the one-page reference for what the game is and how its rules work today. Numbers come from the code; the file that owns each rule is named so you can check or change it. For how to play, see the [player guide](../Clover-Patch-3D/README.md). For what comes next, see the [roadmap](../Clover-Patch-3D/ROADMAP.md).

## What the game is

Clover Patch 3D is a single-player voxel farming game made in Godot 4.7 with the Compatibility renderer. The player inherits a cottage in Clover Valley, grows crops through four seasons, fishes, forages, cooks, befriends the residents, and uncovers what happened the night a flood destroyed three homes.

- **View:** third-person, over the shoulder, with a free orbit camera.
- **Look:** blocks. Terrain rises in whole-block steps, and trees, houses, tools, and people are built from boxes with 16 × 16 pixel textures.
- **Tone:** cozy and unhurried. Nothing in the valley can be lost for good by missing a day.

### Reference games

| Game | What Clover Patch takes from it |
| --- | --- |
| Harvest Moon: Back to Nature | The daily farm loop, village routines, the home upgrade, festivals, and the warm, small-band sound. |
| Stardew Valley | Seasonal crops, shipping, the bag and hotbar, requests, and long-term restoration goals. |
| Animal Crossing: New Horizons | The specimen collection and donation loop. |
| Rune Factory 4 Special | Skills that grow through practice. |

The [mechanics comparison](../Clover-Patch-3D/MECHANICS.md) scores each system against these games. No art, music, text, or level layout is copied from any of them.

## The core loop

1. **Morning:** check the forecast in the journal, water or harvest, and plant what is in season.
2. **Day:** sell or ship produce, buy seeds and bread, fish, forage, explore, and talk to residents.
3. **Evening:** eat, cook, and go to bed. Sleeping advances crops, pays out the shipping bin, and autosaves.

## The valley

The map is generated. [build_world.py](../tools/world/build_world.py) lays the town out in code and writes `world/clover_valley.json`; the game builds terrain, scenery, and houses from that file at startup. The [world guide](../Clover-Patch-3D/world/guide.md) explains each district and [AGENTS.md](../AGENTS.md) lists the build and check commands.

| Place | What is there |
| --- | --- |
| Home Farm | The cottage, the shipping bin, and 35 plots in the home field. |
| Market Square | The seed market, the bakery, and the wishing well. The East Garden beside it has 24 more plots. |
| Council Row | North of the square: the petition boards, the town bell, and Iona's house. |
| Bread Lane | East of the bakery to the commons. Mara's house is the first on it. |
| Village Commons | The great oak, bunting, and picnic tables. |
| Apple Orchard | 24 apple trees east of Council Row. The Hilltop Trail loops behind it. |
| Willow Pond and Clover Meadow | The old waterline and the Valley Supper clearing. |
| Highwater Brook | Runs from the Highbank hills to Clover Lake, crossed by four bridges. The clinic stands on its west bank; the old floodgate and three ruined cottages are on the east. |
| Clover Lake and Reedmere | The eastern waters, reached by Reedmere Walk. |
| The hills | The summit lookout on the north peak, the east knoll, and the outer mountain range. |
| Hidden places | A glade in the northern woods, standing stones in the south meadow, and a pond in the southern woods. |

## Systems and their rules

### Time and seasons (`farm_clock.gd`, `crop_catalog.gd`)

- A day runs from 06:00 to 02:00. One real second is 2.5 game minutes, so a full day lasts 8 minutes.
- Spring, Summer, Fall, and Winter each last 30 days.
- Weather is forecast a day ahead. Rain waters every planted crop. Snow is visual.

### Hunger and fatigue (`farm_clock.gd`, `farm.gd`)

| Rule | Value |
| --- | --- |
| Hunger at the start | 80 of 100, falling 0.09 per second (0.135 while walking) |
| Fatigue rise from time alone | 0.18 per second (0.27 while walking) |
| One plot action | 6 fatigue, less 0.5 per Farming level above 1, and 1.2 hunger |
| Shaking a tree / digging | 2 / 4 fatigue |
| Stages | Getting tired at 30, Tired at 65, Exhausted at 90 |
| Slower walking | 86% speed when hungry (below 45) or tired; 70% when very hungry (below 20) or exhausted |
| Exhausted | Farming, shops, fishing, foraging, and repairs are blocked |
| Bread | +35 food, −22 fatigue |
| An edible crop | +25 food, −14 fatigue |
| Picnic table | 30 minutes for −12 fatigue |
| Sleep | Fatigue to 0, hunger −12. Allowed from 18:00, or earlier at 65 fatigue |

A rebalance is proposed in the roadmap: time alone currently exhausts the farmer in about five and a half minutes of walking, which is harsh for a farm with 59 plots.

### Crops (`crop_catalog.gd`, `farm.gd`)

Press E on a plot to till, plant, water, and harvest. A crop needs one watered night per growth day. Regrowing crops return to the planted state after harvest. Ordinary crops wilt when their season ends.

| Season | Crop (days to first harvest / days to regrow) |
| --- | --- |
| Spring | Turnip (5), Potato (8), Cucumber (10 / 5), Strawberry (10 / 3), Cabbage (15), Moondrop Flower (7), Toy Flower (13) |
| Summer | Tomato (10 / 3), Corn (15 / 3), Onion (8), Pumpkin (15), Pineapple (21 / 5), Pinkcat Flower (7) |
| Fall | Eggplant (10 / 3), Carrot (8), Yam (7 / 3), Spinach (6, sickle), Green Pepper (8 / 2), Adzuki Beans (11 / 4), Chili Pepper (13 / 5), Magic Flower (11), Sunsweet Flower (11) |
| Any but Winter | Fodder Grass (2 / 1, sickle, needs no water) |

The planting day counts as day 1, so a Turnip planted on Spring 1 and watered daily is ready on Spring 5.

### Tools (`farm.gd`)

Hoe, Watering Can, and Sickle. E picks up whichever one the job needs; keys 1 to 4 select by hand. **Watering Can +** costs 25 coins and also waters the four plots beside the target.

### Money (`farm.gd`, `market_menu.gd`, `farm_orders.gd`)

- Start: 6 coins, 5 turnip seeds, 2 bread.
- Earn: sell at the market at once, or ship from the bin by the cottage door for the same price the next morning.
- Three delivery orders per season, shown in the journal.
- Harvest milestones at 5, 20, and 50 crops pay 8, 18, and 35 coins.
- Spend: bread 2, cottage repair 10, Watering Can + 25, bag rows 30 then 80.

### Bag and hotbar (`inventory_grid.gd`)

- 12 slots at the start; 24 and 36 after the two upgrades. Stacks hold 64.
- The first row is the hotbar. The mouse wheel selects a slot and F or right-click uses it.
- Drag to rearrange, right-click or double-click to use, **Sort bag** to merge stacks and put tools and seeds first.

### Fishing (`pond_fishing.gd`, `farm.gd`)

Cast from a dock, wait for the bite, and reel in before the meter empties. Higher Fishing levels widen the window.

| Water | Catch |
| --- | --- |
| Willow Pond | Pond Perch |
| Clover Lake | Lake Trout |
| Reedmere | Reed Carp |
| Hidden pond | Pond Perch, with a 30% Moonfin chance |

Moonfin bites 18% of the time at dusk (from 18:00) or in the rain, and 35% of the time anywhere on a day the ducks or the well have brought luck.

### Foraging and the orchard (`farm.gd`)

- Wild Berries in spring and summer, Chanterelles in fall, River Shells on pond banks until winter. 22 spots; about half refill each morning.
- Apple trees fruit in fall. Different trees bear each morning on a 5-day rotation.

### Things to touch (`valley_interactions.gd`)

| Thing | Rule |
| --- | --- |
| Signs | Show their text. Petition boards show tomorrow's weather, a rumor of a buried find, and a fishing tip. |
| Trees | Once per tree per day: 22% a seasonal find (none in winter), 14% a few coins, otherwise leaves. |
| Ducks | 1 bread. The first feeding each day brings fishing luck. |
| Wishing well | 1 coin, once a day: 4 coins back, fishing luck, a hint to a buried find, or 18 fatigue relief. |
| Town bell | Rings and tells the time. |
| Buried finds | 4 of 18 spots sparkle each day. Coins, a River Shell, 2 seeds, or a 15-coin purse. |
| Landmarks | 16 places. 2 coins each, 25 more for finding them all. |

### Cooking (`cottage_cooking.gd`)

Unlocked by repairing the cottage. Garden Stew (turnip, bread), Orchard Toast (apple, bread), and Pan-Seared Perch (perch). Meals are eaten at once and restore more than their ingredients.

### Skills (`valley_skills.gd`)

Farming, Fishing, and Cooking each have four levels, earned by doing the activity. Farming reaches its levels at 8, 24, and 48 plot actions; Fishing and Cooking at 3, 8, and 16.

### Collection (`farm.gd`)

Nine specimens. Donating the three classics (Pond Perch, Moondrop Flower, Orchard Apple) pays 18 coins, and completing all nine pays 40 more.

### Village and story (`valley_village.gd`, [STORY.md](../Clover-Patch-3D/village/STORY.md))

- The story, *The High-Water Mark*, has three witness accounts, the Valley Supper, and a hearing with three outcomes.
- Talking earns 2 favor a day. Gifts earn 8 (favorite), 3 (neutral), or −5 (disliked). Personal talks open at 10 favor; romance at 12 and 24.
- A town event with two choices is offered each day from day 2.
- The full cast is 32 residents. **Only Iona and Mara are active right now**; the other 30 character files are parked in `village/characters_disabled/`, so most of the story cannot be played until they are restored.

### Saving (`farm_save.gd`)

Sleeping autosaves at dawn; the pause menu saves on demand. The save lives in Godot's user data folder as `farm.cfg`. Crops are saved by plot position, so plots must never move.

### Audio (`farm_audio.gd`, `tools/audio/`)

Four seasonal themes that crossfade on the first morning of a season, and 19 sound effects. All of it is synthesized by `make_music.py` and `make_sounds.py`; no samples or existing melodies are used.

## How the project is put together

| Part | Where |
| --- | --- |
| Main scene and game state | `Clover-Patch-3D/farm.tscn`, `farm.gd` |
| Player and camera | `player/` |
| Menus and HUD | `ui/` |
| Scenery built from the map | `farm_scenery.gd`, `terrain_mesh.gd`, `voxel_batch.gd` |
| World interactions | `valley_interactions.gd` |
| Residents | `valley_village.gd`, `village/characters/*.json` |
| Map builder and checks | `tools/world/` |
| Sound and music generators | `tools/audio/` |
| Tests | `Clover-Patch-3D/tests/valley_life_smoke.gd` |

## Where the documentation lives

| Document | What it covers |
| --- | --- |
| [Player guide](../Clover-Patch-3D/README.md) | Controls and how to play |
| This file | Rules and numbers |
| [Roadmap](../Clover-Patch-3D/ROADMAP.md) | What is planned, in order |
| [Mechanics comparison](../Clover-Patch-3D/MECHANICS.md) | Scoring against the reference games |
| [Story guide](../Clover-Patch-3D/village/STORY.md) | Plot and character files |
| [World guide](../Clover-Patch-3D/world/guide.md) | Districts and layout rules |
| [AGENTS.md](../AGENTS.md) | How to build, check, and preview the map |
| [Work log](agent-work/CLOVER-VALLEY.md) | What was changed, when, and what is unverified |
| [Changelog](../CHANGELOG.md) | Player-facing changes by date |
