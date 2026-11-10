#!/usr/bin/env python3
"""
build_map.py: turn the designer's Krita map (.kra) into the game's map.

    python3 tools/build_map.py path/to/map.kra

Reads these Krita layers (by name):
  Background            land (white or light grey); sea may be blue, or found from WATER_SEEDS
  States and Countries  border and coast lines (any colour); may also be called "Map"
  Rivers and Mountains  decoration only; never used as borders (optional)
  Cities                one dot per city
  (a vector/text layer) names typed next to each city; big text (area names) is skipped

Writes:
  godot/data/content.json   its MAP entry: shapes, label spots and cities (game coordinates)
  godot/assets/map-features.png   rivers and mountains, recoloured as ink

Areas are named by AREA_SEEDS below: a point (in Krita pixels) inside each area.
If a border is redrawn, those points usually still work; if an area gets
split or merged, adjust them.
"""
import html
import json
import os
import re
import sys
import zipfile

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 4          # Krita pixels per game unit (9920 px -> 2480 units)
WORK = 2           # work at half resolution

# A point inside each area, in Krita pixels. kind: region or foreign.
AREA_SEEDS = {
    "yamlin":    ("region",  (2552, 2011)),
    "cranbia":   ("region",  (3680, 600)),
    "alinni":    ("region",  (5934, 726)),
    "erland":    ("region",  (5334, 2628)),
    "fauraifai": ("region",  (3088, 4169)),   # shown as "Fauran"
    "trueants":  ("foreign", (7600, 1485)),
    "dillihan":  ("foreign", (7424, 4757)),
    "bourdeaux": ("foreign", (1180, 6313)),   # shown as "Bordon Federation"
    "james":     ("foreign", (2753, 5494)),
}
# Points in water, for maps whose sea isn't painted blue: the sea, the south-east sea, the lake.
WATER_SEEDS = [(500, 500), (8000, 6950), (4989, 681)]
CAPITAL = "Cranebo"
# Names on the map that the game spells differently.
NAME_FIX = {"Cranbero": "Cranebo"}
CITY_TEXT_MAX = 20   # text bigger than this (font size) is an area name, not a city
# Label text, used only to find room for it (the game has the real names).
LABELS = {"yamlin": ["Yamlin"], "cranbia": ["Cranbia"], "alinni": ["Alinni"], "erland": ["Erland"],
          "fauraifai": ["Fauran"], "trueants": ["Southern", "Trueants"], "dillihan": ["Dillihan", "Republic"],
          "bourdeaux": ["Bordon", "Federation"], "james": None}


# ---------- reading .kra layers ----------
def lzf_decompress(src, outlen):
    out = bytearray(outlen); i = o = 0; n = len(src)
    while i < n:
        ctrl = src[i]; i += 1
        if ctrl < 32:
            l = ctrl + 1; out[o:o + l] = src[i:i + l]; i += l; o += l
        else:
            l = ctrl >> 5; ref = o - ((ctrl & 0x1F) << 8) - 1
            if l == 7: l += src[i]; i += 1
            ref -= src[i]; i += 1; l += 2
            for _ in range(l):
                out[o] = out[ref]; o += 1; ref += 1
    return bytes(out)


def read_paint_layer(z, path, W, H):
    d = z.read(path); pos = 0
    default = z.read(path + ".defaultpixel")

    def line():
        nonlocal pos
        e = d.index(b"\n", pos); s = d[pos:e].decode(); pos = e + 1; return s
    hdr = {}
    for _ in range(5):
        k, v = line().split(" "); hdr[k] = int(v) if v.isdigit() else v
    tw, th, ps, n = hdr["TILEWIDTH"], hdr["TILEHEIGHT"], hdr["PIXELSIZE"], hdr["DATA"]
    img = np.zeros((H + th, W + tw, 4), np.uint8); img[:] = np.frombuffer(default, np.uint8)
    for _ in range(n):
        x, y, _c, size = line().split(","); x, y, size = int(x), int(y), int(size)
        blob = d[pos:pos + size]; pos += size
        if x < 0 or y < 0 or x >= W or y >= H: continue
        raw = lzf_decompress(blob[1:], tw * th * ps) if blob[0] == 1 else blob[1:]
        p = np.frombuffer(raw, np.uint8).reshape(ps, th, tw)  # planar B, G, R, A
        img[y:y + th, x:x + tw] = np.stack([p[2], p[1], p[0], p[3]], -1)
    return img[:H, :W]


