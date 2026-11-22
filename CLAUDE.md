# CLAUDE.md

Instructions for Claude Code sessions working on Cranbovia (the repository keeps its old name, Cranebonistan). Read this first, then [README.md](README.md) (what the game is, file map) and [DESIGN.md](DESIGN.md) (every design decision and why).

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

- Godot 4.7, GDScript, project in `godot/`. The rules (no screen code) are a chain of files in `godot/scripts/rules/`, each extending the one before (base → voters → districts → media → party → scandals → rivals → world → moments → coalition), ending in `godot/scripts/sim.gd`, the autoload `Game`; see the top of `rules/base.gd`. A file may only call functions in itself or earlier in the chain; a call that must go the other way is declared as a hook at the bottom of `base.gd`. New constants and state variables go in `base.gd`. All content is JSON in `godot/data/`, edited directly. There is no browser version any more (old prototype on the `browser-version` branch; never merge it back).
- Seven axes: economy (State/Market), welfare (Welfare/Austerity), nation (Nationalist/Multicultural), society (Progressive/Traditional), order (Authority/Liberty), foreign (Hawk/Dove), system (Radical/Establishment). Positions run -100 (left label) to +100 (right label); "L"/"R" sides in keys like `nation:L`.
- **Keep it moddable.** Every data file is read through `Mods.data("<name>")` (`godot/scripts/mods.gd`), and every picture, sound and font through `Mods.texture/audio/asset_path`. Never read `res://data/` or `res://assets/` directly, and put new content in data files, not code. If the rules start depending on a new id, add it to the list in MODDING.md.
- `SAVE_VERSION` in sim.gd: bump it whenever the shape of the saved state changes (old saves then start a new game).

## The look (decided; see DESIGN.md 7.1)

Neo-noir in a present-day setting: a campaign office at night. When adding or changing a screen:

- **Colours and fonts only from `look.gd`**, never a hex code in a screen script. There are two palettes, `study` (warm, the default) and `night` (cold), chosen in Options (`settings.gd`) or with `--look=night` in a screenshot: a colour belongs in both, so add it to `PALETTES`, and check new screens in both. Sizes go through `Look.fs()` so the Options' large text works. Dark surfaces (the desk, the files, the top bar) use `Look.dlabel`/`dcaps`, `Look.glass()` and `Look.dark_button()`; paper uses `Look.label`/`caps` (ink by default).
- **Cold and dark around you, clean white paper under the lamp in your hands** (not cream: Ozan found cream read as old newsprint). `LAMP` (amber) is the only warm light: hover, city lights, Carlos. Party colours are the only strong colours; on the dark, pass them through `Look.lit()`.
- **Red is rationed:** danger, and the one button to press next. Good news is `GOOD`/`GOOD_HI`, never red.
- **Paper or screen:** what the player reads and decides is a `Paper` sheet; what the country watches (evening news, interview, debate, election night) is the same sheet after `p.screen()`. Build with the sheet's own blocks (`p.text`, `p.card`, `p.chips`...), which recolour themselves on a screen.
- **An event is a plain event screen, Paradox-style:** `p.source(outlet, kind · date)` at the top (who broke it: `_broke_it()` in main.gd, from `BREAKS` in media.json), then the headline, picture, text and choices on the same sheet. Ozan called off the newspaper experiment (front pages, folded paper): don't bring it back unasked.
- **Tone: grit, but not grim.** Ozan found the first pass slightly too slick and depressing. Keep the dark palette; let lightness come from small dry details (a coffee ring), never from caricature.
- **The numbers stay plain.** The files are a clean briefing; don't dress data up as objects.
- **Photographs** go through `Photo` (one filter for all, `shaders/photo.gdshader`); faces through `Face`. Never draw a texture straight to the screen. A missing picture shows nothing.
- Fonts: `display*` Barlow Condensed (labels, numbers, buttons), `news*` Newsreader (headlines, papers, speech), `body*` Plex Sans Condensed, `type` Plex Mono (memos), `hand` Caveat (a margin note from Carlos, rarely).

## Running and checking

