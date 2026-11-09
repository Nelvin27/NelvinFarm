# Clover Patch gameplay roadmap

Build a farming town where crops, animals, neighbors, collecting, and exploration all give the player reasons to return tomorrow. Each new activity should connect to another one through food, materials, friendships, or a shared town project. The [mechanics comparison](MECHANICS.md) tracks the reference systems and scores how much Clover Patch currently covers.

The next playable milestone is **a coop, one hen, and an egg at dawn**. Fodder grass already exists, the day transition already updates crops and shipping, and eggs can feed the cooking, market, and shipping loops. This is the shortest route from the current build to a farm that feels more alive.

## Interface roadmap

The tool belt and day panel put Stardew Valley-style shortcuts and Back to Nature-style daily status on the play screen. The Farm Bag keeps the stack grid and gives the selected item its own action card. The Valley Journal keeps Animal Crossing-inspired specimen donations and Rune Factory-inspired practice skills one click from the farm.

- Add a daily care card when the coop ships, using the hen's actual feed, affection, and egg state.
- Add a journal calendar when birthdays, shop hours, and recurring festivals are available. Put shipment totals beside requests and farm milestones as the ledger grows.
- Separate discoveries from donations when the first-catch and specimen records ship. Expand the skill pages as practice starts unlocking recipes and mastery rewards.

## 1. Give the farm animals

- Let the player buy a small coop and adopt one hen. Give the hen visible idle, feeding, and petting animations. Feed it fodder, collect its egg the next morning, then cook, sell, or ship the egg.
- Show whether the hen has eaten and whether an egg is waiting. Track affection through daily care. A missed feeding skips production for that day, and feeding resumes the loop.
- Once the first hen works, expand into coop upgrades, hatching, cows and sheep, grazing, milk and wool, and a companion pet. Use the same care rules for every species, with differences that give each animal a purpose.

**Ready when** a player can buy, feed, sleep, collect, and use an egg through normal play. Saves preserve the hen, feed state, and uncollected eggs, and reloading cannot duplicate production.

## 2. Make Clover Valley feel inhabited

- Give the seed market and bakery named residents with readable schedules. Add a ranch keeper, carpenter, and smith as their services become available. Start with conversations that respond to the season, weather, and the player's recent activities.
- Add friendship, individual gift preferences, birthdays, letters, visiting merchants, and a calendar in the Valley Journal. Introduce requests that teach new activities and open shops, recipes, or town services. Let repeatable daily goals share the same journal.
- Start events with a pond fishing derby and a harvest fair. Add seasonal gatherings, cooking and livestock contests, and villager visits as the cast grows. Add personal scenes before courtship, marriage, and family life.

**Ready when** players can find residents from the calendar, build a friendship through ordinary visits or gifts, and attend a festival with a reward worth pursuing.

## 3. Add crafting, farm upgrades, and decoration

- Open a safe quarry and woodland gathering routes. Let players use stone, ore, and wood at a workbench and smith. Add recipes through skills, requests, and recipe books or bread.
- Add tool tiers, refillable watering cans, irrigation, fertilizer, soil quality, higher-quality seeds, and a greenhouse. Give upgrades clear uses, such as tending more crops or recovering more time for town visits. Put routine automation behind milestones that teach the manual version.
- Add storage, bag upgrades, processing machines for eggs, milk, wool, and crops, plus more cottage and farm buildings. Let players place and rotate furniture, paths, fences, and outdoor decorations. Add house expansions, outfits, and building finishes in later passes.

**Ready when** a player can gather materials, craft or commission an upgrade, place it, and see a meaningful improvement in their daily routine. Storage, placements, and machine queues survive reload.

## 4. Expand fishing and build a real collection

- Record first catches and discoveries separately from donations. Add fish that vary by water, season, time, and weather. Keep the current timed bite approachable. Add rods, bait, and optional harder catches for players who want more depth.
- Add insects, dig spots for fossils, seasonal forage, artifacts, and an exhibit hall that displays donated specimens. Connect collecting to displays, town projects, and rotating visitors who buy surplus finds.
- Add a stocked farm pond with feed, population limits, and harvestable fish. Give extra crops, fruit, fish, and finds a choice of uses through recipes, exhibits, gifts, or income.

**Ready when** the journal helps a player find a specific specimen, the first discovery stays recorded even after selling it, and an exhibit displays the donated item after reload.

## 5. Open the mines and add monster companions

- Start with a shallow mine with ore, ladders, and checkpoints. Add optional deeper routes with enemies, weapons, elemental magic, equipment upgrades, and boss encounters. Give farm meals and crafted gear useful effects underground.
- Let players befriend a few original monsters by offering food. Add a habitat, daily care, and roles such as producing materials, helping with simple chores, or accompanying the player into the mine.
- Expand the practice system into gathering, crafting, mining, combat, and companion care. Add mastery rewards and recipes as each activity gains enough depth. Offer crafting and trade routes to shared upgrades so the farm and town remain viable for players who prefer peaceful play.

**Ready when** a mine trip can produce a useful farm upgrade, a player can keep a companion across days, and ordinary farming and town routes stay peaceful.

## 6. Restore the valley and expand the map

- Tie collections, delivery orders, relationships, and farm milestones to shared restoration projects. Start with visible improvements such as an exhibit hall, repaired bridge, or new service. Offer different contributions so farming, fishing, crafting, and exploration can all move projects forward.
- Add a yearly farm review with rewards for several play styles and continued play afterward. Build toward a coastal area with new catches and a highland area with forage, ruins, and seasonal events. Give each region its own activity and reason to revisit.
- Add shortcuts, a mount, or a ferry after the map supports repeated journeys. Add alternative farm layouts and challenge settings after the main valley has a complete progression path.

**Ready when** finishing a project changes the world, opens a useful route or service, and feels worthwhile for more than one play style.

## 7. Add visits and shared farms

- Start with farm visits and sightseeing. Expand to shared farming after the clock, inventory ownership, trade, sleeping, shipping payouts, and world edits have clear host rules.
- Add shared events or contests after joins, departures, and reconnects preserve progress. Use the same game rules for solo and shared play wherever possible.

**Ready when** players can join, trade, help on the farm, and leave without losing or duplicating items, progress, or payouts.

## How the reference games fit together

| Reference | What it contributes to Clover Patch |
| --- | --- |
| Stardew Valley | Farm production chains, seasonal requests, restoration projects, mining and combat, skill mastery, late-game regions, and shared farms. |
| Harvest Moon: Back to Nature | Daily animal care, village routines, farm and home upgrades, festivals, pond stocking, family life, and a multi-year farm review. |
| Animal Crossing: New Horizons | Discoveries and exhibits, insects and fossils, gifts and letters, visiting merchants, daily goals, decorating, and farm visits. |
| Rune Factory 4 Special | Skills that grow through practice, recipe progression, cooking benefits, crafting and equipment, elemental combat, and monsters as companions and farm helpers. |

Use the existing in-game clock for crops, resident schedules, festivals, and dawn payouts. Use coins for ordinary trade and the journal for milestones, requests, and unlocks. Keep market sales immediate and use one overnight shipping bin for crops, fish, and animal goods. Make permanent rewards visible in the valley, and let players miss a day and pick up where they left off.

For map additions, extend `tools/world/build_world.py` and follow the [world authoring guide](../AGENTS.md). Keep the voxel style and guide players with paths, landmarks, and nearby prompts. For each milestone, play the new loop from its normal entry point, verify an existing save can load, check dawn and reload behavior where relevant, then update the mechanics comparison and recalculate its similarity scores.
