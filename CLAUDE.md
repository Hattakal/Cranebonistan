# CLAUDE.md

Instructions for Claude Code sessions working on Cranebonistan. Read this first, then [README.md](README.md) (what the game is, file map) and [DESIGN.md](DESIGN.md) (every design decision and why).

## Who decides what

Ozan is the designer. The game must stay *his* game: propose, explain trade-offs, and let him decide on anything that changes how the game plays or what the world is. Build freely on things he has already decided. When you disagree, say so plainly and once, with reasons; he asks for honest criticism. Record each decision he makes in DESIGN.md (decision, short history of what it replaced).

He tests by playing in the Godot editor (F5) and sends notes. Work in small stages, push each one, and say what to look at.

## Design principles (decided; don't drift from these)

- Enjoyable game first. The satire is second and must stay subtle: he would rather players miss the message and enjoy the game than the other way around. No caricature, no lecturing.
- The game never tells you to be a hypocrite; it makes hypocrisy pay. Taking business money while attacking the elites should be a viable, tempting play; scandal risk must not make it pointless.
- People vote for personalities first, policies second. Your public persona and *how you say things* matter most. Choosing the exact words is the core skill; some ways of saying things are simply right or wrong (gaffes).
- Playing calm and centrist should be possible, just harder.
- No religion in the game (deliberately). Keep content away from obvious real-country parallels, Turkey in particular (the map is being redrawn for this reason).
- Names: short words beat accurate phrases. Recognisable, slightly jokey city names are fine; people's names should not read as distinctly Turkish.
- Carlos Aster (advisor) is the voice of the interface, Knights of Honor style: hypes the player, spins every number but never lies about one, praises a gaffe only occasionally. Will be voice-acted. Margaret Teyl (party secretary) speaks in text only, rarely, when the player crosses a line.
- Running the country is out of scope for a long time. The election simulator must work really well first. Continuing after losing an election is a likely future direction.

## The project

- Godot 4.7, GDScript, project in `godot/`. The rules (no screen code) are a chain of files in `godot/scripts/rules/`, each extending the one before (base → voters → districts → media → party → scandals → rivals → world → moments), ending in `godot/scripts/sim.gd`, the autoload `Game`; see the top of `rules/base.gd`. A file may only call functions in itself or earlier in the chain; a call that must go the other way is declared as a hook at the bottom of `base.gd`. New constants and state variables go in `base.gd`. All content is JSON in `godot/data/`, edited directly. There is no browser version any more (old prototype on the `browser-version` branch; never merge it back).
- Seven axes: economy (State/Market), welfare (Welfare/Austerity), nation (Nationalist/Multicultural), society (Progressive/Traditional), order (Authority/Liberty), foreign (Hawk/Dove), system (Radical/Establishment). Positions run -100 (left label) to +100 (right label); "L"/"R" sides in keys like `nation:L`.
- **Keep it moddable.** Every data file is read through `Mods.data("<name>")` (`godot/scripts/mods.gd`), and every picture, sound and font through `Mods.texture/audio/asset_path`. Never read `res://data/` or `res://assets/` directly, and put new content in data files, not code. If the rules start depending on a new id, add it to the list in MODDING.md.
- `SAVE_VERSION` in sim.gd: bump it whenever the shape of the saved state changes (old saves then start a new game).

## Running and checking

