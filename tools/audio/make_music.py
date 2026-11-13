#!/usr/bin/env python3
"""Composes and synthesizes Clover Patch's seasonal music: four original pastoral themes for a small band
(flute or reed lead, plucked guitar, marimba, upright bass, soft strings, and brushed percussion).

    python3 tools/audio/make_music.py

Writes spring.ogg, summer.ogg, fall.ogg, and winter.ogg into Clover-Patch-3D/assets/audio/ (needs `sox` for
the Ogg encoding). Each tune is written below as a chord and a melody per bar; the bass, guitar,
marimba, strings, and percussion are derived from the chords. Deterministic: the same script gives the same files.
"""
import math, os, random, struct, subprocess, sys, tempfile, wave

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Clover-Patch-3D", "assets", "audio")
NOTES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
CHORDS = {"": (0, 4, 7), "m": (0, 3, 7)}


def pitch(name):
    """'F#5' or 'Bb4' to a frequency."""
    step = NOTES[name[0]]
    rest = name[1:]
    while rest[0] in "#b":
        step += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 440.0 * 2 ** ((step - 9) / 12 + int(rest) - 4)


def octave_down(token):
    """'F#5/1' to 'F#4/1'; rests pass through."""
    name, length = token.split("/")
    return token if name == "-" else "%s%d/%s" % (name[:-1], int(name[-1]) - 1, length)


def chord_tones(name, octave):
    root = name.rstrip("m")
    return [pitch(root + str(octave)) * 2 ** (step / 12) for step in CHORDS["m" if name.endswith("m") else ""]]


# --- Instruments. Each returns one sample for time `t` into a note held for `held` seconds. ----------
TAU = 2 * math.pi


def flute(f, t, held):
    w = TAU * f * t + 0.03 * math.sin(TAU * 5.2 * t) * min(1.0, t * 3) * f / 60
    breath = ((t * 7919.13) % 1.0 - 0.5) * 0.05 * math.exp(-t * 14)
    body = math.sin(w) + 0.3 * math.sin(2 * w) + 0.09 * math.sin(3 * w) + breath
    return body * min(1.0, t * 26) * min(1.0, max(0.0, (held - t) * 16)) * (0.8 + 0.2 * math.exp(-t * 3))


def reed(f, t, held):
    """A small accordion: odd harmonics with a slow tremolo."""
    w = TAU * f * t
    body = math.sin(w) + 0.42 * math.sin(3 * w) + 0.2 * math.sin(5 * w) + 0.25 * math.sin(2 * w * 1.003)
    return body * min(1.0, t * 18) * min(1.0, max(0.0, (held - t) * 14)) * (0.88 + 0.12 * math.sin(TAU * 5.8 * t))


def music_box(f, t, held):
    w = TAU * f * t
    return (math.sin(w) + 0.35 * math.sin(2 * w) + 0.12 * math.sin(3 * w)) * math.exp(-t * 3.2) * min(1.0, t * 300)


def marimba(f, t, held):
    w = TAU * f * t
    return (math.sin(w) + 0.45 * math.sin(4 * w) * math.exp(-t * 22)) * math.exp(-t * 7.5) * min(1.0, t * 350)


def upright(f, t, held):
    w = TAU * f * t
    body = math.sin(w) + 0.5 * math.sin(2 * w) * math.exp(-t * 5) + 0.18 * math.sin(3 * w) * math.exp(-t * 9)
    return body * min(1.0, t * 150) * math.exp(-t * 2.4) * min(1.0, max(0.0, (held - t) * 25))


def strings(f, t, held):
    """A soft section: two slightly detuned voices, four harmonics each, slow bow."""
    total = 0.0
    for detune in (0.997, 1.004):
        w = TAU * f * detune * t
        total += math.sin(w) + 0.5 * math.sin(2 * w) + 0.28 * math.sin(3 * w) + 0.14 * math.sin(4 * w)
    return total * 0.5 * min(1.0, t * 3.5) * min(1.0, max(0.0, (held - t) * 3.5))


