# Cranebonistan (Godot)

The Godot 4.7 version of the game. The browser version in the repository root is the reference until this one catches up.

- `scripts/sim.gd`: the rules (autoload `Game`). It started as a line-for-line port of `sim.js`, `world.js` and `voice.js`; since November 2026 the Godot version has its own rules (see below), so the browser version is now behind.
- `data/content.json`: all game content. Since the axis rework it is edited here directly; `tools/export_content.js` would overwrite it with the old browser content, so don't run it. `tools/remap_axes.py` is the one-off script that moved the content to the seven axes.
- `data/debates.json`: debate topics, including the ones the economy starts by itself.
- `data/content.json`: all content (regions, parties, events, sound bites, crises, the map). Generated from the browser files with `node tools/export_content.js`; edit the browser files, then regenerate.
- `tests/parity.gd`: plays a seeded game with a fixed script. It matched `tools/parity.js` exactly until the Godot rules changed; now it is a smoke test that a whole game runs.
- `tests/debates.gd`: plays a game where the player fans one debate a month and prints how the national debate develops and how many events happen.

Run the comparison:

```
node tools/parity.js 42
godot --headless --path godot -s tests/parity.gd -- 42
```

## Godot-only rules

- **The national debate** is the main activity. Live debates have heat (how much people talk about it) and a lean (which side is winning the argument). Heat raises the issue's salience, so whoever owns that side gains; a debate that stays hot and one-sided slowly moves voters' opinions. The economy, the news, events, rival parties and the player start, fan or cool debates. Debates tire with age.
- 3 actions a month, shared between debate moves and the other actions. Starting a debate (the old agenda slot) costs an action, one a month.
- Events are rarer (about one every two to three months). A debate that hits heat 75 brings one on, and hot debates make related events likelier.
- Every party holds at most two issues; dropping one loses the claim entirely.
