#!/usr/bin/env python3
"""Clover Valley world builder.

Lays out the whole valley in code and writes Clover-Patch-3D/world/clover_valley.json. The game reads that
file at startup (scenery, terrain, plots, houses). Run it, then check and preview the result in Godot:

    python3 tools/world/build_world.py
    godot --headless --path Clover-Patch-3D --script ../tools/world/check_world.gd
    godot --path Clover-Patch-3D --script ../tools/world/render_world.gd -- overview

Gameplay anchors (plots, cottage, shops, spawn, ridges, north peak, old pass, Willow Pond, the Supper
clearing) are fixed below because saves, the story, and the smoke test depend on them. Everything else is free
to change. The layout is deterministic: the same script always produces the same file.
"""
import json, math, os, random, sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "Clover-Patch-3D", "world", "clover_valley.json")
BOUNDS = [-43, -62, 168, 132]
rng = random.Random(20261109)
E = []          # output entities
problems = []

def add(kind, x, z, y=0, **fields):
    e = {"kind": kind, "position": [round(x, 3), y, round(z, 3)]}
    e.update(fields)
    E.append(e)
    return e

# --- Fixed anchors -----------------------------------------------------------------------
# Farm plots: saves identify crops by these grid positions. Never move or remove them.
for x in range(7):
    for z in range(-2, 3):
        add("plot", -4.5 + x, z)            # home field
for x in range(6):
    for z in range(-1, 3):
        add("plot", 15.5 + x, z)            # east garden
add("spawn", -5.5, 0)
add("cottage", -12.5, 6)
add("seed_market", 4.5, 2.5, y=0.06)
add("bakery", 8.5, 6)
add("closed_pass", -28, 14)                 # the rockslide; approached from the east

# Terrain. [x, z, width, depth, height]. The outer ring frames the valley; the ridge barriers stop
# movement behind its visible slopes. The north peak and its neighbor are climbable lookouts.
MOUNTAINS = [
    (-13.5, -26, 23, 23, 8.45), (7.5, -27, 20, 21, 6),                 # north peak (flat summit) and its neighbor
    (49.5, -29, 32, 22, 9), (68.5, -29, 21, 20, 6),                     # Highbank hills
    (97, 13, 16, 16, 5),                                                # east knoll lookout
    (31.5, 40, 22, 14, 2), (59.5, 46, 25, 14, 1),                       # southern rolling hills
]
# The outer mountain range is laid out later (see "Mountain range"), once the town exists, so its
# foothills can be fitted around everything that needs level ground.
for x, z, w, d, h in MOUNTAINS:
    add("mountain", x, z, size=[w, d], height=h)
for x, z, w, d in ((41, -56, 168, 12), (41, 63.5, 168, 13), (-38.5, 4, 9, 132), (119, 4, 12, 132)):
    add("ridge_barrier", x, z, size=[w, d])
mountains = [e for e in E if e["kind"] == "mountain"]

def elevation(x, z):
    cx, cz = math.floor(x) + 0.5, math.floor(z + 0.5)
    best = 0.0
    for m in mountains:
        sx, sz = m.get("size", [16, 16])
        ox = (cx - m["position"][0]) / (sx * 0.5)
        oz = (cz - m["position"][2]) / (sz * 0.5)
        f = max(0.0, 1.0 - (ox * ox + oz * oz))
        best = max(best, m.get("height", 5) * f ** m.get("falloff", 2.0))
    return float(round(best))   # Python rounds half to even; Godot rounds half away. Checked in-engine too.

def level(x0, z0, x1, z1, what, height=0.0):
    x = x0
    while x <= x1 + 1e-6:
        z = z0
        while z <= z1 + 1e-6:
            if elevation(x, z) != height:
                problems.append(f"{what} not level at ({x:.1f},{z:.1f})")
                return
            z += 0.5
        x += 0.5

# Keep-out rectangles for scattered props: (x0, z0, x1, z1)
keep_out = []
def reserve(x0, z0, x1, z1, pad=0.0):
    keep_out.append((x0 - pad, z0 - pad, x1 + pad, z1 + pad))

def clear(x, z, pad=0.0):
    return not any(a - pad <= x <= c + pad and b - pad <= z <= d + pad for a, b, c, d in keep_out)

# Gameplay reserves from world/guide.md plus the fixed buildings.
reserve(-19.0, 0.5, -8.0, 8.5)        # cottage expansion (includes the cottage)
reserve(-21.0, -8.5, -12.0, -1.5)     # outbuilding yard
reserve(-5.0, -13.5, 5.0, -6.5)       # north field
reserve(-24.0, 16.5, -12.0, 24.5)     # south field
reserve(-5.2, -3.4, 2.4, 2.7)         # home field plots
reserve(15.0, -1.5, 21.0, 2.5)        # east garden plots
reserve(-16.0, 8.5, -8.0, 11.0)       # cottage door, shipping bin, repair sign
reserve(10.5, 13.5, 18.0, 20.0, 0.8)  # Valley Supper clearing (table at 14, 16.5)
reserve(-29.5, 11.0, -25.5, 17.0)     # old pass approach

def path(x0, z0, x1, z1, trail=False, name="path"):
    """Axis-aligned dirt strip covering the rectangle (x0, z0)-(x1, z1)."""
    x0, x1 = min(x0, x1), max(x0, x1)
    z0, z1 = min(z0, z1), max(z0, z1)
    add("path", (x0 + x1) / 2, (z0 + z1) / 2, size=[round(x1 - x0, 3), round(z1 - z0, 3)])
    if not trail:
        level(x0, z0, x1, z1, name)
    reserve(x0, z0, x1, z1, 0.55)