def load_kra(path):
    z = zipfile.ZipFile(path)
    doc = z.read("maindoc.xml").decode()
    W, H = int(re.search(r'<IMAGE[^>]*\swidth="(\d+)"', doc).group(1)), int(re.search(r'<IMAGE[^>]*\sheight="(\d+)"', doc).group(1))
    imgname = re.search(r'<IMAGE[^>]*\sname="([^"]*)"', doc).group(1)
    layers, texts = {}, []
    for tag in re.findall(r"<layer [^>]*>", doc):
        attr = dict(re.findall(r'(\w[\w-]*)="([^"]*)"', tag))
        base = f"{imgname}/layers/{attr['filename']}"
        if attr.get("nodetype") == "paintlayer":
            layers[attr["name"]] = read_paint_layer(z, base, W, H)
        elif attr.get("nodetype") == "shapelayer":
            svg = z.read(base + ".shapelayer/content.svg").decode()
            vb = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', svg)
            s = W / float(vb.group(1))
            for t in re.finditer(r'<text[^>]*transform="translate\(([-\d.]+),\s*([-\d.]+)\)"[^>]*?font-size:\s*([\d.]+)[^>]*>(.*?)</text>', svg, re.S):
                x, y, fs = float(t.group(1)), float(t.group(2)), float(t.group(3))
                txt = re.sub(r"<[^>]+>", "", html.unescape(t.group(4))).strip()
                if txt and fs <= CITY_TEXT_MAX and x >= 0 and y >= 0:
                    w = len(txt) * 0.55 * fs
                    texts.append((NAME_FIX.get(txt, txt), (x + w / 2) * s, (y - fs * 0.35) * s))
    return W, H, layers, texts


def find_layer(layers, *names):
    for n in names:
        for k in layers:
            if k.strip().lower() == n.lower(): return layers[k]
    raise SystemExit(f"Missing layer: {names[0]}")


