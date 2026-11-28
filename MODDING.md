# Modding Cranbovia

Almost everything in the game is data: the country, the parties, every event and line, the media, the map, the names, the balance settings. A mod changes that data, or the pictures and sounds, **without touching the game's own files**. Several mods can run together.

## Where mods go

A mod is a folder with a `mod.json` in it. The game looks for mod folders in:

| Where | When |
|---|---|
| `user://mods/` (the game's data folder; on Windows `%APPDATA%\Godot\app_userdata\Cranbovia\mods\`) | always |
| a `mods` folder next to the game's executable | the exported game |
| `mods/` at the top of this repository | running from the Godot editor |

`mod.json`:

```json
{
 "name": "Harder Elections",
 "version": "1.0",
 "description": "Fewer actions, angrier voters.",
 "enabled": true,
 "priority": 0
}
```

Mods load by `priority` (lower first), then by folder name; when two mods change the same thing, the later one wins. `"enabled": false` switches a mod off. The founding sheet lists the mods in use, and a save remembers which mods it was started with (loading it with different mods works, but you get a warning).

## Changing data

Put a file in your mod's `data/` folder with the **same name** as the game's file in `godot/data/`. You don't copy the whole file: write only what you change, and it is merged in.

| Game file | What's in it |
|---|---|
| `content.json` | Settings (`CONFIG`), the seven issues (`AXES`), ages, classes, nationalities, regions and their people, neighbours, rival parties, founding templates, events (`EVENTS`), money offers, initiatives, crises, tones, actions, the end-of-game archetypes |
| `map.json` | Region, neighbour and province shapes, cities (written by `tools/build_map.py`) |
| `districts.json` | Province names, fixed seats and local leans |
| `cities.json` | City population, size, lean and one-line fact |
| `debates.json`, `debate_lines.json`, `issues.json` | The national debate: topics, what the leader can say, local issues |
| `laws.json` | The government's programme: the bills it tables, what they change, the events they bring (lines for their debates in `debate_lines.json`) |
| `pledges.json` | The promises the leader can make after speaking in a debate: a big and a small one per side of each topic, and a promise to scrap each bill |
| `flagship.json`, `interview.json`, `final_debate.json` | The year-three promise, the year-one interview, the final debate |
| `media.json` | Outlets, personalities, their scandals, foreign money |
| `scandals.json`, `violence.json` | Secrets and how they leak; political violence and rivals' labels |
| `party.json` | Your party's founding politicians |
| `leader_types.json` | What kind of leader each group wants |
| `names.json` | Name pools by background (`POOLS`, by region `REGIONS` and by country abroad `FOREIGN`), and `YES_MEN`: one name in every background's language, for the yes-men who fill a drifting party |
| `tours.json` | Stories from the leader's trips |
| `carlos.json`, `margaret.json` | What Carlos and Margaret say |
| `news.json` | What the rules write about the parties and the country: rival scandals, new leaders, splits, their tours, adverts and leaks, the start of the campaign, new arguments, stories in the news, your own politicians quitting |
| `mapmodes.json` | The map's modes (names, legends) and how distress is worked out |

Every game file starts with a `_note` explaining its fields.

### How merging works

- **Objects merge key by key.** `{"CONFIG": {"actionsPerMonth": 4}}` changes one setting and keeps the rest.
- **A key set to `null` is removed.**
- **`"_replace": true`** inside an object replaces that whole object instead of merging.
- **Lists of things with an `"id"`** (events, parties, regions, outlets, crises…) merge by id: an id the game knows is merged into, a new id is added, and `{"id": "x", "_remove": true}` removes one. Lists of things with a `"name"` and no id merge by name.
- **Other lists are replaced**, unless you write `{"_append": [...]}`, which adds to the list (good for names and lines).

Examples:

```json
// data/content.json: a new event, a renamed rival leader, a setting
{
 "CONFIG": {"actionsPerMonth": 4},
 "PARTIES": [{"id": "oc", "leader": "Camille Fontanel", "leaderHome": "Giloford"}],
 "EVENTS": [{"id": "my_ferry_strike", "kind": "regional", "title": "Ferry crews strike in Nikecisa", "text": "...",
   "choices": [{"label": "Back the crews", "effects": {"shift": {"economy": -6}}}]}]
}
```

```json
// data/names.json: more Yamlin names
{"POOLS": {"yamlin": {"m": {"_append": ["Ettore", "Filippo"]}}}}
```

```json
// data/content.json: remove an event
{"EVENTS": [{"id": "port_automation", "_remove": true}]}
```

### The country's name

Texts never spell out the country's name: they write `{country}` (Cranbovia), `{national}` (Cranbovian) and `{nationals}` (Cranbovians), filled in when the data loads from `COUNTRY` in content.json. To rename the country, change only that, and write the same words in your own texts:

```json
// data/content.json
{"COUNTRY": {"name": "Ostmark", "national": "Ostmarker", "nationals": "Ostmarkers"}}
```

A working example is in `mods/example-more-cities/` (switched off; set `"enabled": true` to try it).

## Changing pictures, sounds and fonts

Which outlet breaks each kind of event is `BREAKS` in `data/media.json`; an event can name its own with `"source": "<outlet id>"`.


Put a file in your mod's `assets/` folder at the same path as in `godot/assets/`, and it is used instead:

- Photographs (`.jpg`, `.png` or `.webp`; all are shown through the game's one filter): `assets/events/<event id>.jpg` or `assets/events/_<kind>.jpg`, `assets/portraits/<leader-name>.jpg` or `<party id>.jpg`, `assets/tours/<region>_<great|good|flat>.jpg` or `assets/tours/<great|good|flat>.jpg`, `assets/places/<country id>.jpg`. [IMAGES.md](IMAGES.md) has the full list. A mod can add pictures the game doesn't have yet
- `assets/voice/carlos/<line id>.ogg`: Carlos's voice (ids are in `carlos.json` and `VOICE.md`)
- `assets/map-features.png`: rivers and mountains on the map
- `assets/icons/<name>.svg`, `assets/fonts/<file>.ttf` (the file names are at the top of `godot/scripts/look.gd`)

## Things the game relies on

The rules refer to a few things by id. Change their names, numbers and text freely, but **don't remove them**:

- **Party** `player`; **politician** `teyl` (Margaret Perkins).
- **Region** `alinni`, and **nationalities** `cranebonian`, `alinnian`, `norbanian`.
- **Ages** `18-29`, `30-45`, `46-60`, `61+`; **classes** `working`, `middle`, `upper`.
- **Tones** `statesman`, `fiery`, `folksy`, `hopeful` (the four styles), and `provocative` (the sharp edge on a style: a line with `"sharp": true` gets its reactions on top of half its style's). Each tone in `TONES` has a `name` and a `pitch` shown when the player picks how to come across; an outlet's `tones` say how much it likes each.
- **World numbers** `jobs`, `prices`, `migration`, `border`, `unrest`.
- **Money offers** `chamber` and `tycoon` (business money that feeds hypocrisy).
- **Leader types** `star`, `statesman`, `revolutionary`, `strongman`, `one_of_us`, `clean`, `expert`, `visionary`.
- **`SMALL_TASKS`** in content.json: the small things the leader can do with no actions left.
- **`STYLE_NOTES`** in content.json: what each speaking-style label means (keyed by the label).
- **`PARTY_HISTORY`** in content.json: grudges and favours between parties at the start (`parties`, `amt`, `why`).
- **Outlets** `cbc` (the state broadcaster: the evening news, the TV debate, election night, the ticker) and `herald` (the paper of record: the news sheet, the ending's column).
- **Media kinds** `public`, `paper`, `tabloid`, `business`, `network`, `online`, `regional`, `platform`, `foreign`, `influencer`.
- **The seven issues** (`economy`, `welfare`, `nation`, `society`, `order`, `foreign`, `system`).
- **`COUNTRY`** in content.json (`name`, `national`, `nationals`).
- `MINOR_PARTIES` in content.json (merged by id, like `PARTIES`) and `CONFIG.threshold` (the share of the vote needed for seats; 0 turns it off).
- **Ministry** `pm` (the Prime Minister) in coalition.json; the outcome ids in its `OUTCOMES`.
- **Map modes** `vote`, `known`, `issues`, `fed`, `distress`, `local`, `past` in mapmodes.json (rename, reorder or drop them; a new id shows nothing).

## What a mod can't change (yet)

- **The rules themselves:** how voters choose, what an action does. They live in `godot/scripts/rules/`. You can change their numbers through `CONFIG` and the data, but not the logic.
- **Some interface text** is still written in the screens' code.
- **Old saves:** a save started without your mod keeps the parties, voters and outlets it was started with.

## Testing a mod

Run the game from the editor with your mod in `mods/`. The cheat panel (` or F12) skips time and queues any event by id, including yours. `godot --headless --path godot -s tests/mods.gd` checks that the loader works, and `tools/check.sh` runs every check.
