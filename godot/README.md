# Cranebonistan (Godot)

The Godot 4.7 version of the game. The browser version in the repository root is the reference until this one catches up.

- `scripts/sim.gd`: the rules (autoload `Game`): a line-for-line port of `sim.js`, `world.js` and `voice.js`.
- `data/content.json`: all content (regions, parties, events, sound bites, crises, the map). Generated from the browser files with `node tools/export_content.js`; edit the browser files, then regenerate.
- `tests/parity.gd`: plays a seeded game with a fixed script. `tools/parity.js` plays the same script with the browser rules. The two traces should match: same random draws, same seats and crisis; vote shares agree to about five decimal places.

Run the comparison:

```
node tools/parity.js 42
godot --headless --path godot -s tests/parity.gd -- 42
```
