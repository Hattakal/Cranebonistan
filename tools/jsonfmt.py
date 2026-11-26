"""Write JSON the way the hand-edited data files are laid out: one item per line where it fits.

Usage: python3 tools/jsonfmt.py godot/data/issues.json [...]   (rewrites the files in place)
A dict or list that fits in WIDTH characters stays on one line; bigger ones open up, one
entry per line, indented by one space per level."""
import json, sys

WIDTH = 160

def dump(v, ind=0):
    flat = json.dumps(v, ensure_ascii=False)
    if len(flat) + ind <= WIDTH or not isinstance(v, (dict, list)) or not v:
        return flat
    pad = " " * (ind + 1)
    if isinstance(v, dict):
        items = [pad + json.dumps(k, ensure_ascii=False) + ": " + dump(x, ind + 1) for k, x in v.items()]
        return "{\n" + ",\n".join(items) + "\n" + " " * ind + "}"
    items = [pad + dump(x, ind + 1) for x in v]
    return "[\n" + ",\n".join(items) + "\n" + " " * ind + "]"

if __name__ == "__main__":
    for path in sys.argv[1:]:
        data = json.load(open(path, encoding="utf-8"))
        out = dump(data) + "\n"
        assert json.loads(out) == data
        open(path, "w", encoding="utf-8").write(out)
        print(path)
