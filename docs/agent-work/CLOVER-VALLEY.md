# Work log: Clover Valley

A dated record of the work done on Clover Patch 3D with Claude Code: what changed, how it was checked, and what is still unverified. Newest entries are at the bottom. Player-facing summaries are in the [changelog](../../CHANGELOG.md).

**State on 2026-11-13:** all work is committed and pushed on branch `refactor/scene-nodes`, and [pull request 1](https://github.com/Nelvin27/NelvinFarm/pull/1) is open from that branch. It is not merged into `main`.

**How to check the project** (from `Clover-Patch-3D`):

```bash
godot --headless --import
godot --headless --script res://tests/valley_life_smoke.gd
godot --headless --script ../tools/world/check_world.gd
godot --headless --script ../tools/world/audit_world.gd
```

The smoke test currently reports 187 checks and 10 failures. All 10 come from the reduced cast (see 2026-11-09) and are expected until the other residents are restored.

## 2026-11-09 · Scenes, a generated world, and valley extras

Committed as `008e28f` and pushed; pull request 1 opened.

- **Scenes in place of code-built nodes.** The main scene, player, menus, HUD, effects, and audio are authored as `.tscn` files with signals connected in the scene. `farm.gd` keeps the game state.
- **Cast reduced to two.** At the user's request only Iona and Mara stay active. The other 30 character files were moved to `village/characters_disabled/`. This is why 10 smoke checks fail.
- **World builder replaced.** The separate World Builder project was removed. `tools/world/build_world.py` now generates `world/clover_valley.json`, with `check_world.gd`, `audit_world.gd`, and `render_world.gd` beside it.
- **Map rebuilt.** Market Square, the commons, the orchard, three fishing waters, a hidden pond, the glade, the standing stones, two lookouts, and a layered mountain range.
- **Batched scenery.** Trees, flowers, bushes, rocks, and grass tufts draw through MultiMesh (`voxel_batch.gd`).
- **Valley extras.** Three more fish and the rare Moonfin, seasonal forage, a nine-specimen collection, lantern light at night, puddles in rain, and snow in winter.
- **Map audit.** After the user said the map was not good enough, `audit_world.gd` was written to check every 5 × 5 cell, and its findings were fixed. The side mountains were rebuilt after a second complaint.

## 2026-11-12 · Interactive world

Committed and pushed on 2026-11-13.

- **Interactions** (`valley_interactions.gd`): readable signs and petition boards, shakeable trees, ducks to feed, the wishing well, the town bell, buried finds, rustling bushes, and discoverable landmarks. State is saved under the `world` key and resets each morning, except discoveries.
- **Highwater Brook:** new `stream` and `bridge` map pieces, four bridges, and the Brook Path.
- **Sounds:** `tools/audio/make_sounds.py` added with five synthesized effects.
- **Outer ridge fix:** the smoke test found a low gap in the regenerated mountain range. The builder now fills any gap along the barrier line and reports one if it remains.
- **Tests:** `_test_world_interactions()` added. It found a real bug: `nearby()` cached by position only, so switching tools on a dig spot had no effect until the farmer moved. Fixed.
- **Renders reviewed:** brook, well, and bell.

## 2026-11-13 · Story layout, audio, and controls

Committed and pushed on 2026-11-13.

- **Town laid out to match the story.**
  - Council Row moved from the far east to the lane north of Market Square, with the plaza, boards, bell, and Iona's house at its head. Iona's workplace in `iona.json` moved with it.
  - The orchard shifted east, and the Hilltop Trail now loops behind it.
  - Flood places added: the clinic (an empty house), the floodgate (`floodgate` kind) with the Old Gate Route, and three lost cottages (`ruin` kind).
  - Bread Lane built from the bakery to the commons, with Mara's house moved onto it.
  - Checked with the builder, `check_world.gd` (0 failures), `audit_world.gd` (0 findings), the smoke test, and reviewed renders.
- **Docs:** the player guide, world guide, tools README, and `AGENTS.md` updated for the layout and interactions.
- **Audio remade twice.** First as four seasonal chiptune themes; the user did not want a handheld-console sound, so the same melodies were re-rendered with synthesized acoustic-style instruments (flute, reed, guitar, marimba, upright bass, strings, brushes) and a room reverb. All 19 effects were regenerated with soft mallet tones. `farm_audio.gd` gained `play_season()`, which crossfades on a season change. The old `clover_theme.ogg` was deleted.
- **Controls, bag, and flow.** E picks the right tool; holding E works each new plot once; Shift runs; left-click is E and right-click is F; Shift + wheel zooms. The bag gained Sort and right-click use. Planting the last seed switches to another in-season seed. The bed works from 18:00.
- **Fatigue reviewed, not changed.** A rebalance was proposed and is in the roadmap.
- **This documentation set** written: `docs/GAME-DESIGN.md`, this log, and `CHANGELOG.md`. The earlier `WORK_IN_PROGRESS.md` was folded into this log and removed.

## Not verified

- **Nothing from 2026-11-12 onward has been played by a person.** It was checked by tests and still renders only.
- **Motion:** the tree wobble, ducks swimming over, and the bell swing have not been watched in the running game.
- **Audio:** the music and effects were checked for length and level only. Nobody has confirmed how they sound.
- **Keyboard-held actions:** running with Shift and holding E read the keyboard directly and have no automated test.
- **Mechanics comparison scores:** `MECHANICS.md` was last scored before the extra fish, forage, and collection work, so its percentages are out of date.

## Known gaps

- Highbank Terrace (the uphill lamp route from the story) is not on the map.
- The clinic is an empty house; nobody works there.
- Mara's house backs onto the main street with about half a tile to spare.
- Sorting the bag also rearranges the hotbar, because the hotbar is the bag's first row.
- A resource-leak warning still prints when the game exits headlessly. It does not affect play.
