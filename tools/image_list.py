#!/usr/bin/env python3
"""Writes IMAGES.md: how pictures are used, and the list of pictures the game can show,
with a tick beside the ones that are already in godot/assets/.

Run from the repository root after adding pictures or events:
    python3 tools/image_list.py
"""
import json, os, re

ROOT = os.path.join(os.path.dirname(__file__), "..")
ASSETS = os.path.join(ROOT, "godot", "assets")
EXTS = ["jpg", "jpeg", "png", "webp"]

def have(name):
    return any(os.path.exists(os.path.join(ASSETS, f"{name}.{e}")) for e in EXTS)

def tick(name):
    return "✓" if have(name) else " "

def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")

def load(name):
    with open(os.path.join(ROOT, "godot", "data", name + ".json"), encoding="utf-8") as f:
        return json.load(f)

content = load("content")
KINDS = {"crisis": "Crisis", "scandal": "Scandal", "foreign": "Foreign affairs", "opportunity": "Opportunity",
         "regional": "Regional issue", "trap": "Tricky moment", "followup": "Consequences",
         "flagship": "Flagship promise", "secret": "In confidence", "violence": "Political violence"}
HINTS = {"crisis": "an empty hospital corridor, a queue, a closed factory gate",
         "scandal": "a brown envelope, a car park at night, a shredder, a hotel lobby",
         "foreign": "a border post, flags outside a ministry, a warship on the horizon",
         "opportunity": "a crowd at a rally, a ribbon being cut, a factory floor",
         "regional": "a small-town high street, a harbour, a field with pylons",
         "trap": "a television studio, a row of microphones, cameras pointed at one chair",
         "followup": "the morning after: an empty hall, newspapers on a doormat",
         "flagship": "a campaign poster going up on a wall",
         "secret": "two people talking in a doorway, a phone face down on a table",
         "violence": "police tape, a broken shop window, a square at night"}

out = []
w = out.append
w("# Pictures")
w("")
w("*This file is written by `tools/image_list.py`. Edit the script, not this file; run it again after adding pictures or events.*")
w("")
w("The game shows photographs in four places. None is required: a missing picture is simply not shown, so pictures can go in one at a time.")
w("")
w("| Where it shows | File (in `godot/assets/`) | Shape |")
w("|---|---|---|")
w("| An event: on the desk, in the morning paper, and behind the evening news | `events/<event id>.jpg`; if there is none, `events/_<kind>.jpg` is used for every event of that kind | wide, about 16:9 |")
w("| The leader on the road | `tours/<region id>_<great, good or flat>.jpg`; if there is none, `tours/<great, good or flat>.jpg` | wide, about 3:1 (the middle band of a 16:9 picture is fine) |")
w("| A leader's face (top bar, the Parties and Country files) | `portraits/<leader's name in small letters with dashes>.jpg`, or `portraits/<party id>.jpg`; Carlos is `portraits/carlos.jpg` | square, face in the upper middle |")
w("| A neighbouring country's profile | `places/<country id>.jpg` | wide |")
w("")
w("`.jpg`, `.png` and `.webp` all work. About 1600 pixels wide is plenty (500 for a portrait).")
w("")
w("## The treatment")
w("")
w("Every picture goes through one filter (`godot/shaders/photo.gdshader`), so pictures from many sources look like they were printed by one newspaper. Nothing needs to be edited by hand first:")
w("")
w("- Colour is removed and the tones are pushed apart: deep shadows, clean highlights.")
w("- The picture is printed in two inks: blue-black shadows, and the paper itself as the light (on the television, a cold white with scan lines instead).")
w("- **Anything strongly red in the original stays red:** a flag, a tie, a fire, a stop sign. Everything else loses its colour. A picture with one red thing in it is worth looking for.")
w("- A fine halftone screen on paper, and darker corners.")
w("")
w("What works best: pictures taken at night or in hard light, with strong shapes and few small details; empty places rather than crowds of faces; nothing that pins the picture to a real country (readable signs, real flags, recognisable politicians or buildings). Daylight pictures work too, they come out as a pale print.")
w("")
w("Public-domain and CC0 pictures only, never generative AI. For each picture added, note the source and licence in [CREDITS.md](CREDITS.md).")
w("")
w("## The shortest useful list")
w("")
w("One picture per kind of event covers every event in the game. Start here:")
w("")
w("| Have | File | Used for | Something like |")
w("|---|---|---|---|")
kinds = []
for e in content["EVENTS"]:
    k = e.get("kind", "")
    if k and k not in kinds: kinds.append(k)
for k in ["flagship", "secret", "violence"]:
    if k not in kinds: kinds.append(k)
for k in kinds:
    n = sum(1 for e in content["EVENTS"] if e.get("kind") == k)
    w(f"| {tick('events/_' + k)} | `events/_{k}.jpg` | {KINDS.get(k, k)}{f' ({n} events)' if n else ''} | {HINTS.get(k, '')} |")
for k, hint in [("great", "a packed hall, hands in the air"), ("good", "a market square, a handshake over a stall"), ("flat", "rows of empty chairs, one man listening")]:
    w(f"| {tick('tours/' + k)} | `tours/{k}.jpg` | A trip that went {'very well' if k == 'great' else ('well' if k == 'good' else 'badly')} | {hint} |")
w("")
w("## Faces")
w("")
w("| Have | File | Who |")
w("|---|---|---|")
w(f"| {tick('portraits/carlos')} | `portraits/carlos.jpg` | Carlos Aster, your advisor (until then: a silhouette against the lamp) |")
for p in content["PARTIES"]:
    if p.get("isPlayer"): continue
    w(f"| {tick('portraits/' + p['id'])} | `portraits/{p['id']}.jpg` | The leader of {p.get('name', p['id'])}, whoever it is this game |")
for l in content.get("LEADER_POOL", []):
    w(f"| {tick('portraits/' + slug(l['name']))} | `portraits/{slug(l['name'])}.jpg` | {l['name']} ({'woman' if l.get('sex') == 'f' else 'man'}, {l.get('age', '')}) |")
for t in content.get("PARTY_TEMPLATES", []):
    if t.get("leader"):
        w(f"| {tick('portraits/' + slug(t['leader']))} | `portraits/{slug(t['leader'])}.jpg` | {t['leader']}, your leader if you pick {t['name']} |")
w("")
w("A face for a name wins over a face for a party. Your own leader can also be `portraits/player.jpg`.")
w("")
w("## Neighbours")
w("")
w("| Have | File | Country |")
w("|---|---|---|")
for f in content["FOREIGN"]:
    w(f"| {tick('places/' + f['id'])} | `places/{f['id']}.jpg` | {' '.join(f['name'])} |")
w("")
w("## Every event")
w("")
w("For when the short list is done: a picture of its own for one event.")
w("")
for k in kinds:
    evs = [e for e in content["EVENTS"] if e.get("kind") == k]
    if not evs: continue
    w(f"### {KINDS.get(k, k)}")
    w("")
    w("| Have | File | Headline |")
    w("|---|---|---|")
    for e in evs:
        w(f"| {tick('events/' + e['id'])} | `events/{e['id']}.jpg` | {e['title']} |")
    w("")

with open(os.path.join(ROOT, "IMAGES.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(out).rstrip() + "\n")
print("IMAGES.md written:", sum(1 for l in out if l.startswith("| ✓")), "pictures in place")