def lane_x(x, z0, z1, w=1.6, **kw):
    path(x - w / 2, z0, x + w / 2, z1, **kw)

def lane_z(z, x0, x1, w=1.6, **kw):
    path(x0, z - w / 2, x1, z + w / 2, **kw)

def lamp(x, z):
    add("lamp", x, z)
    reserve(x - 0.3, z - 0.3, x + 0.3, z + 0.3)

def flat_around(x, z, half):
    """True when the columns under a footprint of half-width `half` share one height."""
    base = elevation(x, z)
    return all(elevation(x + dx, z + dz) == base for dx, dz in ((half, 0), (-half, 0), (0, half), (0, -half),
                                                                  (half, half), (-half, -half), (half, -half), (-half, half)))

def tree_fits(x, z, scale):
    # The trunk must stand inside one column and the canopy must not reach a taller column.
    base = elevation(x, z)
    if not flat_around(x, z, 0.2 * scale):
        return False
    reach = 0.6 * scale
    return all(elevation(x + dx, z + dz) - base < 1.0 for dx, dz in ((reach, 0), (-reach, 0), (0, reach), (0, -reach)))

def tree(x, z, scale=None, kind="tree"):
    scale = round(scale if scale else rng.uniform(0.85, 1.3), 2)
    if elevation(x, z) > 0:
        x, z = math.floor(x) + 0.5, round(z)          # sit hillside trees in the middle of a column
    if not tree_fits(x, z, scale):
        return False
    add(kind, x, z, scale=scale)
    return True

def deco(kind, x, z, scale=1.0, **fields):
    add(kind, x, z, scale=round(scale, 2), yaw=round(rng.uniform(0, math.tau), 2), **fields)

def reeds(x0, x1, z, step=0.45):
    x = x0
    while x <= x1:
        deco("tuft", x + rng.uniform(-0.1, 0.1), z + rng.uniform(-0.12, 0.12), rng.uniform(1.4, 2.0), color="#6f9a57")
        x += step

def flower(x, z, kind=None, scale=None):
    add(kind or rng.choice(["purple_flower", "yellow_flower"]), x, z, scale=round(scale or rng.uniform(0.55, 0.8), 2))

def bed(x0, z0, x1, z1, count, kind=None):
    for _ in range(count):
        flower(rng.uniform(x0, x1), rng.uniform(z0, z1), kind)
    reserve(x0, z0, x1, z1, 0.2)

def fence(x0, z0, x1, z1):
    if abs(z1 - z0) < 1e-6:
        add("fence", (x0 + x1) / 2, z0, length=round(abs(x1 - x0), 3))
    else:
        add("fence", x0, (z0 + z1) / 2, length=round(abs(z1 - z0), 3), yaw=90)
    level(min(x0, x1), min(z0, z1), max(x0, x1), max(z0, z1), "fence")
    reserve(min(x0, x1), min(z0, z1), max(x0, x1), max(z0, z1), 0.6)

def picnic(x, z, height=0.0):
    add("picnic", x, z)
    level(x - 1, z - 0.9, x + 1, z + 0.9, "picnic", height)
    reserve(x - 1.0, z - 0.9, x + 1.0, z + 0.9, 0.9)

def sign(x, z, label):
    add("sign", x, z, y=0.02, label=label)
    reserve(x - 0.3, z - 0.2, x + 0.3, z + 0.2)

def pond(x, z, w, d, fish="perch", rare=0.0):
    fields = {"fish": fish}
    if rare:
        fields["rare"] = rare
    add("pond", x, z, size=[w, d], **fields)
    level(x - w / 2, z - d / 2, x + w / 2, z + d / 2, "pond")
    reserve(x - w / 2, z - d / 2 - 1.4, x + w / 2, z + d / 2, 0.6)

# --- Roads ---------------------------------------------------------------------------
lane_z(4.5, -7.3, 62.0, w=1.8, name="Market Lane")             # main street: farm -> square -> Bread Lane -> east
path(2.6, 0.6, 13.6, 8.6, name="Market Square")                  # paved plaza under the stalls
lane_x(-6.5, -17.4, 3.6, name="ridge trail (lower)")
lane_x(-6.5, -20.3, -17.4, trail=True)             # lantern trail north beside the north field
lane_z(-19.5, -14.3, -5.7, name="ridge trail (terrace)", trail=True)
lane_x(-13.5, -24.5, -18.7, trail=True)                          # final climb to the north peak
lane_z(10.0, -22.3, 27.4, w=1.5, name="Pond Lane")               # cottage -> Willow Pond dock -> commons
path(-13.7, 8.8, -11.3, 10.0, name="cottage forecourt")
lane_x(-7.0, 5.4, 9.25, w=1.5, name="farm link")
lane_x(10.0, 8.6, 9.25, w=1.5, name="bakery link")
lane_x(-21.5, 9.25, 14.75, w=1.5, name="old pass road")
lane_z(14.0, -26.7, -20.75, w=1.5, name="old pass road")
lane_x(11.0, -17.6, 0.6, name="Orchard Lane")
lane_z(-12.5, 11.8, 30.0, w=1.2, name="orchard aisle")
# Village Commons ring
lane_z(8.4, 27.4, 44.6, w=1.2, name="commons north")
lane_z(16.6, 27.4, 44.6, w=1.2, name="commons south")
lane_x(28.0, 8.4, 16.6, w=1.2, name="commons west")
lane_x(44.0, 8.4, 16.6, w=1.2, name="commons east")
lane_x(36.0, 5.4, 7.8, name="commons gate")
# Reedmere Walk to the eastern lakes
lane_x(60.0, 5.4, 22.3, name="Reedmere Walk")
lane_z(21.5, 59.2, 86.8, name="Reedmere Walk (lake)")
lane_x(86.0, 20.7, 32.3, name="Reedmere Walk (south)")
lane_z(31.5, 85.2, 94.6, name="Reedmere Walk (pond)")
# Lookout trail onto the east knoll
lane_z(21.5, 86.8, 92.0, trail=True)
lane_x(92.0, 13.2, 22.3, trail=True)
lane_z(13.0, 91.2, 95.6, w=1.4, trail=True)    # up onto the knoll top (flat at x 95..99, z 11.5..14.5)