# ---------- areas ----------
def build_areas(bg, borders):
    b = bg[::WORK, ::WORK].astype(int); st = borders[::WORK, ::WORK]
    h, w = b.shape[:2]
    water = (b[..., 2] > 120) & (b[..., 0] < 90) & (b[..., 1] < 90) & (b[..., 3] > 0)
    line = st[..., 3] >= 60
    # border lines that stop just short of the map edge count as reaching it
    M = 30
    for sl in [(slice(h - M, h), slice(None)), (slice(0, M), slice(None))]:
        band = line[sl]; cols = band.any(0); band[:, cols] = True; line[sl] = band
    for sl in [(slice(None), slice(w - M, w)), (slice(None), slice(0, M))]:
        band = line[sl]; rows = band.any(1); band[rows, :] = True; line[sl] = band
    white = (b[..., 0] > 200) & (b[..., 1] > 200) & (b[..., 2] > 200) & ~line
    lab, n = ndimage.label(white)
    if not water.any():
        # sea not painted: the areas around the water seeds are water
        for sx, sy in WATER_SEEDS:
            L = lab[sy // WORK, sx // WORK]
            if L: water |= lab == L
        white &= ~water
        lab, n = ndimage.label(white)
    ids = {}
    seeds = np.zeros((h, w), np.int32)
    for k, (area_id, (_kind, (sx, sy))) in enumerate(AREA_SEEDS.items(), start=1):
        L = lab[sy // WORK, sx // WORK]
        if L == 0: raise SystemExit(f"Seed for {area_id} is not on open land; adjust AREA_SEEDS")
        if L in ids.values(): raise SystemExit(f"{area_id} shares an area with another seed: a border has a gap")
        ids[area_id] = L; seeds[lab == L] = k
    # every non-water pixel (borders, coast, small islands) joins its nearest area
    _, (iy, ix) = ndimage.distance_transform_edt(seeds == 0, return_indices=True)
    full = seeds[iy, ix]
    full[water] = 0
    return full, list(AREA_SEEDS.keys())


def mask_to_path(mask, eps=1.4):
    m = (mask * 255).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    contours, hier = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    parts = []
    k = WORK / SCALE
    for c in contours:
        if cv2.contourArea(c) < 40: continue
        c = cv2.approxPolyDP(c, eps, True).reshape(-1, 2)
        if len(c) < 3: continue
        pts = " ".join(f"{x * k:.1f} {y * k:.1f}" for x, y in c)
        parts.append("M" + pts + "Z")
    return "".join(parts)


def label_spot(mask, lines, obstacles):
    """Centre of the spot where the whole label fits, clear of cities, farthest from edges."""
    k = WORK / SCALE                      # work pixels -> game units
    d = ndimage.distance_transform_edt(np.pad(mask, 1))[1:-1, 1:-1]
    room = round(d.max() * k)
    if not lines:
        y, x = np.unravel_index(np.argmax(d), d.shape)
        return [round(x * k), round(y * k)], room
    free = (mask & ~obstacles).astype(np.uint8)
    region = len(lines) == 1
    char = 54 if region else 42           # game units per letter (see style.css), with margin
    w = max(len(l) for l in lines) * char + 30
    h = (110 if region else 62 * len(lines) + 20)
    for shrink in (1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.42):
        kw, kh = max(3, int(w * shrink / k)), max(3, int(h * shrink / k))
        fit = cv2.erode(free, np.ones((kh, kw), np.uint8), borderType=cv2.BORDER_CONSTANT, borderValue=0)
        if fit.any():
            score = np.where(fit > 0, d, -1)
            y, x = np.unravel_index(np.argmax(score), score.shape)
            # (x, y) is the centre of the box; the label's first line sits a little above it
            return [round(x * k), round(y * k), shrink], room   # centre of the label box, text scale
    y, x = np.unravel_index(np.argmax(d), d.shape)
    return [round(x * k), round(y * k)], room


def main(path):
    W, H, layers, texts = load_kra(path)
    bg = find_layer(layers, "Background")
    borders = find_layer(layers, "States and Countries", "Map")
    try:
        feats = find_layer(layers, "Rivers and Mountains")
    except SystemExit:
        feats = np.zeros((H, W, 4), np.uint8)   # none drawn yet
    cities_l = find_layer(layers, "Cities")

    full, order = build_areas(bg, borders)
    out = {"w": W // SCALE, "h": H // SCALE, "regions": {}, "foreign": {}, "cities": [], "capital": CAPITAL}

    # cities: dots matched to the nearest typed name
    cm = cities_l[..., 3] > 100
    lab, n = ndimage.label(cm)
    coms = ndimage.center_of_mass(cm, lab, range(1, n + 1)); sizes = ndimage.sum(cm, lab, range(1, n + 1))
    dots = [(x, y, s) for (y, x), s in zip(coms, sizes) if s > 200]
    # city dots and names are obstacles for area labels
    obstacles = np.zeros(full.shape, np.uint8)
    for name, tx, ty in texts:
        x, y, _s = min(dots, key=lambda d: (d[0] - tx) ** 2 + (d[1] - ty) ** 2)
        hw = (len(name) * 17 + 40) * SCALE // WORK // 2
        for cx, cy, rx, ry in [(x, y, 24 * SCALE // WORK, 24 * SCALE // WORK), (tx, ty, hw, 22 * SCALE // WORK)]:
            cv2.rectangle(obstacles, (int((cx - rx) / WORK), int((cy - ry) / WORK)), (int((cx + rx) / WORK), int((cy + ry) / WORK)), 1, -1)
    obstacles = obstacles.astype(bool)
    for k, area_id in enumerate(order, start=1):
        kind = AREA_SEEDS[area_id][0]
        mask = full == k
        spot, room = label_spot(mask, LABELS.get(area_id), obstacles)
        out["regions" if kind == "region" else "foreign"][area_id] = {"d": mask_to_path(mask), "label": spot, "room": room}

    med = float(np.median([d[2] for d in dots]))
    print("city dots (px):", sorted(int(d[2]) for d in dots), "median", int(med))
    for name, tx, ty in texts:
        x, y, s = min(dots, key=lambda d: (d[0] - tx) ** 2 + (d[1] - ty) ** 2)
        k = full[int(y) // WORK, int(x) // WORK]
        out["cities"].append({"name": name, "x": round(x / SCALE), "y": round(y / SCALE),
                              "size": 3 if s > 1.5 * med else 2 if s > 0.75 * med else 1,   # dot size, relative to a typical dot
                              "area": order[k - 1] if k else None,
                              "lx": round(tx / SCALE), "ly": round(ty / SCALE)})

    # rivers and mountains as an ink overlay
    f = feats.astype(int)
    a = f[..., 3]
    blue = (f[..., 2] > f[..., 0] + 40) & (a > 0)
    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[blue] = (52, 98, 122, 0); rgba[~blue & (a > 0)] = (92, 62, 34, 0)
    rgba[..., 3] = a
    img = Image.fromarray(rgba, "RGBA").resize((W // SCALE, H // SCALE), Image.LANCZOS)
    godot = os.path.join(ROOT, "godot")
    img.save(os.path.join(godot, "assets", "map-features.png"), optimize=True)

    # the map lives inside the game's content file, next to everything else
    path = os.path.join(godot, "data", "content.json")
    content = json.load(open(path, encoding="utf-8"))
    content["MAP"] = out
    json.dump(content, open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"map: {len(out['regions'])} regions, {len(out['foreign'])} neighbours, {len(out['cities'])} cities")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "map.kra")