class Song:
    def __init__(self, bpm, beats, seed):
        self.beat = 60.0 / bpm
        self.beats = beats
        self.rng = random.Random(seed)
        self.left = []
        self.right = []

    def _room(self, end):
        need = int(end * RATE) + 1 - len(self.left)
        if need > 0:
            self.left.extend([0.0] * need)
            self.right.extend([0.0] * need)

    def note(self, voice, f, start, length, volume, pan=0.0, ring=0.0):
        """`start` and `length` in beats. `ring` lets decaying voices sound past the note's end."""
        begin = start * self.beat
        held = length * self.beat
        total = held + ring
        self._room(begin + total)
        first = int(begin * RATE)
        l, r = volume * (1.0 - max(0.0, pan)), volume * (1.0 + min(0.0, pan))
        for i in range(int(total * RATE)):
            s = voice(f, i / RATE, held if not ring else total)
            self.left[first + i] += s * l
            self.right[first + i] += s * r

    def pluck(self, f, start, volume, pan=0.0, seconds=1.1, bright=0.5):
        """A plucked string (Karplus-Strong): nylon guitar when dull, harp when bright."""
        begin = start * self.beat
        self._room(begin + seconds)
        first = int(begin * RATE)
        size = max(2, int(RATE / f))
        line = [self.rng.uniform(-1, 1) for _ in range(size)]
        for i in range(1, size):                       # soften the pick
            line[i] = line[i] * bright + line[i - 1] * (1 - bright)
        l, r = volume * (1.0 - max(0.0, pan)), volume * (1.0 + min(0.0, pan))
        n = int(seconds * RATE)
        for i in range(n):
            at = i % size
            s = line[at]
            line[at] = (s + line[(at + 1) % size]) * 0.4975
            fade = min(1.0, (n - i) / (RATE * 0.08))
            self.left[first + i] += s * l * fade
            self.right[first + i] += s * r * fade

    def strum(self, tones, start, volume, pan=-0.3):
        for index, tone in enumerate(tones):
            self.pluck(tone, start + index * 0.02 / self.beat, volume, pan, 0.9, 0.45)

    def drum(self, kind, start, volume):
        begin = start * self.beat
        length = {"kick": 0.16, "brush": 0.13, "shaker": 0.06, "block": 0.06}[kind]
        self._room(begin + length)
        first = int(begin * RATE)
        y = 0.0
        for i in range(int(length * RATE)):
            t = i / RATE
            if kind == "kick":
                s = math.sin(TAU * (48 + 70 * math.exp(-t * 30)) * t) * math.exp(-t * 20)
            elif kind == "block":
                s = math.sin(TAU * 820 * t) * math.exp(-t * 70)
            else:
                smooth = {"brush": 2.4, "shaker": 1.25}[kind]
                y += (self.rng.uniform(-1, 1) - y) / smooth
                s = y * math.exp(-t * {"brush": 22, "shaker": 55}[kind]) * min(1.0, t * 200)
            self.left[first + i] += s * volume
            self.right[first + i] += s * volume

    def melody(self, voice, bar, line, volume, ring=0.0):
        at = bar * self.beats
        for token in line.split():
            name, length = token.split("/")
            length = float(length)
            if name != "-":
                self.note(voice, pitch(name), at, length * (0.96 if not ring else 1.0), volume, 0.1, ring)
            at += length
        if abs(at - (bar + 1) * self.beats) > 1e-6:
            sys.exit("bar %d of a melody is %g beats, expected %g" % (bar, at - bar * self.beats, self.beats))

    def save(self, name, bars):
        """Folds the tail back onto the start so the loop is seamless, adds a room, and encodes."""
        n = int(bars * self.beats * self.beat * RATE)
        self._room(n / RATE)
        for channel in (self.left, self.right):
            for i in range(n, len(channel)):
                channel[i - n] += channel[i]
            del channel[n:]
        # A small hall: four damped comb filters on the mono mix, run twice around the loop so the
        # reverb tail of the last bar is already ringing when the first bar starts.
        dry = [(self.left[i] + self.right[i]) * 0.5 for i in range(n)]
        wet = [0.0] * n
        for delay_ms, feedback in ((29.7, 0.80), (37.1, 0.78), (41.1, 0.76), (43.7, 0.74)):
            size = int(delay_ms * RATE / 1000)
            line = [0.0] * size
            low = 0.0
            at = 0
            for turn in range(2):
                for i in range(n):
                    out = line[at]
                    low += (out - low) * 0.45
                    line[at] = dry[i] + low * feedback
                    at += 1
                    if at == size:
                        at = 0
                    if turn:
                        wet[i] += out
        spread = int(0.011 * RATE)
        for i in range(n):
            self.left[i] += wet[i] * 0.07
            self.right[i] += wet[(i - spread) % n] * 0.07
        peak = max(max(abs(s) for s in self.left), max(abs(s) for s in self.right))
        frames = bytearray()
        for i in range(n):
            frames += struct.pack("<hh", int(self.left[i] / peak * 0.82 * 32767), int(self.right[i] / peak * 0.82 * 32767))
        with tempfile.TemporaryDirectory() as folder:
            raw = os.path.join(folder, name + ".wav")
            with wave.open(raw, "wb") as f:
                f.setnchannels(2)
                f.setsampwidth(2)
                f.setframerate(RATE)
                f.writeframes(bytes(frames))
            subprocess.run(["sox", raw, "-C", "4", os.path.join(OUT, name + ".ogg")], check=True)
        print("wrote %s.ogg  (%d bars, %.0f s)" % (name, bars, n / RATE))