# --- Water -----------------------------------------------------------------------------
pond(2.95, 13.925, 7.9, 5.35)         # Willow Pond (original position; the flood landmark)
pond(70.0, 25.5, 11.0, 6.0, "trout")  # Clover Lake
pond(93.0, 37.0, 8.0, 7.0, "carp")    # Reedmere pond (original position)

# --- Home Farm --------------------------------------------------------------------------
fence(-5.2, -3.1, 2.3, -3.1)          # north edge of the home field
fence(2.3, -3.1, 2.3, 0.6)            # east edge, open to the square on the south
fence(14.9, -1.9, 21.1, -1.9)         # east garden, north
fence(14.9, -1.9, 14.9, 2.6)
fence(21.1, -1.9, 21.1, 2.6)
bed(-16.2, 9.0, -15.6, 10.6, 4)       # cottage dooryard flowers
bed(-9.4, 9.0, -8.9, 10.4, 3)
sign(-7.9, 3.1, "Home Farm")
sign(-20.4, 11.2, "Old Pass")
sign(-5.0, -14.5, "Ridge Trail")
for z in (0.0, -6.0, -12.0, -18.0):
    lamp(-5.3, z)
lamp(-11.0, -19.5 + 1.3)
lamp(-12.3, -23.0)

# --- Market Square ----------------------------------------------------------------------
add("bunting", 6.2, 4.5)
lamp(2.9, 0.9); lamp(13.3, 0.9); lamp(2.9, 8.3)
bed(13.9, 7.4, 14.6, 8.8, 4)
bed(2.8, 5.6, 3.6, 6.8, 4)
picnic(12.5, 7.0)                      # kept: the picnic test and the bakery break spot
add("butterflies", 12.2, 9.0)
sign(9.9, 0.9, "Market Lane")

# --- Bread Lane (Mara) ------------------------------------------------------------------------
# Mara keeps the house nearest the bakery, with a garden and room at the step for Ada's soup pot.
def house(x, z, street, **fields):
    add("resident_house", x, z, street=street, **fields)
    level(x - 2.2, z - 1.6, x + 2.2, z + 2.4, "house " + fields.get("resident", "?"))
    reserve(x - 2.2, z - 1.6, x + 2.2, z + 2.6, 0.4)

house(25.0, 1.5, "Bread Lane", resident="mara", color="#af6052", trim="#f0d39c", style=1, detail="crate")
path(24.4, 2.2, 25.6, 3.6, name="Mara's front walk")
bed(26.3, 2.6, 27.0, 3.3, 3)
bed(23.0, 2.6, 23.4, 3.3, 2, "yellow_flower")
fence(22.2, -1.1, 28.4, -1.1)              # Mara's kitchen garden behind the house
fence(22.2, -1.1, 22.2, 0.9)
fence(28.4, -1.1, 28.4, 0.9)
for x in (23.6, 25.0, 27.0):
    flower(x, -0.6, "yellow_flower", 0.75)
for x in (22.5, 26.5):
    tree(x, -3.0, 1.25)
sign(21.8, 3.0, "Bread Lane")

# --- Council Row (Iona) --------------------------------------------------------------------------
# Iona keeps the council book. Her house heads a small civic plaza north of the main street, where the
# petition boards stand; she works there and walks down to the market and Willow Pond.
lane_x(40.0, -5.4, 3.6, name="Council Row")
path(35.6, -9.0, 44.4, -5.4, name="Council plaza")
house(40.0, -11.2, "Council Row", resident="iona", color="#655782", trim="#dfbe7e", style=2, detail="woodpile")
path(39.4, -10.5, 40.6, -9.0, name="Iona's front walk")
for x in (36.6, 38.0, 42.0, 43.4):             # petition boards around the plaza
    sign(x, -9.5 if x in (36.6, 43.4) else -5.0, "Petition board")
lamp(35.8, -5.6); lamp(44.2, -5.6); lamp(39.1, 2.6)
bed(36.0, -8.6, 37.0, -7.8, 4, "purple_flower")
bed(43.0, -8.6, 44.0, -7.8, 4, "purple_flower")
picnic(37.4, -3.2)                            # where neighbors wait to sign
hedge_later = [(34.6, -13.4, 45.4, -13.4), (34.6, -13.4, 34.6, -9.6), (45.4, -13.4, 45.4, -9.6)]
reserve(34.4, -13.6, 45.6, -2.2)
sign(41.2, 3.0, "Council Row")

