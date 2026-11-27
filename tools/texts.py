#!/usr/bin/env python3
"""
texts.py: every line a player reads, in one spreadsheet, and back again.

    python3 tools/texts.py export        writes texts.csv (open it in Excel, LibreOffice or Google Sheets)
    python3 tools/texts.py apply         copies the "new" column of texts.csv back into the files

texts.csv has one row per text: how often a player sees it (1 = all the time, 2 = often,
3 = once a game or less), the file, where in the file it is, the text, and an empty "new"
column. Write your version in "new" (leave it empty to keep the text), save as CSV, run
apply, and check the game. Rows from the screen code (.gd) are applied by finding the old
text on its line; if the line changed since the export, the row is skipped and reported.
Placeholders in braces ({leader}, {city}...) must stay as they are.
Export again after the data changes: paths point into the files as they were.
After changing Carlos's lines, run tools/voice_script.py too (the recording script).
"""
import csv, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "godot", "data")
OUT = os.path.join(ROOT, "texts.csv")
SKIP_FILES = {"map.json", "cities.json", "mapmodes.json"}
SKIP_KEYS = {"id", "who", "kind", "tone", "axis", "region", "event", "type", "color", "emblem", "icon", "photo", "where",
             "provinces", "regions", "months", "when", "requires", "parties", "platform", "source", "sourceRegion", "outlet",
             "offer", "ministries", "short", "leaderHome", "home", "name_id"}
# how often a player meets a file or a section of it: 1 all the time, 2 often, 3 once or less
SEEN = {"carlos.json": 1, "margaret.json": 1, "debate_lines.json": 1, "news.json": 1, "issues.json": 1, "leader_types.json": 1,
        "interview.json": 2, "final_debate.json": 2, "flagship.json": 2, "tours.json": 2, "coalition.json": 2, "media.json": 2,
        "party.json": 2, "scandals.json": 3, "violence.json": 3, "papers.json": 3, "scenes.json": 3, "names.json": 3,
        "debates.json": 1, "districts.json": 3}
SEEN_CONTENT = {"TONES": 1, "STYLE_NOTES": 1, "SMALL_TASKS": 1, "INDICATORS": 1, "AXES": 1, "ACTIONS": 1, "CRISES": 2,
                "ARCHETYPES": 2, "FUNDING_OFFERS": 2, "INITIATIVES": 2, "PARTIES": 2, "MINOR_PARTIES": 2, "EVENTS": 3}

def is_text(s):
    return isinstance(s, str) and (len(s.split()) >= 3 or (len(s) >= 12 and " " in s)) and not s.startswith("res://")

def walk(v, path, out):
    if isinstance(v, dict):
        for k, x in v.items():
            if k.startswith("_") or k.endswith("NOTE") or k in SKIP_KEYS: continue
            walk(x, path + [k], out)
    elif isinstance(v, list):
        for i, x in enumerate(v): walk(x, path + [i], out)
    elif is_text(v):
        out.append((path, v))

def literals(line):
    """The string literals on a line of GDScript, in order (comments after # are ignored)."""
    out, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c == "#": break
        if c == '"':
            j, buf = i + 1, []
            while j < n and line[j] != '"':
                if line[j] == "\\" and j + 1 < n: buf.append(line[j:j + 2]); j += 2; continue
                buf.append(line[j]); j += 1
            out.append("".join(buf)); i = j + 1; continue
        i += 1
    return out

def export():
    rows = []
    for fn in sorted(os.listdir(DATA)):
        if not fn.endswith(".json") or fn in SKIP_FILES: continue
        data = json.load(open(os.path.join(DATA, fn), encoding="utf-8"))
        found = []
        walk(data, [], found)
        for path, text in found:
            seen = SEEN_CONTENT.get(str(path[0]), 2) if fn == "content.json" else SEEN.get(fn, 2)
            rows.append([seen, "godot/data/" + fn, "/".join(str(p) for p in path), text, ""])
    # texts written into the screen code: help, tooltips, buttons, stamps
    code = re.compile(r'"((?:[^"\\]|\\.){12,})"')
    for d in ["godot/scripts", "godot/scripts/rules"]:
        for fn in sorted(os.listdir(os.path.join(ROOT, d))):
            if not fn.endswith(".gd"): continue
            seen = 2 if d.endswith("rules") else 1
            for n, line in enumerate(open(os.path.join(ROOT, d, fn), encoding="utf-8"), start=1):
                if line.lstrip().startswith("#"): continue
                for t in literals(line):
                    if len(t) < 12 or " " not in t or t.startswith("res://") or len(t.split()) < 3: continue
                    rows.append([seen, f"{d}/{fn}", f"line {n}", t, ""])
    rows.sort(key=lambda r: (r[0], r[1]))
    with open(OUT, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["seen (1 always, 2 often, 3 rarely)", "file", "where", "text", "new"])
        w.writerows(rows)
    print(f"{len(rows)} texts written to texts.csv")

def apply():
    rows = list(csv.reader(open(OUT, encoding="utf-8-sig")))[1:]
    changed_files, done, skipped = {}, 0, []
    for seen, fn, where, old, new in rows:
        if not new.strip() or new == old: continue
        path = os.path.join(ROOT, fn)
        if fn.endswith(".json"):
            data = changed_files.setdefault(fn, json.load(open(path, encoding="utf-8")))
            keys = [int(k) if k.isdigit() else k for k in where.split("/")]
            node = data
            for k in keys[:-1]: node = node[k]
            if node[keys[-1]] != old: skipped.append(f"{fn} {where}: the text there changed"); continue
            node[keys[-1]] = new; done += 1
        else:
            lines = open(path, encoding="utf-8").read().split("\n")
            n = int(where.split()[1]) - 1
            if f'"{old}"' not in lines[n]: skipped.append(f"{fn} {where}: the line changed"); continue
            lines[n] = lines[n].replace(f'"{old}"', '"' + new.replace('"', '\\"') + '"', 1)
            open(path, "w", encoding="utf-8").write("\n".join(lines)); done += 1
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from jsonfmt import dump
    for fn, data in changed_files.items():
        open(os.path.join(ROOT, fn), "w", encoding="utf-8").write(dump(data) + "\n")
    print(f"{done} texts changed")
    for s in skipped: print("skipped:", s)

if __name__ == "__main__":
    {"export": export, "apply": apply}.get(sys.argv[1] if len(sys.argv) > 1 else "export", export)()
