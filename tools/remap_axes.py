"""One-off: move content.json and debates.json from the old eight axes to the
seven agreed in November 2026. Old -> new:
  econ (laissez-faire- / planning+)  -> economy, sign flipped (State- / Market+)
  labor (workers- / business+)       -> economy, same sign
  gov (small- / big+)                -> welfare, sign flipped (Welfare- / Austerity+)
  nat (nationalist- / multicult+)    -> nation, same sign
  immig (pro- / restrictive+)        -> nation, sign flipped
  prog -> society, war -> foreign, rev -> system (same signs)
  order (Authority- / Liberty+) is new.
"""
import json, sys

MAP = {"econ": ("economy", -1), "labor": ("economy", 1), "gov": ("welfare", -1), "nat": ("nation", 1),
       "immig": ("nation", -1), "prog": ("society", 1), "war": ("foreign", 1), "rev": ("system", 1)}
OLD = set(MAP)
log = []

def positions(o, how):
    out = {}
    for k, v in o.items():
        if k not in MAP: out[k] = v; continue
        nk, sg = MAP[k]
        out.setdefault(nk, []).append(v * sg)
    res = {}
    for k, v in out.items():
        if not isinstance(v, list): res[k] = v; continue
        if len(v) == 1: res[k] = v[0]
        elif how == "sum":
            m = max(abs(x) for x in v) * 1.3
            res[k] = round(max(-m, min(m, sum(v))), 1)
        else: res[k] = round(sum(v) / len(v), 1)
        if isinstance(res[k], float) and res[k].is_integer(): res[k] = int(res[k])
    return res

def weights(o):
    res = {}
    for k, v in o.items():
        nk = MAP[k][0] if k in MAP else k
        res[nk] = max(res.get(nk, v), v)
    return res

def filters(o):
    res = {}
    for k, v in o.items():
        if k not in MAP: res[k] = v; continue
        nk, sg = MAP[k]
        if sg < 0: v = ("<" if v[0] == ">" else ">") + v[1:]
        if nk in res and res[nk] != v: log.append("filter clash %s: kept %s, dropped %s" % (nk, res[nk], v)); continue
        res[nk] = v
    return res

def indices(o):
    acc = {}
    for k, v in o.items():
        nk, sg = MAP[k]
        acc.setdefault(nk, []).append(v if sg > 0 else 4 - v)
    return {k: int(round(sum(v) / len(v) + 1e-9)) if len(v) == 1 else int(round(sum(v) / len(v))) for k, v in acc.items()}

def owns(o):
    res = {}
    for key, v in o.items():
        ax, side = key.split(":")
        nk, sg = MAP[ax]
        if sg < 0: side = "R" if side == "L" else "L"
        nkey = nk + ":" + side
        res[nkey] = max(res.get(nkey, 0), v)
    return res

def walk(o, path):
    if isinstance(o, dict):
        for k in list(o.keys()):
            v = o[k]
            if isinstance(v, dict) and set(v) & OLD:
                vals = list(v.values())
                if k == "lean" and vals and isinstance(vals[0], str): o[k] = filters(v)
                elif k == "lean": o[k] = positions(v, "avg")
                elif k == "shift": o[k] = positions(v, "sum")
                elif k == "manifesto" and "PARTY_TEMPLATES" in path: o[k] = indices(v)
                elif k == "manifesto": o[k] = positions(v, "avg")
                elif k in ("sal", "salience", "permSal"): o[k] = weights(v)
                else: log.append("UNHANDLED %s %s" % ("/".join(map(str, path)), k))
            elif k == "owns" and isinstance(v, dict): o[k] = owns(v)
            else: walk(v, path + [k])
    elif isinstance(o, list):
        for x in o: walk(x, path)