# Main-street lanterns and street trees
for x in (17.5, 31.0, 50.0, 58.0):
    lamp(x, 3.0)
for x in (20.0, 44.5, 54.0):
    lamp(x, 6.0)
for x in (16.0, 23.0, 30.5, 38.0, 47.0, 51.5, 56.5):
    tree(x, 6.6, 1.15)

# --- Village Commons ---------------------------------------------------------------------
add("bunting", 36.0, 7.9)
tree(36.0, 12.5, 1.9)                  # the great oak
for i in range(10):
    a = i / 10 * math.tau
    flower(36.0 + math.cos(a) * 1.9, 12.5 + math.sin(a) * 1.9, "yellow_flower" if i % 2 else "purple_flower", 0.7)
reserve(33.6, 10.1, 38.4, 14.9)
for x, z in ((27.3, 7.7), (44.7, 7.7), (27.3, 17.3), (44.7, 17.3)):
    lamp(x, z)
picnic(31.0, 14.6)
picnic(41.0, 14.6)
bed(29.0, 9.4, 30.4, 10.6, 5)
bed(41.6, 9.4, 43.0, 10.6, 5)
add("butterflies", 36.0, 11.0)
sign(37.2, 6.2, "Commons")
for x in (26.0, 46.0):
    for z in (9.5, 12.5, 15.5):
        tree(x, z, 1.0)

# --- Willow Pond and Clover Meadow ------------------------------------------------------------
sign(1.6, 9.0, "Willow Pond")
picnic(-3.6, 15.0)
for x, z in ((-2.2, 18.0), (1.0, 18.6), (4.5, 18.4), (7.8, 17.2), (-2.6, 12.0), (8.2, 12.6)):
    tree(x, z, rng.uniform(1.15, 1.45))
reeds(-0.8, 6.8, 16.95)                # reeds on the south bank
bed(-1.2, 17.3, 6.8, 17.6, 6)
add("butterflies", 20.0, 15.0)
add("butterflies", 9.0, 21.5)
picnic(22.0, 21.5)
sign(18.5, 11.0, "Clover Meadow")
reserve(-1.4, 10.8, 7.4, 17.4, 0.4)    # pond plus banks
# Wildflowers across the meadow, leaving the Supper clearing open
for _ in range(70):
    x, z = rng.uniform(8.0, 26.0), rng.uniform(11.5, 25.0)
    if clear(x, z):
        flower(x, z)

# --- Orchard -----------------------------------------------------------------------------------
for x in (14, 17, 20, 23, 26, 29):
    for z in (-8, -11, -14, -17):
        tree(x + rng.uniform(-0.15, 0.15), z + rng.uniform(-0.15, 0.15), round(rng.uniform(0.95, 1.1), 2), "apple_tree")
reserve(12.6, -18.6, 30.4, -6.4)
fence(12.6, -18.8, 30.6, -18.8)
fence(12.6, -6.2, 30.6, -6.2)
fence(30.6, -18.8, 30.6, -6.2)
fence(12.6, -18.8, 12.6, -13.3)
fence(12.6, -11.7, 12.6, -6.2)
add("butterflies", 20.0, -12.5)
add("butterflies", 27.0, -9.5)
sign(12.0, 3.0, "Orchard")
lamp(11.9, -5.0); lamp(10.1, -12.0)

# --- Reedmere Walk and the eastern lakes ----------------------------------------------------------
sign(61.2, 6.0, "Reedmere Walk")
for z in (10.0, 16.0):
    lamp(61.0, z)
lamp(66.0, 20.4); lamp(78.0, 20.4); lamp(87.1, 27.0); lamp(95.0, 30.4)
picnic(80.6, 26.0)
picnic(90.0, 43.0)
reeds(65.0, 75.0, 28.95)
reeds(89.4, 96.6, 40.95)
add("butterflies", 74.0, 33.0)
add("butterflies", 96.0, 43.5)
add("bunting", 70.0, 21.5)
lamp(95.7, 11.9); lamp(95.7, 14.1)
picnic(97.4, 13.0, height=5.0)                   # knoll lookout table
reserve(64.0, 21.8, 76.0, 29.3, 0.4)
reserve(88.5, 31.6, 97.5, 41.3, 0.4)

# --- Exploration: secret spots, loops, the summit, landmarks -------------------------------------
# Hilltop Trail: from the top of Orchard Lane over the shoulder of the second hill to Council Row.
lane_x(11.0, -22.3, -17.6, trail=True)                  # over the second hill's shoulder
lane_z(-21.5, 11.8, 14.0, w=1.4, trail=True)
lane_z(-21.5, 14.0, 36.7, w=1.4, name="Hilltop Trail")
lane_x(36.0, -22.2, -9.0, w=1.4, name="Hilltop Trail (descent)")
for x, z in ((18.0, -20.3), (26.0, -22.7), (34.8, -16.0)):
    lamp(x, z)
sign(12.2, -17.0, "Hilltop Trail")

# Lakeside loop around Clover Lake.
lane_x(63.2, 21.5, 30.9, w=1.2, name="lake loop west")
lane_z(30.3, 62.6, 77.2, w=1.2, name="lake loop south")
lane_x(76.6, 21.5, 30.9, w=1.2, name="lake loop east")
for x, z in ((62.1, 31.2), (77.7, 31.2)):
    lamp(x, z)

