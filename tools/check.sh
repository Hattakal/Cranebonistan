#!/bin/sh
# Run every check: the game boots with no script errors (this is the only check that loads
# the screens), then the test games. Usage: tools/check.sh [path-to-godot]
G="${1:-godot}"
cd "$(dirname "$0")/.." || exit 1
fail=0
out=$(timeout 180 "$G" --headless --path godot --quit-after 120 2>&1)
if echo "$out" | grep -q "SCRIPT ERROR"; then echo "BOOT: script errors"; echo "$out" | grep -A2 "SCRIPT ERROR" | head -12; fail=1; else echo "BOOT ok"; fi
for t in "mods.gd" "parity.gd -- 42" "debates.gd -- 7" "rivals.gd" "scandals.gd -- deny 4"; do
  out=$(timeout 600 "$G" --headless --path godot -s tests/$t 2>&1)
  if echo "$out" | grep -qE "SCRIPT ERROR|^FAIL"; then echo "$t: failed"; echo "$out" | grep -E -A2 "SCRIPT ERROR|^FAIL" | head -8; fail=1
  else echo "$t ok: $(echo "$out" | grep -E "RESULT|final support|money|FAIL" | tail -1)"; fi
done
exit $fail
