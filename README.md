# Cranebonistan

A political election simulator set in the fictional country of Cranebonistan, made in Godot 4.7. You found a new party and have four years to become the largest party in the National Assembly. Money, attention and votes go to whoever plays the game best, and the game never tells you to be a hypocrite; it just makes it pay.

Art, fonts and licences are listed in [CREDITS.md](CREDITS.md). Every design decision, and why it was made, is in [DESIGN.md](DESIGN.md).

## Running it

Open the `godot` folder in Godot 4.7 (Import, then pick `godot/project.godot`) and press F5. The game saves to Godot's user folder; a change to the rules starts a new game.

The browser (HTML/JavaScript) prototype was retired in November 2026. It is kept in the repository history on the branch `browser-version`.

## How it plays

- **Four years, monthly decisions.** A tracking poll every month, a detailed poll every December, a quarterly budget, the final debate, then the election.
- **Pops.** About 170 population groups (region × age × class × nationality) with views on seven axes: Economy (State ↔ Market), Welfare (Welfare ↔ Austerity), Nation (Nationalist ↔ Multicultural), Society (Progressive ↔ Traditional), Order (Authority ↔ Liberty), Foreign (Hawk ↔ Dove) and System (Radical ↔ Establishment).
- **Manifesto.** One stance per axis. Voters then judge you by what you say; drifting one stance is free, beyond that it costs you.
- **The national debate** is the main activity. Live debates have heat (how much the country talks about it) and a tug of war (which side is winning). The economy, the news, events, rival parties and you start, fan or cool them. A hot debate helps whoever owns that side; one that stays hot and one-sided slowly changes what people believe.
- **Three actions a month**, shared between debate moves, championing up to two issues, grassroots organising, opposition research, dossiers, recruiting defectors and provoking outrage.
- **Events** every two to three months. Choose what to say, then the exact words; the wording shapes your leader's style and can go viral or become a gaffe.
- **The state of the nation.** Jobs, prices, migration, border tension and the public mood drift and push each other.
- **One major crisis** in the second year, from five. Your campaign can make one up to twice as likely.
- **Living rivals, trust in politics, a leader cult, dirty money.**
- **The final debate and the profile.** Rivals quote you against yourself; at the end a hostile newspaper writes your story.

## Files

| Path | What it holds |
|------|---------------|
| `godot/data/content.json` | All game content: balance settings (`CONFIG`), axes, demographics, regions, neighbours, parties, events and their sound bites, initiatives, crises, the map. Edited directly |
| `godot/data/debates.json` | Debate topics, including the ones the economy starts by itself |
| `godot/data/scenes.json` | Back-room dialogue with Carlos Aster and Margaret Teyl (not yet shown in the Godot version) |
| `godot/scripts/sim.gd` | The rules (autoload `Game`). No screen code |
| `godot/scripts/main.gd` | Headquarters: top bar, layout, decision sheets, saving |
| `godot/scripts/board.gd` | The evidence board: what needs you now |
| `godot/scripts/files.gd` | The planning files along the top bar |
| `godot/scripts/paper.gd` | Decision sheets as paper: front pages, index cards, the ledger |
| `godot/scripts/map_view.gd` | The map |
| `godot/scripts/look.gd` | Colours, fonts and small builders |
| `godot/assets/` | Fonts, icons, flags, the map's rivers and mountains; `events/` and `portraits/` for pictures to come |
| `godot/tests/` | `parity.gd` plays a whole seeded game as a smoke test; `debates.gd` prints how the national debate develops |
| `tools/build_map.py` | Builds the map from the Krita file |
| `tools/remap_axes.py` | One-off script that moved the content from eight axes to seven |

Run the tests from the repository root:

```
godot --headless --path godot -s tests/parity.gd -- 42
godot --headless --path godot -s tests/debates.gd -- 7
```

## Setting

Cranebonistan has five regions: Cranbia (capital Cranebo, industrial and educated), Yamlin (trade gateway, mixed and tense), Erland (nationalist breadbasket), Alinni (conquered from the Southern Trueants fifty years ago, minority-heavy) and Fauran (the poorest). Its neighbours are the Southern Trueants, the Dillihan Republic, the Bordon Federation and James. Further away are Golba, Norbanistan and Potania. The map is being redrawn.

## Updating the map

The map is drawn in Krita (layers: Background, States and Countries, Rivers and Mountains, Cities, and a text layer with the city names). To rebuild the game's map from a new version:

```
python3 tools/build_map.py path/to/map.kra
```

This rewrites the `MAP` entry in `godot/data/content.json` and `godot/assets/map-features.png`. It needs Python with numpy, scipy, opencv-python and Pillow. If a border is moved so much that an area no longer contains its seed point, adjust `AREA_SEEDS` at the top of the script.