# The summit lookout: a flat crown on the north peak with lanterns, a table, and a ring of flowers.
PEAK = (-13.5, -26.0)
picnic(-12.2, -26.0, height=8.0)           # keeps the peak column open; the flat crown is x -16..-11, z -27.5..-24.5
lamp(-14.6, -27.2); lamp(-14.6, -24.8)
for i in range(14):
    a = i / 14 * math.tau
    x, z = PEAK[0] + math.cos(a) * 2.4, PEAK[1] + math.sin(a) * 2.4
    if elevation(x, z) == 8.0:
        flower(x, z, "yellow_flower" if i % 2 else "purple_flower", 0.7)
add("butterflies", PEAK[0] + 1.0, PEAK[1] + 0.6)
reserve(PEAK[0] - 3.0, PEAK[1] - 3.0, PEAK[0] + 3.0, PEAK[1] + 3.0)

# Secret glade deep in the Highbank forest: no path leads here.
GLADE = (66.0, -15.0)
reserve(GLADE[0] - 4.2, GLADE[1] - 3.6, GLADE[0] + 4.2, GLADE[1] + 3.6)
picnic(GLADE[0] + 1.2, GLADE[1] - 0.6)
for i in range(16):
    a = i / 16 * math.tau
    flower(GLADE[0] + math.cos(a) * 3.3, GLADE[1] + math.sin(a) * 2.8, "purple_flower" if i % 3 else "yellow_flower", 0.75)
add("butterflies", GLADE[0] - 1.0, GLADE[1] + 0.5)
add("butterflies", GLADE[0] + 2.0, GLADE[1] + 1.6)
tree(GLADE[0] - 1.8, GLADE[1] - 1.6, 1.9)

# Hidden pond in the southern woods. Moonfin bite here more often.
HIDDEN = (-8.0, 38.5)
pond(HIDDEN[0], HIDDEN[1], 4.0, 3.0, "perch", rare=0.3)
reeds(HIDDEN[0] - 1.8, HIDDEN[0] + 1.8, HIDDEN[1] + 1.95)
reserve(HIDDEN[0] - 3.0, HIDDEN[1] - 3.2, HIDDEN[0] + 3.0, HIDDEN[1] + 2.8)
bed(HIDDEN[0] + 2.2, HIDDEN[1] - 1.0, HIDDEN[0] + 2.8, HIDDEN[1] + 1.0, 5, "purple_flower")

# Landmarks: a great lone oak in Clover Meadow and a ring of standing stones in the south meadow.
tree(21.6, 13.8, 2.3)
reserve(20.6, 12.8, 22.6, 14.8)
STONES = (48.5, 28.0)
for i in range(8):
    a = i / 8 * math.tau
    x = math.floor(STONES[0] + math.cos(a) * 3.4) + 0.5     # pillars sit on single terrain columns
    z = round(STONES[1] + math.sin(a) * 3.4)
    add("mountain", x, z, size=[1, 1], height=3 if i % 2 == 0 else 2)
    mountains.append(E[-1])
for i in range(6):
    a = i / 6 * math.tau
    flower(STONES[0] + math.cos(a) * 1.2, STONES[1] + math.sin(a) * 1.2, "yellow_flower", 0.8)
reserve(STONES[0] - 4.6, STONES[1] - 4.6, STONES[0] + 4.6, STONES[1] + 4.6)
add("butterflies", STONES[0], STONES[1])

# Forage: berries at grove edges (spring and summer), chanterelles in shady woods (fall), shells on banks.
FORAGE = {
    "berries": [(-18.5, -11.5), (13.5, 23.5), (49.8, 10.4), (GLADE[0] - 2.4, GLADE[1] + 1.8), (33.5, 26.8),
                (70.6, 13.5), (-6.0, 23.6), (87.5, 7.5)],
    "mushroom": [(-21.0, 30.5), (HIDDEN[0] - 2.4, HIDDEN[1] - 1.6), (5.5, 40.5), (47.0, 39.0), (58.0, -17.5),
                 (72.5, -12.5), (40.0, -38.0), (86.0, -20.0)],
    "shell": [(95.5, 42.2), (97.9, 36.5), (88.1, 37.5), (7.6, 14.6), (HIDDEN[0] + 2.4, HIDDEN[1] + 0.6), (65.4, 30.3 - 1.0)],
}
for item, spots in FORAGE.items():
    for x, z in spots:
        if elevation(x, z) != 0.0:
            problems.append(f"forage {item} on a slope at ({x},{z})")
        add("forage", x, z, item=item)
        reserve(x - 0.5, z - 0.5, x + 0.5, z + 0.5)

# --- Forests, hedgerows, and flower drifts --------------------------------------------------------
placed = [(e["position"][0], e["position"][2]) for e in E if e["kind"] in ("tree", "apple_tree")]
def far_enough(x, z, d):
    return all((x - a) ** 2 + (z - b) ** 2 >= d * d for a, b in placed)

def plant(x, z, scale, spacing):
    if not clear(x, z, 0.35) or elevation(x, z) > 10 or not far_enough(x, z, spacing):
        return False
    if not tree(x, z, scale):
        return False
    placed.append((E[-1]["position"][0], E[-1]["position"][2]))
    return True

def hedge(x0, z0, x1, z1, step=1.15):
    n = max(1, int(math.hypot(x1 - x0, z1 - z0) / step))
    for i in range(n + 1):
        t = i / n
        plant(x0 + (x1 - x0) * t + rng.uniform(-0.12, 0.12), z0 + (z1 - z0) * t + rng.uniform(-0.12, 0.12),
              rng.uniform(0.72, 0.88), 0.95)

