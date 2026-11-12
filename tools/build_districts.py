#!/usr/bin/env python3
"""
build_districts.py: split each region of the game map into electoral districts.

    python3 tools/build_districts.py

Reads the region shapes and cities from the MAP entry in godot/data/content.json
(written by build_map.py, which also runs this at the end) and writes MAP.districts:
one entry per district with its shape, a label spot, its share of the region's
people and the cities inside it.

Districts are drawn automatically until the designer draws them in Krita: each
region gets DISTRICTS[region] compact districts around its cities, with gently
wavy borders. Names come from the biggest city inside, or from the direction
("North Erland"); rename them in godot/data/districts.json, not here.
"""
import json
import math
import os

import cv2
import numpy as np
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "godot", "data", "content.json")
CITIES = os.path.join(ROOT, "godot", "data", "cities.json")
DISTRICTS = {"cranbia": 7, "yamlin": 7, "erland": 7, "alinni": 6, "fauraifai": 6}
REGION_NAMES = {"cranbia": "Cranbia", "yamlin": "Yamlin", "erland": "Erland", "alinni": "Alinni", "fauraifai": "Fauran"}
K = 2            # work at half the game's resolution
SEED = 7         # change to get a different (still stable) split
WAVE = 18.0      # how wavy the borders are, in game units


def parse_path(d):
    polys = []
    for part in d.split("M"):
        nums = part.replace("Z", "").split()
        if len(nums) < 6: continue
        pts = np.array([[float(nums[i]), float(nums[i + 1])] for i in range(0, len(nums) - 1, 2)])
        polys.append(pts)
    return polys


def raster(polys, w, h):
    m = np.zeros((h, w), np.uint8)
    # even-odd, so holes (lakes) stay open
    for p in polys:
        layer = np.zeros_like(m)
        cv2.fillPoly(layer, [np.round(p / K).astype(np.int32)], 1)
        m ^= layer
    return m.astype(bool)


def mask_to_path(mask):
    m = (mask * 255).astype(np.uint8)
    contours, _ = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    parts = []
    for c in contours:
        if cv2.contourArea(c) < 6: continue
        c = cv2.approxPolyDP(c, 0.8, True).reshape(-1, 2)
        if len(c) < 3: continue
        parts.append("M" + " ".join(f"{x * K:.1f} {y * K:.1f}" for x, y in c) + "Z")
    return "".join(parts)


def smooth_noise(h, w, rng, scale):
    """Low-frequency noise in [-1, 1]: a coarse random grid blown up smoothly."""
    gh, gw = max(2, int(h / scale)), max(2, int(w / scale))
    g = rng.uniform(-1, 1, (gh, gw)).astype(np.float32)
    return cv2.resize(g, (w, h), interpolation=cv2.INTER_CUBIC)


def kmeans(points, k, init, iters=25):
    c = np.array(init, float)
    for _ in range(iters):
        d = ((points[:, None, :] - c[None, :, :]) ** 2).sum(-1)
        lab = d.argmin(1)
        for j in range(k):
            sel = points[lab == j]
            if len(sel): c[j] = sel.mean(0)
    return c


def direction(dx, dy):
    a = (math.degrees(math.atan2(-dy, dx)) + 360) % 360
    names = ["East", "North-East", "North", "North-West", "West", "South-West", "South", "South-East"]
    return names[int((a + 22.5) // 45) % 8]


def main():
    content = json.load(open(CONTENT, encoding="utf-8"))
    m = content["MAP"]
    info = json.load(open(CITIES, encoding="utf-8"))["CITIES"] if os.path.exists(CITIES) else {}
    w, h = m["w"] // K, m["h"] // K
    rng = np.random.default_rng(SEED)
    out = []
    for region, k in DISTRICTS.items():
        mask = raster(parse_path(m["regions"][region]["d"]), w, h)
        ys, xs = np.nonzero(mask)
        pts = np.stack([xs, ys], 1).astype(float)
        sample = pts[rng.choice(len(pts), min(len(pts), 6000), replace=False)]
        cities = [c for c in m["cities"] if c["area"] == region]
        pop = {c["name"]: float(info.get(c["name"], {}).get("population", 0.1)) for c in cities}
        # start from the cities (biggest first), then the points farthest from them
        init = [(c["x"] / K, c["y"] / K) for c in sorted(cities, key=lambda c: -pop[c["name"]])][:k]
        while len(init) < k:
            d = np.min([((sample - np.array(p)) ** 2).sum(1) for p in init], 0) if init else np.zeros(len(sample))
            init.append(tuple(sample[d.argmax()]))
        centres = kmeans(sample, k, init)
        # nearest centre, with smooth noise so the borders wander a little
        dist = np.stack([np.hypot(np.arange(w)[None, :] - cx, np.arange(h)[:, None] - cy) for cx, cy in centres])
        for j in range(k): dist[j] += smooth_noise(h, w, rng, 60 / K) * (WAVE / K)
        lab = dist.argmin(0) + 1
        lab[~mask] = 0
        # keep each district in one piece: stray bits join their neighbours
        for j in range(1, k + 1):
            comp, n = ndimage.label(lab == j)
            if n > 1:
                sizes = ndimage.sum(np.ones_like(comp), comp, range(1, n + 1))
                keep = int(np.argmax(sizes)) + 1
                lab[(comp > 0) & (comp != keep)] = 0
        _, (iy, ix) = ndimage.distance_transform_edt(lab == 0, return_indices=True)
        lab = lab[iy, ix]; lab[~mask] = 0
        area_total = float(mask.sum())
        cy0, cx0 = ys.mean(), xs.mean()
        names_used = set()
        districts = []
        for j in range(1, k + 1):
            dm = lab == j
            if not dm.any(): continue
            inside = [c["name"] for c in cities if lab[min(h - 1, int(c["y"] / K)), min(w - 1, int(c["x"] / K))] == j]
            dt = ndimage.distance_transform_edt(np.pad(dm, 1))[1:-1, 1:-1]
            ly, lx = np.unravel_index(np.argmax(dt), dt.shape)
            dy, dx = np.nonzero(dm)
            if inside:
                name = max(inside, key=lambda n: pop[n])
            else:
                name = f"{direction(dx.mean() - cx0, dy.mean() - cy0)} {REGION_NAMES[region]}"
                if name in names_used: name = f"Upper {name}" if dy.mean() < cy0 else f"Lower {name}"
            names_used.add(name)
            districts.append({"region": region, "name": name, "d": mask_to_path(dm), "label": [int(lx * K), int(ly * K)],
                              "area": round(float(dm.sum()) / area_total, 4), "cities": inside})
        # people: half spread by land, half living in the cities
        city_total = sum(pop.values()) or 1.0
        for d in districts:
            d["share"] = round(0.5 * d["area"] + 0.5 * sum(pop[c] for c in d["cities"]) / city_total, 4)
        # ids by position (north to south, west to east) so they stay put between runs
        for i, d in enumerate(sorted(districts, key=lambda d: (d["label"][1] // 120, d["label"][0])), start=1):
            d["id"] = f"{region}_{i}"
        out.extend(sorted(districts, key=lambda d: d["id"]))
    m["districts"] = [{"id": d["id"], **{k2: v for k2, v in d.items() if k2 != "id"}} for d in out]
    json.dump(content, open(CONTENT, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"districts: {len(out)} ({', '.join(f'{r} {sum(1 for d in out if d['region'] == r)}' for r in DISTRICTS)})")
    for d in out: print(f"  {d['id']:12} {d['name']:24} share {d['share']:.3f} cities {d['cities']}")


if __name__ == "__main__":
    main()