AXES = [
 {"id": "economy", "left": "State", "right": "Market", "issue": "The economy", "leftGroup": "supporters of state control", "rightGroup": "free marketeers",
  "stances": ["Socialist", "Statist", "Mixed economy", "Pro-market", "Free-market purist"]},
 {"id": "welfare", "left": "Welfare", "right": "Austerity", "issue": "Welfare & public services", "leftGroup": "welfare supporters", "rightGroup": "tax-cutters",
  "stances": ["Cradle to grave", "Generous", "Moderate", "Lean", "Austerity"]},
 {"id": "nation", "left": "Nationalist", "right": "Multicultural", "issue": "Nation & immigration", "leftGroup": "nationalists", "rightGroup": "multiculturalists",
  "stances": ["Ultranationalist", "Nationalist", "Neutral", "Multicultural", "Open borders"]},
 {"id": "society", "left": "Progressive", "right": "Traditional", "issue": "Social values", "leftGroup": "progressives", "rightGroup": "traditionalists",
  "stances": ["Radical progressive", "Progressive", "Moderate", "Traditional", "Ultra-traditional"]},
 {"id": "order", "left": "Authority", "right": "Liberty", "issue": "Law & order", "leftGroup": "law-and-order voters", "rightGroup": "civil libertarians",
  "stances": ["Iron fist", "Tough", "Balanced", "Rights first", "Hands off"]},
 {"id": "foreign", "left": "Hawk", "right": "Dove", "issue": "Defence & foreign policy", "leftGroup": "hawks", "rightGroup": "doves",
  "stances": ["Very hawkish", "Hawkish", "Neutral", "Doveish", "Pacifist"]},
 {"id": "system", "left": "Radical", "right": "Establishment", "issue": "The political system", "leftGroup": "anti-system voters", "rightGroup": "establishment voters",
  "stances": ["Radical", "Reformist", "Moderate", "Establishment", "Old guard"]},
]

# Order (Authority - / Liberty +) for the demographics and parties: first pass, to be tuned
ORDER = {
 "AGES": {"18-29": 20, "30-45": 5, "46-60": -5, "61+": -20},
 "CLASSES": {"working": -10, "middle": 0, "upper": -5},
 "NATIONALITIES": {"alinnian": 35, "norbanian": 15},
 "REGIONS": {"erland": -15, "cranbia": 5, "yamlin": 0, "alinni": -10, "fauraifai": -5},
 "PARTIES": {"nup": -35, "clf": 5, "oc": 35, "apv": 40},
 "PARTY_TEMPLATES": {"awakening": 2, "homeland": 1, "horizon": 3, "steppe": 1, "rage": 2, "custom": 2},
}
ORDER_SAL = {"61+": 1.2, "alinnian": 1.5}

def main(content, debates):
    d = json.load(open(content))
    walk(d, [])
    d["AXES"] = AXES
    for group, vals in ORDER.items():
        for x in d[group]:
            if x["id"] not in vals: continue
            if group == "PARTIES": x["manifesto"]["order"] = vals[x["id"]]
            elif group == "PARTY_TEMPLATES": x["manifesto"]["order"] = vals[x["id"]]
            else:
                x.setdefault("lean", {})["order"] = vals[x["id"]]
                if x["id"] in ORDER_SAL: x.setdefault("sal", {})["order"] = ORDER_SAL[x["id"]]
    d["VIEW_GROUPS"] = [
     {"id": "nationalists", "label": "Nationalists", "who": {"lean": {"nation": "<-30"}}},
     {"id": "multicultural", "label": "Multiculturalists", "who": {"lean": {"nation": ">30"}}},
     {"id": "statists", "label": "State-economy voters", "who": {"lean": {"economy": "<-25"}}},
     {"id": "freemarket", "label": "Free marketeers", "who": {"lean": {"economy": ">25"}}},
     {"id": "welfare", "label": "Welfare supporters", "who": {"lean": {"welfare": "<-30"}}},
     {"id": "progressives", "label": "Progressives", "who": {"lean": {"society": "<-25"}}},
     {"id": "traditionalists", "label": "Traditionalists", "who": {"lean": {"society": ">25"}}},
     {"id": "lawandorder", "label": "Law-and-order voters", "who": {"lean": {"order": "<-25"}}},
     {"id": "antisystem", "label": "Anti-system voters", "who": {"lean": {"system": "<-25"}}},
    ]
    json.dump(d, open(content, "w"), indent=1, ensure_ascii=False)
    t = json.load(open(debates))
    for x in t["TOPICS"]:
        nk, sg = MAP[x["axis"]]
        x["axis"] = nk
    json.dump(t, open(debates, "w"), indent=1, ensure_ascii=False)
    print("\n".join(log) or "no clashes")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
