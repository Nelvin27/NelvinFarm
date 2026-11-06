---
title: The High-Water Mark
language: en
premise: "A village can rebuild trust when the people who bear the cost have a say in what happens next."
counter-premise: "Keeping essential services alive sometimes means making a decision before everyone can be heard."
---

# The High-Water Mark

## Main story summary

The farmer inherits a cottage that stayed dry the night a flood destroyed three homes in Clover Valley. At Iona's urging, the farmer hears three accounts. Vera opened the floodgate to save six patients in the clinic. Tess removed the tenants' names from the ledger to buy the families time to move, and the missing page let the council treat the land as vacant. The council sold the flooded plots to keep the clinic open. Orin kept the tenants' copy of the deed, which shows that the farmer's grandmother signed the sale and kept the only dry parcel.

At the Valley Supper, the farmer can honor the displaced families or the clinic workers. At the hearing, the farmer chooses whether to publish the ledger, put the land in a trust the families help govern, or protect their names through a private claims fund. The villagers respond from their own experiences, and life on the farm continues after the hearing.

The farmer is silent. Choice buttons describe what the player does, asks about, or supports. Other residents speak for themselves. Players can farm, fish, cook, and build friendships between story scenes, then return to a witness when they're ready.

## Story and event sequence

1. **The dry cottage.** Iona points the player to Tess, Vera, and Orin. The player can hear each of them in any order. The Valley Journal records whose account they have heard.
2. **The missing page.** Tess cut the lease list out of the ledger to buy the families time to move. The missing page also let the council treat those families as absent. Vera deliberately opened the gate to save six patients. The council kept the clinic running with money from selling the land it flooded.
3. **The key.** Orin still has the tenants' deed. The farmer's grandmother signed the sale, asked him to burn his copy, and kept the only dry parcel. The farm the player has been making their own is part of the evidence.
4. **The Valley Supper.** From day 3 after 16:00, Mara asks whom the village should honor with its extra place. The player can choose the displaced families or the clinic workers. The table appears in the meadow that evening. Mara, Orin, and Sana respond to who was honored. The rest of the village remembers the same meal through their own work and relationships.
5. **The hearing.** Iona waits until the day after the third account, giving the families time to hear about the hearing. Posting the ledger makes the facts public and earns trust with the witnesses. A shared land trust gives the families a vote over future leases and gives the player seeds. Private claims protect names and pay the player a fee for recovering the records. Each route leaves different questions open. Iona and Greta respond to the selected outcome, and every resident has a hearing reaction.

The supper and hearing are separate events. A player can reach the hearing before attending the supper. Neither event has an expiry date, and the daily farm loop continues after the hearing.

The [town event catalog](town_events.json) gives every villager a smaller scene drawn from their backstory. The journal announces a host each day starting on day 2. Each scene has two choices with distinct replies and awards 3 favor once. The event is available until the next dawn. A missed event can return after the roster has rotated.

## Relationships

The first conversation of a day earns 2 favor. One gift per resident per day earns 8 for a favorite, 3 for a neutral gift, or loses 5 for a disliked one. Residents have individual favorite and disliked replies. At 10 favor, a personal conversation becomes available. Six adult residents have optional romance routes. An invitation becomes available at 12 favor, and a relationship can be proposed at 24 after the date conversation. Each has their own answer. Players can keep friendships and finish the story without romance.

## Character files

The game loads one JSON file per resident from [characters](characters/). Use a resident's file as the starting point for an AI writing request. For example, ask for three new lines for [Orin](characters/orin.json) after the shared trust outcome, using his relationships, motives, and voice. Read the files named in `character.connections` before writing about those relationships.

- `id` matches the filename and keys saved favor, gifts, and romance. Keep it stable when editing an existing resident.
- `order` controls roster order. Districts `0`, `1`, `2`, and `3` are Market Lane, west of Willow Pond, the orchard edge, and Clover Meadow.
- `character.backstory` summarizes the resident's link to the flood, its aftermath, or the hearing. Treat it as established history when writing new scenes.
- `character.quest_hook` gives a starting point for a future personal quest. Use it alongside the resident's motivation, voice, and connections. The `dialogue` section holds their live lines.
- `appearance` holds skin, hair, clothing, and accent colors, along with the resident's scale, haircut, outfit, and signature accessory. The original voxel shapes and accessory names are defined in [resident_model.gd](../resident_model.gd).
- Gift IDs come from [crop_catalog.gd](../crop_catalog.gd). Bread is `-1`, Turnip is `0`, Moondrop Flower is `5`, Fodder Grass is `22`, Orchard Apple is `23`, and Pond Perch is `24`.
- Every resident needs an introduction, a friendship line, a supper reaction, a hearing reaction, and two gift reactions. Witnesses also need their account and a line after it. Romance candidates need a date and relationship reply. Optional `supper_choices` and `hearings` arrays provide outcome-specific reactions in the order listed above.
- Export builds need the character JSON files included by the same `*.json` filter used for the world layout.

## Where people settled

**Highbank Terrace** follows Otto's old uphill lamp route. Orin took a house above the flood line, and Sol and Niko keep their repair yard nearby. **Bread Lane** grew along the road to the bakery and market. Ada lives beside Mara, and Tess and Iona are close enough to trade records on foot. **Orchard Row** puts Lark, Joel, Faye, and Ness within reach of the orchards and replacement gardens. **Reedmere Walk** passes Sana and Vera's homes on the way to the water, where Bea, Hollis, and Ren live near each other.

The residents carry those choices into their days. Otto tends the uphill lamp. Mara and Ada bring bread and soup to the commons. Hollis watches the new water without taking on passengers. After their testimony, Vera walks the old gate route, Orin retraces the lost cottages, and Tess checks the lease dates against the families' accounts. Iona makes time for neighbors after the hearing. The character files record why each resident chose their home and when they leave and return.