Find the Godot executable first (it may not be on PATH; ask Ozan where it is if you can't find it). From the repository root:

`tools/check.sh [path-to-godot]` runs everything below in one go, and first boots the real game headless: the only check that loads the screen scripts. Run it before every push.

```
godot --headless --path godot -s tests/parity.gd -- 42     # plays a whole seeded game; must end with a RESULT line and no SCRIPT ERROR
godot --headless --path godot -s tests/debates.gd -- 7     # prints how debates develop and how many events happen (aim: ~1 event every 2-3 months)
godot --headless --path godot --import                     # needed after adding a new class_name script
godot --headless --path godot -s tests/scandals.gd -- deny 4   # a game that takes dirty money and answers every scandal one way (deny/own/attack/subject/scapegoat)
godot --headless --path godot -s tests/rivals.gd            # what the rival parties did over a whole game
godot --headless --path godot -s tests/coalition.gd         # the coalition talks on made-up results, with extra parties
godot --headless --path godot -s tests/strong.gd -- populist 2   # a competent player (populist | centrist | left), to measure difficulty; add e.g. nospeak,notrips or trace
```

Screenshots of the real game (use these to check any visual change; look at the image before claiming it works):

```
godot --path godot --resolution 1600x900 -- --shot=out.png --weeks=60 [--file=debates|electorate|platform|parties|media|polls|diary] [--tour=cranbia_5] [--profile=1] [--cheats=6] [--leak=1 --open=1] [--clear=1] [--scroll=700]
    [--open=1 --until=event|budget|debate|election --step2=1 --result=1] [--speak=0] [--raise=0] [--country=dillihan] [--carlos=tip] [--margaret=flip] [--build=1] [--then=0.5] [--found=1] [--title=1 --then=4] [--look=night|study] [--options=1]
    [--until=election --coalition=6|end] [--seats=player:95,nup:80,clf:70,oc:35,apv:20]   # the coalition talks, 6 seconds in or at the end; --seats makes up a result
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

- Never write the country's name in data texts: use `{country}`, `{national}`, `{nationals}` (filled in from content.json `COUNTRY` when data loads, in `Mods.data`). In screen code use `G.COUNTRY.name`.
- About 300 written lines live in `debate_lines.json`, `issues.json`, `carlos.json`, `margaret.json`; events and sound bites in `content.json`. Keep Ozan's voice: dry, grounded, specific to the world (Cranebo, Bayernal, Tarroport, the pezo), never cartoonish.
- After changing Carlos's lines, run `python3 tools/voice_script.py` to regenerate VOICE.md (the recording script; recordings go in `godot/assets/voice/carlos/<id>.ogg`).
- After adding events or pictures, run `python3 tools/image_list.py` to regenerate IMAGES.md (where pictures go and which are missing).
- The map is built from Ozan's Krita file: `python3 tools/build_map.py art/map4.kra` (writes `godot/data/map.json` and the map features image).

## Open items Ozan knows about

- `scenes.json` (back-room intro with Carlos and Margaret) still describes old rules and isn't shown in Godot yet.
- **Visual direction (decided November 2026, first pass built; Ozan has not reviewed it yet):** neo-noir, "the campaign at night"; see DESIGN.md 7.1 and "The look" above. Still open: the photographs (Ozan is finding them; IMAGES.md is the list, written by `tools/image_list.py`), sound in Godot, time of day, election night province by province, portraits of Carlos and Margaret (might be commissioned). Zero budget: public-domain/CC0 photos, open-licence fonts, CC0 or synthesised sounds; no generative-AI art, ever.
- **Turnout (draft, not on main):** per-party turnout from trust and drift is on the branch `claude/project-overview-roadmap-3813b2-sjo7ds` (commit "Draft (not on main): per-party turnout…"). Trust works; the drift penalty is far too strong (a competent populist fell from ~23% to ~12%). Open questions for Ozan: drift only against core supporters? measured against the founding or the current manifesto? how far low trust may push turnout down.
- **Lore and names (Ozan is working on them):** his history of Cranbovia and the world was discussed (comments: replace the religious split, add recent political history 1964–now, Fauran is now written as the rural, traditional south). Done with map4: the city renames (Vüllent, Crümländ, Tarroport, Giloford, Lilabourg), Salmark (capital Salbourg) in the north, the Hesperian Sea and Follount Lake, the new Erland province Sisillia (no city yet). The country is now **Cranbovia** (people: Cranbovians) in the game and docs; ids keep the old spelling. Political history 1942–2026 written by Ozan (DESIGN.md, *Political history*), with open questions there (who governs at the start, Open Cranbovia's place, an unfinished Norbanistan sentence). Still to do: Erland modelled on Castile and/or Alberta. See DESIGN.md, *The political spectrum* and *A new northern neighbour*.
- Planned: personas, continuing after a lost election, event pictures and portraits, sound, exports.

## Git

Commit in small, described steps on `main` and push. Ozan pulls with GitHub Desktop. Never rewrite history or force-push.