def grove(cx, cz, radius, density=0.36):
    count = int(radius * radius * density)
    for _ in range(count * 3):
        if count <= 0:
            break
        r = radius * math.sqrt(rng.random())
        a = rng.random() * math.tau
        # Larger trees toward the middle of a grove give it a rounded silhouette.
        scale = 1.75 - 0.6 * (r / radius) + rng.uniform(-0.1, 0.1)
        if plant(cx + math.cos(a) * r, cz + math.sin(a) * r * 0.85, scale, 1.8):
            count -= 1

# Hedgerows frame the farm, the lanes, and the back gardens.
hedge(-5.6, -4.2, 2.6, -4.2)              # behind the home field fence
hedge(14.6, -2.8, 21.4, -2.8)             # behind the east garden
hedge(-21.0, 11.2, -14.6, 11.2)           # south side of Pond Lane by the cottage
hedge(-24.6, -1.0, -24.6, 9.0)            # west edge of the farmstead
hedge(46.8, 3.0 - 4.0, 58.5, 3.0 - 4.0)   # behind the east end of Bread Lane
hedge(61.4, 8.0, 61.4, 19.6)              # along Reedmere Walk
hedge(26.8, 18.6, 45.2, 18.6)             # south edge of the commons
for segment in hedge_later:
    hedge(*segment)

GROVES = [  # x, z, radius
    (-20, -14, 6), (-24, -26, 7), (-4, -32, 7), (16, -30, 6), (24, -40, 6), (-14, -38, 6),
    (-22, 30, 7), (-8, 34, 8), (6, 40, 7), (20, 34, 6), (-24, 42, 6), (14, 46, 5),
    (38, -16, 6), (46, -10, 5), (58, -16, 7), (72, -12, 7), (86, -20, 7), (98, -6, 6), (40, -38, 7), (64, -38, 6),
    (84, -36, 7), (100, -30, 6),
    (52, 13, 4), (70, 10, 6), (82, 4, 6), (98, 6, 5), (102, 22, 4),
    (36, 30, 6), (48, 40, 7), (64, 44, 6), (78, 44, 6), (102, 46, 5), (54, 26, 4), (80, 30, 3.5),
    (70, 37, 5), (60, 31, 3),
    (-18, 4, 3.5), (8, 22, 3), (24, 26, 4),
]
for gx, gz, gr in GROVES:
    grove(gx, gz, gr)
# A light scatter of loners between groves so the meadows aren't bare.
for _ in range(110):
    x, z = rng.uniform(-26, 105), rng.uniform(-42, 49)
    plant(x, z, rng.uniform(0.9, 1.25), 7.0)

# Flower drifts at junctions and grove edges.
DRIFTS = [(-8.6, 5.9), (9.0, 11.2), (26.6, 5.9), (45.4, 5.9), (58.6, 6.0), (61.4, 23.0), (85.0, 23.0),
          (-20.2, 15.6), (12.4, 3.4), (-4.6, 4.0), (35.0, 19.6), (24.0, 12.0), (-7.8, -14.0), (96.5, 29.8)]
for dx, dz in DRIFTS:
    kind = rng.choice(["purple_flower", "yellow_flower"])
    for _ in range(9):
        x, z = dx + rng.gauss(0, 0.55), dz + rng.gauss(0, 0.4)
        if clear(x, z, 0.0):
            flower(x, z, kind if rng.random() < 0.75 else None)
# Lakeside wildflowers between the two eastern ponds.
for _ in range(45):
    x, z = rng.uniform(62, 98), rng.uniform(29.5, 34)
    if clear(x, z, 0.1) and elevation(x, z) == 0:
        flower(x, z)
added = sum(1 for e in E if e["kind"] == "tree")

# --- Mountain range around the valley -----------------------------------------------------------------
# Three layers per stretch of the ring: a crest of uneven peaks on the ridge line, broken ridges in front,
# and broad low foothills reaching into the valley. Broad, low shapes give wide green terraces; only the
# crest climbs to bare rock and snow. Any piece that would lift ground the town needs flat is skipped.
FLAT_KINDS = ("path", "pond", "picnic", "resident_house", "fence", "plot", "cottage", "seed_market", "bakery",
              "lamp", "sign", "forage", "bunting", "closed_pass", "spawn")
FLAT_POINTS = []
for e in E:
    if e["kind"] not in FLAT_KINDS:
        continue
    x, z = e["position"][0], e["position"][2]
    w, d = e.get("size", {"pond": [1, 1]}.get(e["kind"], [1, 1]))
    if e["kind"] == "resident_house":
        w, d = 4.4, 4.0
    elif e["kind"] in ("picnic", "cottage"):
        w, d = (2.2, 2.0) if e["kind"] == "picnic" else (7.0, 7.0)
    elif e["kind"] == "pond":
        w, d = w + 1.0, d + 3.0
    elif e["kind"] == "fence":
        w = d = float(e.get("length", 1.0)) + 0.4
    hx, hz = w / 2, d / 2
    nx, nz = max(1, int(w / 1.5)), max(1, int(d / 1.5))
    for i in range(nx + 1):
        for j in range(nz + 1):
            px, pz = x - hx + w * i / nx, z - hz + d * j / nz
            FLAT_POINTS.append((px, pz, elevation(px, pz)))
for a, b, c, d in keep_out:
    for i in range(5):
        for j in range(5):
            px, pz = a + (c - a) * i / 4, b + (d - b) * j / 4
            FLAT_POINTS.append((px, pz, elevation(px, pz)))