Find the Godot executable first (it may not be on PATH; ask Ozan where it is if you can't find it). From the repository root:

`tools/check.sh [path-to-godot]` runs everything below in one go, and first boots the real game headless: the only check that loads the screen scripts. Run it before every push.

```
godot --headless --path godot -s tests/parity.gd -- 42     # plays a whole seeded game; must end with a RESULT line and no SCRIPT ERROR
godot --headless --path godot -s tests/debates.gd -- 7     # prints how debates develop and how many events happen (aim: ~1 event every 2-3 months)
godot --headless --path godot --import                     # needed after adding a new class_name script
godot --headless --path godot -s tests/scandals.gd -- deny 4   # a game that takes dirty money and answers every scandal one way (deny/own/attack/subject/scapegoat)
godot --headless --path godot -s tests/rivals.gd            # what the rival parties did over a whole game
godot --headless --path godot -s tests/strong.gd -- populist 2   # a competent player (populist | centrist | left), to measure difficulty; add e.g. nospeak,notrips or trace
```

Screenshots of the real game (use these to check any visual change; look at the image before claiming it works):

```
godot --path godot --resolution 1600x900 -- --shot=out.png --weeks=60 [--file=debates|electorate|platform|parties|media|polls|diary] [--tour=cranbia_5] [--profile=1] [--cheats=6] [--leak=1 --open=1] [--clear=1] [--scroll=700]
    [--open=1 --until=event|budget|debate|election --step2=1 --result=1] [--speak=0] [--raise=0] [--country=dillihan] [--carlos=tip] [--margaret=flip] [--build=1] [--then=0.5]
```

In the game, ` (backtick) or F12 opens the cheat panel (`godot/scripts/cheats.gd`): skip time, change money, support, trust, the world, rivals, queue any event. `--cheats=N` opens it in a screenshot after skipping N months. `--weeks` plays that many weeks automatically first; `--clear` empties the decision queue so files are usable; the other flags open specific sheets. (On Linux without a display, wrap it in `xvfb-run -a -s "-screen 0 1600x900x24"` and add `--rendering-driver opengl3`.)

## GDScript gotchas met in this project

- Don't use `:=` on values whose type Godot can't infer (anything from JSON/Dictionaries): a parse error makes headless runs hang because `quit()` is never reached. Use `=`. Always run headless commands with a timeout.
- Containers reset a child's rotation and scale: tilt cards via a wrapper control (see `Holder` in board.gd).
- Autowrapped labels need a minimum width or a sized parent, or they balloon or collapse.
- Signals connected after a node is added may miss `ready`; start tweens directly.
- The test games load only the rules: a parse error in a screen script (main, files, board, cheats...) only shows up when the game itself runs. After editing one, take a screenshot and check its log for SCRIPT ERROR.
- `Game.ssort` is a stable merge sort; use it instead of `sort_custom` where order matters.
- Lambdas capture loop variables by value per iteration in GDScript 4; fine to use in loops.

## Content and writing

- About 300 written lines live in `debate_lines.json`, `issues.json`, `carlos.json`, `margaret.json`; events and sound bites in `content.json`. Keep Ozan's voice: dry, grounded, specific to the world (Cranebo, Bayernal, Tarropolis, the pezo), never cartoonish.
- After changing Carlos's lines, run `python3 tools/voice_script.py` to regenerate VOICE.md (the recording script; recordings go in `godot/assets/voice/carlos/<id>.ogg`).
- The map is built from Ozan's Krita file: `python3 tools/build_map.py art/map3.kra` (writes `godot/data/map.json` and the map features image).

## Open items Ozan knows about

- Fauran is still written as nomads/herders in ~20 places; awaiting his new history.
- `scenes.json` (back-room intro with Carlos and Margaret) still describes old rules and isn't shown in Godot yet.
- **Visual direction (next):** the noir/old-print look clashes with the present-day setting. Options discussed: keep noir; "modern political drama" (dark office, warm desk lamp, cold desaturated halftone photos, colour only for party colours and a red accent; social media shown as printouts pinned to the board; the recommendation); screen-print poster; modern newsroom/TV. Agreed next step: three mock-ups of the same screen to compare. Zero budget: public-domain/CC0 photos given one shared newsprint treatment by a shader, open-licence fonts, CC0 sounds; no generative-AI art, ever; only Carlos's and Margaret's portraits might be commissioned.
- **Turnout (draft, not on main):** per-party turnout from trust and drift is on the branch `claude/project-overview-roadmap-3813b2-sjo7ds` (commit "Draft (not on main): per-party turnout…"). Trust works; the drift penalty is far too strong (a competent populist fell from ~23% to ~12%). Open questions for Ozan: drift only against core supporters? measured against the founding or the current manifesto? how far low trust may push turnout down.
- **Lore and names (Ozan is working on them):** his history of Cranebonistan and the world was discussed (comments: replace the religious split, add recent political history 1964–now, decide what Fauran is today). Planned renames: Büllünt → Vüllent, Crumland → Crümland, Cranbia cities lose -polis for "city" suffixes, Erland modelled on Castile and/or Alberta, possibly the country name itself (Cranebonia keeps "Cranebonian").
- Planned: personas, continuing after a lost election, event pictures and portraits, sound, exports.

## Git

Commit in small, described steps on `main` and push. Ozan pulls with GitHub Desktop. Never rewrite history or force-push.