def arrange(song, chords, lines, lead, style, lead_volume=0.5, ring=0.0, second=None):
    """chords: one entry per bar, 'C' or 'F G' for a mid-bar change. lines: one melody string per bar.
    `second` is a voice that doubles the melody an octave down in the last quarter of each 8-bar phrase."""
    for bar, (names, line) in enumerate(zip(chords, lines)):
        at = bar * song.beats
        halves = names.split()
        song.melody(lead, bar, line, lead_volume, ring)
        if second and bar % 8 >= 6:
            low_line = " ".join(octave_down(token) for token in line.split())
            song.melody(second, bar, low_line, lead_volume * 0.45)
        for half, name in enumerate(halves):                # strings hold each chord
            span = song.beats / len(halves)
            for tone in chord_tones(name, 3)[1:] + chord_tones(name, 4)[:1]:
                song.note(strings, tone, at + half * span, span, 0.05 if style != "snow" else 0.075, 0.25)
        for beat in range(song.beats):
            name = halves[min(len(halves) - 1, beat * len(halves) // song.beats)]
            low = chord_tones(name, 2)
            mid = chord_tones(name, 3)
            high = chord_tones(name, 4)
            if style == "bounce":         # bass on the beats, guitar answers off them, marimba fills
                song.note(upright, low[0] if beat % 2 == 0 else low[2], at + beat, 0.9, 0.55)
                song.strum(mid, at + beat + 0.5, 0.11)
                song.note(marimba, high[(beat + 1) % 3] * 2, at + beat + 0.5, 0.4, 0.08, 0.35, 0.3)
                song.drum("kick" if beat % 2 == 0 else "brush", at + beat, 0.3 if beat % 2 == 0 else 0.16)
                song.drum("shaker", at + beat + 0.5, 0.06)
            elif style == "drive":        # walking bass, strummed guitar, a running marimba line
                song.note(upright, (low[0], low[2], low[0] * 2, low[2])[beat], at + beat, 0.9, 0.55)
                song.strum(mid, at + beat + 0.5, 0.12)
                if beat % 2 == 0:
                    song.strum(mid, at + beat, 0.07)
                for half in range(2):
                    step = beat * 2 + half
                    song.note(marimba, high[step % 3] * (2 if step % 4 != 3 else 4), at + beat + half * 0.5, 0.4, 0.075, 0.35, 0.25)
                song.drum("kick" if beat % 2 == 0 else "brush", at + beat, 0.3 if beat % 2 == 0 else 0.18)
                song.drum("shaker", at + beat + 0.5, 0.08)
                if beat == 3:
                    song.drum("block", at + beat + 0.5, 0.08)
            elif style == "waltz":        # low bass, then two guitar chords
                if beat == 0:
                    song.note(upright, low[0], at, 2.0, 0.55)
                    song.drum("kick", at, 0.14)
                else:
                    song.strum(mid, at + beat, 0.1)
                    song.drum("brush", at + beat, 0.07)
                    if beat == 2:
                        song.note(marimba, high[2] * 2, at + beat + 0.5, 0.4, 0.05, 0.35, 0.3)
            elif style == "snow":         # a slow harp under the music box, a soft bass, sleigh shaker
                if beat % 2 == 0:
                    song.note(upright, low[0] if beat == 0 else low[2], at + beat, 1.9, 0.34)
                for half in range(2):
                    step = beat * 2 + half
                    song.pluck(high[(0, 1, 2, 1, 2, 1, 0, 1)[step]], at + beat + half * 0.5, 0.085, -0.35, 1.6, 0.8)
                song.drum("shaker", at + beat + 0.5, 0.035)


def build(name, bpm, beats, style, sections, order, lead, seed, **kw):
    chords, lines = [], []
    for key in order:
        section_chords, section_lines = sections[key]
        chords += section_chords
        lines += section_lines
    song = Song(bpm, beats, seed)
    arrange(song, chords, lines, lead, style, **kw)
    song.save(name, len(chords))


# --- Spring: a bright, bouncy morning on the farm. C major. ---------------------------------------
SPRING_A = ["E5/.5 G5/.5 C6/1 G5/.5 E5/.5 G5/1", "A5/.5 G5/.5 E5/1 C5/1 -/1", "F5/.5 A5/.5 C6/1 A5/.5 F5/.5 A5/1",
            "G5/.5 B5/.5 D6/1 B5/1 G5/1", "E5/.5 G5/.5 C6/1 E6/.5 D6/.5 C6/1", "A5/1 C6/.5 A5/.5 E5/1 A5/1"]
SPRING = {
    "A": (["C", "C", "F", "G", "C", "Am", "F G", "C"],
          SPRING_A + ["F5/.5 G5/.5 A5/1 B5/.5 A5/.5 G5/1", "C6/2 -/.5 G5/.5 C6/1"]),
    "A2": (["C", "C", "F", "G", "C", "Am", "F G", "C"],
           SPRING_A + ["F5/.5 A5/.5 C6/1 B5/.5 G5/.5 D5/1", "C5/3 -/1"]),
    "B": (["Am", "Em", "F", "C", "Dm", "G", "C", "G"],
          ["A5/1.5 B5/.5 C6/1 E6/1", "D6/1 B5/1 G5/2", "A5/1.5 G5/.5 F5/1 A5/1", "G5/1 E5/1 C5/2",
           "D5/.5 F5/.5 A5/1 D6/1 C6/1", "B5/1 G5/1 D5/1 G5/1", "E5/.5 G5/.5 C6/1 G5/1 E5/1", "D5/1 G5/1 B5/1 D6/1"]),
}

# --- Summer: quick and sunny, with a running arpeggio. G major. --------------------------------------
SUMMER_A = ["D5/.5 G5/.5 B5/.5 D6/1 B5/.5 G5/1", "A5/.5 B5/.5 A5/.5 G5/1 D5/.5 G5/1", "E5/.5 G5/.5 C6/.5 E6/1 C6/.5 G5/1",
            "F#5/.5 A5/.5 D6/1 C6/.5 A5/.5 F#5/1", "G5/1 B5/.5 E6/1 B5/.5 G5/1", "E5/.5 G5/.5 C6/1 B5/.5 A5/.5 G5/1"]
SUMMER = {
    "A": (["G", "G", "C", "D", "Em", "C", "D", "G"],
          SUMMER_A + ["A5/.5 D6/.5 C6/.5 A5/.5 F#5/1 A5/1", "G5/2 -/1 D5/1"]),
    "A2": (["G", "G", "C", "D", "Em", "C", "D", "G"],
           SUMMER_A + ["A5/.5 B5/.5 C6/.5 D6/.5 F#6/1 A5/1", "G5/3 -/1"]),
    "B": (["C", "G", "C", "D", "Em", "Bm", "C", "D"],
          ["E6/1 C6/.5 G5/.5 C6/1 E6/1", "D6/1 B5/.5 G5/.5 B5/2", "E6/.5 E6/.5 C6/1 G5/1 C6/1", "D6/1.5 C6/.5 A5/1 F#5/1",
           "G5/.5 B5/.5 E6/1 D6/1 B5/1", "F#5/.5 B5/.5 D6/1 B5/2", "C6/.5 B5/.5 A5/.5 G5/.5 E5/1 G5/1", "A5/1 D6/1 F#6/1 A5/1"]),
}

# --- Fall: a gentle harvest waltz. F major, leaning on D minor. ----------------------------------------
FALL_A = ["A5/1 C6/1 F5/1", "A5/2 F5/1", "D5/1 F5/1 Bb5/1", "G5/2 E5/1", "A5/1 C6/1 F6/1", "D6/2 A5/1"]
FALL = {
    "A": (["F", "Dm", "Bb", "C", "F", "Dm", "Gm C", "F"], FALL_A + ["Bb5/1 G5/1 E5/1", "F5/3"]),
    "A2": (["F", "Dm", "Bb", "C", "F", "Dm", "Gm C", "F"], FALL_A + ["G5/1 Bb5/1 E5/1", "F5/2 -/1"]),
    "B": (["Dm", "Am", "Bb", "F", "Gm", "Dm", "Bb", "C"],
          ["D6/1.5 E6/.5 F6/1", "E6/2 C6/1", "D6/1 Bb5/1 F5/1", "A5/2 C6/1", "Bb5/1 D6/1 G5/1", "A5/2 F5/1",
           "D5/1 F5/1 Bb5/1", "G5/2 C6/1"]),
}

# --- Winter: a slow music box over quiet snow. A minor. ---------------------------------------------
WINTER_A = ["E5/1 A5/1 C6/2", "A5/1 F5/1 C6/2", "E5/1 G5/1 C6/1 E6/1", "D6/2 B5/2", "C6/1 A5/1 E5/2", "F5/1 A5/1 C6/2"]
WINTER = {
    "A": (["Am", "F", "C", "G", "Am", "F", "G", "Am"], WINTER_A + ["B5/1 D6/1 G5/2", "A5/4"]),
    "A2": (["Am", "F", "C", "G", "Am", "F", "G", "Am"], WINTER_A + ["B5/1 G5/1 D5/2", "A5/3 -/1"]),
    "B": (["F", "C", "Dm", "Am", "F", "C", "E", "E"],
          ["A5/1 C6/1 F6/2", "E6/1 C6/1 G5/2", "F5/1 A5/1 D6/2", "C6/1 A5/1 E5/2", "F5/1 A5/1 C6/1 A5/1",
           "G5/1 C6/1 E6/2", "E6/1 B5/1 G#5/2", "E5/2 G#5/1 B5/1"]),
}

if __name__ == "__main__":
    wanted = sys.argv[1:]
    for name, args in (
        ("spring", dict(bpm=120, beats=4, style="bounce", sections=SPRING, lead=flute, seed=1, second=reed)),
        ("summer", dict(bpm=138, beats=4, style="drive", sections=SUMMER, lead=flute, seed=2, second=marimba)),
        ("fall", dict(bpm=108, beats=3, style="waltz", sections=FALL, lead=reed, seed=3, lead_volume=0.3, second=flute)),
        ("winter", dict(bpm=80, beats=4, style="snow", sections=WINTER, lead=music_box, seed=4, lead_volume=0.5, ring=0.9)),
    ):
        if not wanted or name in wanted:
            build(name, order=["A", "A2", "B", "A2"], **args)