def mound(x, z, w, d, h, falloff=2.0):
    m = {"kind": "mountain", "position": [round(x, 2), 0, round(z, 2)], "size": [round(w, 1), round(d, 1)], "height": round(h, 2)}
    if falloff != 2.0:
        m["falloff"] = round(falloff, 2)
    return m

def lifts_town(m):
    mx, mz = m["position"][0], m["position"][2]
    rx, rz = m["size"][0] / 2, m["size"][1] / 2
    for px, pz, base in FLAT_POINTS:
        cx, cz = math.floor(px) + 0.5, math.floor(pz + 0.5)
        ox, oz = (cx - mx) / rx, (cz - mz) / rz
        f = max(0.0, 1.0 - (ox * ox + oz * oz))
        if f > 0 and round(m["height"] * f ** m.get("falloff", 2.0)) > base:
            return True
    return False

def place(m):
    bx, bz, bw, bd = BOUNDS
    m["position"][0] = round(min(max(m["position"][0], bx + 0.5), bx + bw - 0.5), 2)
    m["position"][2] = round(min(max(m["position"][2], bz + 0.5), bz + bd - 0.5), 2)
    if lifts_town(m):
        return False
    E.append(m)
    mountains.append(m)
    return True

# The ring as four edges: (start, end, inward direction). Crest runs on the ridge-barrier line.
EDGES = [((-40, -55), (122, -55), (0, 1)), ((120, -55), (120, 64), (-1, 0)),
         ((122, 63), (-40, 63), (0, -1)), ((-39, 64), (-39, -55), (1, 0))]
placed_range = Counter()
for (x0, z0), (x1, z1), (ix, iz) in EDGES:
    length = math.hypot(x1 - x0, z1 - z0)
    ux, uz = (x1 - x0) / length, (z1 - z0) / length
    s = 0.0
    while s < length:
        step = rng.uniform(12.0, 20.0)
        cx, cz = x0 + ux * s, z0 + uz * s
        along = rng.uniform(22, 34)
        across = rng.uniform(18, 24)
        w, d = (along, across) if abs(ux) > 0.5 else (across, along)
        jitter = rng.uniform(-2.5, 2.5)
        peak = 16 if rng.random() < 0.25 else rng.uniform(9.5, 15.4)
        if place(mound(cx + ix * jitter, cz + iz * jitter, w, d, peak, rng.uniform(0.9, 1.3))):
            placed_range["crest"] += 1
        # Broken ridge in front of the crest.
        if rng.random() < 0.8:
            inset = rng.uniform(9, 13)
            along, across = rng.uniform(14, 24), rng.uniform(10, 15)
            w, d = (along, across) if abs(ux) > 0.5 else (across, along)
            shift = rng.uniform(-4, 4)
            if place(mound(cx + ix * inset + ux * shift, cz + iz * inset + uz * shift, w, d, rng.uniform(5.0, 8.0), rng.uniform(1.3, 1.7))):
                placed_range["ridge"] += 1
        # Foothills: wide and low, so they read as green terraces with trees.
        for _ in range(2):
            inset = rng.uniform(15, 22)
            along, across = rng.uniform(12, 22), rng.uniform(9, 14)
            w, d = (along, across) if abs(ux) > 0.5 else (across, along)
            shift = rng.uniform(-6, 6)
            if place(mound(cx + ix * inset + ux * shift, cz + iz * inset + uz * shift, w, d, rng.uniform(1.6, 3.6))):
                placed_range["foothill"] += 1
        s += step
print("mountain range:", dict(placed_range))

# Trees climb the foothills and the lower ridge terraces.
hill_trees = 0
for _ in range(2600):
    x, z = rng.uniform(-36, 117), rng.uniform(-52, 60)
    h = elevation(x, z)
    if not 1 <= h <= 7:
        continue
    if not clear(x, z, 0.3) or not far_enough(x, z, 2.2 if h <= 3 else 3.0):
        continue
    if tree(x, z, rng.uniform(0.9, 1.35)):
        placed.append((E[-1]["position"][0], E[-1]["position"][2]))
        hill_trees += 1
# Boulders where the slopes turn to rock.
for _ in range(500):
    x, z = rng.uniform(-38, 119), rng.uniform(-54, 62)
    if 6 <= elevation(x, z) <= 11 and flat_around(x, z, 0.4) and clear(x, z, 0.3):
        deco("rock", x, z, rng.uniform(0.9, 1.6))
print("hillside trees:", hill_trees)

# --- Tidy and fill, 5x5 cell by cell ----------------------------------------------------------------
PATHS = [(e["position"][0] - e["size"][0] / 2, e["position"][2] - e["size"][1] / 2,
          e["position"][0] + e["size"][0] / 2, e["position"][2] + e["size"][1] / 2) for e in E if e["kind"] == "path"]
PONDS = [(e["position"][0] - e["size"][0] / 2 - 0.45, e["position"][2] - e["size"][1] / 2 - 1.3,
          e["position"][0] + e["size"][0] / 2 + 0.45, e["position"][2] + e["size"][1] / 2 + 0.3) for e in E if e["kind"] == "pond"]
HOUSES = [(e["position"][0] - 2.0, e["position"][2] - 1.6, e["position"][0] + 2.0, e["position"][2] + 2.4)
          for e in E if e["kind"] == "resident_house"]
