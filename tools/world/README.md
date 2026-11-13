# World tools

| File | What it does |
| --- | --- |
| `build_world.py` | Lays out Clover Valley and writes `Clover-Patch-3D/world/clover_valley.json`. Fixed anchors are at the top; each district has its own section. Same input, same map. |
| `check_world.gd` | Loads the game headlessly and checks level ground, resident routes, and reachability from spawn, including the well, bell, signs, dig spots, and ground-level landmarks. Non-zero exit on failure. |
| `audit_world.gd` | Checks every 5×5 cell for ledge-straddling props, trees in walls or each other, props on paths or in ponds, and dead-end paths. `-- --verbose` lists findings per cell. |
| `render_world.gd` | Renders preview PNGs into `renders/`. Views: `top`, `overview`, `farm`, `square`, `bread_lane`, `council_row`, `flood`, `commons`, `lakes`, `summit`, `glade`, `stones`, `hidden_pond`, `meadow`, or `x,z,distance,pitch,yaw`. Options: `--hour 22`, `--season 0-3`, `--rain`, `--suffix _name`. |

Run the Godot scripts from `Clover-Patch-3D` so `res://` resolves to the game. The commands are in [AGENTS.md](../../AGENTS.md).

Example, a summer night on Bread Lane:

```bash
cd Clover-Patch-3D
godot --script ../tools/world/render_world.gd -- bread_lane meadow --hour 22.5 --season 1 --suffix _night
```

## Audio tools

`tools/audio/make_sounds.py` synthesizes every sound effect as a WAV file. `tools/audio/make_music.py` composes and renders the four seasonal themes (`spring.ogg`, `summer.ogg`, `fall.ogg`, `winter.ogg`) and needs `sox` for the Ogg encoding. Each tune is a chord and a melody line per bar near the bottom of the script. Both write into `Clover-Patch-3D/assets/audio/`; run `godot --headless --import` afterward.