HOUSES.append((-15.9, 3.1, -9.1, 9.6))                      # cottage, porch, shipping bin
HOUSES += [(3.4, 1.0, 5.8, 4.0), (7.6, 5.4, 9.4, 6.6)]      # stalls
HOUSES += [(e["position"][0] - 1.05, e["position"][2] - 0.95, e["position"][0] + 1.05, e["position"][2] + 0.95)
           for e in E if e["kind"] == "picnic"]
TRUNKS = [(e["position"][0], e["position"][2]) for e in E if e["kind"] in ("tree", "apple_tree")]

def inside(x, z, rects, pad=0.0):
    return any(a - pad <= x <= c + pad and b - pad <= z <= d + pad for a, b, c, d in rects)

SMALL = ("purple_flower", "yellow_flower", "tuft", "bush", "rock")
kept = []
removed = Counter()
for e in E:
    x, z = e["position"][0], e["position"][2]
    k = e["kind"]
    bad = False
    if k in SMALL:
        bad = (inside(x, z, PATHS, 0.08) or inside(x, z, PONDS) or inside(x, z, HOUSES)
               or any((x - a) ** 2 + (z - b) ** 2 < 0.12 for a, b in TRUNKS)
               or not flat_around(x, z, 0.12 if k in ("purple_flower", "yellow_flower", "tuft") else 0.35))
    elif k in ("tree", "apple_tree"):
        s = e.get("scale", 1.0)
        bad = inside(x, z, PATHS, 0.15 * s) or inside(x, z, HOUSES, 0.3 * s) or not tree_fits(x, z, s)
    if bad:
        removed[k] += 1
    else:
        kept.append(e)
E[:] = kept

# Ground cover so no stretch of the valley floor is bare grass.
VALLEY = (-26, -46, 106, 50)
def occupied_cells():
    seen = set()
    for e in E:
        if e["kind"] in ("mountain", "ridge_barrier"):
            continue
        x, z = e["position"][0], e["position"][2]
        if e["kind"] in ("path", "pond"):
            w, d = e["size"]
            cx = math.floor((x - w / 2) / 5)
            while cx * 5 < x + w / 2:
                cz = math.floor((z - d / 2) / 5)
                while cz * 5 < z + d / 2:
                    seen.add((cx, cz))
                    cz += 1
                cx += 1
        else:
            seen.add((math.floor(x / 5), math.floor(z / 5)))
    return seen

filled = 0
taken = occupied_cells()
for cx in range(math.floor(VALLEY[0] / 5), math.ceil(VALLEY[2] / 5)):
    for cz in range(math.floor(VALLEY[1] / 5), math.ceil(VALLEY[3] / 5)):
        if (cx, cz) in taken:
            continue
        x0, z0 = cx * 5, cz * 5
        if elevation(x0 + 2.5, z0 + 2.5) > 9:
            continue
        # A small vignette: tufts, plus a bush, rock, or flower patch, kept off anything reserved.
        props = []
        for _ in range(rng.randint(3, 6)):
            props.append(("tuft", rng.uniform(1.0, 1.5), "#7fa65a" if rng.random() < 0.6 else "#6a944f"))
        roll = rng.random()
        if roll < 0.4:
            props.append(("bush", rng.uniform(0.8, 1.3), None))
        elif roll < 0.6:
            props.append(("rock", rng.uniform(0.7, 1.4), None))
        elif roll < 0.85:
            props += [("flower", 0.0, None)] * 3
        cluster = (rng.uniform(x0 + 1, x0 + 4), rng.uniform(z0 + 1, z0 + 4))
        for kind, scale, color in props:
            x, z = cluster[0] + rng.gauss(0, 0.7), cluster[1] + rng.gauss(0, 0.6)
            if not clear(x, z, 0.2) or not flat_around(x, z, 0.35) or inside(x, z, PATHS, 0.2) or inside(x, z, PONDS):
                continue
            if kind == "flower":
                flower(x, z)
            elif kind == "tuft":
                deco("tuft", x, z, scale, color=color)
            else:
                deco(kind, x, z, scale)
        filled += 1

# Bushes and rocks soften grove edges and hillsides.
for _ in range(320):
    x, z = rng.uniform(VALLEY[0], VALLEY[2]), rng.uniform(VALLEY[1], VALLEY[3])
    near_tree = any((x - a) ** 2 + (z - b) ** 2 < 3.2 for a, b in placed[-600:])
    if near_tree and clear(x, z, 0.3) and flat_around(x, z, 0.4) and not inside(x, z, PATHS, 0.3) and not inside(x, z, PONDS):
        deco("bush" if rng.random() < 0.7 else "rock", x, z, rng.uniform(0.75, 1.25))
print("tidy: removed", dict(removed), "· filled", filled, "bare cells")

# --- Write ---------------------------------------------------------------------------------------
bx, bz, bw, bd = BOUNDS
for e in E:
    x, z = e["position"][0], e["position"][2]
    if not (bx <= x <= bx + bw and bz <= z <= bz + bd):
        problems.append(f"out of bounds {e['kind']} {x},{z}")
lines = ",\n".join("\t" + json.dumps(e, ensure_ascii=False) for e in E)
open(OUT, "w").write('{"version": 1, "bounds": %s, "entities": [\n%s\n]}\n' % (json.dumps(BOUNDS), lines))
print(len(E), "entities; forest trees", added)
print(dict(Counter(e["kind"] for e in E)))
print("PROBLEMS:" if problems else "no problems", *problems[:30], sep="\n")
