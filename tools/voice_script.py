"""Writes VOICE.md, the recording script for Carlos, from godot/data/carlos.json.
Run it again whenever his lines change:  python3 tools/voice_script.py"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lines = json.load(open(os.path.join(ROOT, "godot", "data", "carlos.json"), encoding="utf-8"))["LINES"]
DIRECTION = {
 "tutorial": "First day at headquarters. Warm, eager, a little too pleased to see the boss.",
 "month_start": "Breezy, upbeat. A quick bark at the start of a month.",
 "poll_up": "Delighted, like he called it all along.",
 "poll_down": "Smoothing it over. Light, quick, never worried out loud.",
 "poll_flat": "Reassuring, spinning stillness into strength.",
 "annual_poll": "Proud, a little ceremonial.",
 "budget": "Enjoying himself. Money talk is his favourite.",
 "event": "Urgent but excited: news is opportunity.",
 "viral": "Thrilled. Almost giddy.",
 "gaffe": "Unshakeable. Says it as if he means it. Played straight, not winking.",
 "speak": "Short, admiring.",
 "raise_caught": "Triumphant.",
 "raise_fizzled": "Instant excuse, no pause.",
 "major_debate": "Serious for once, but still on your side.",
 "community": "Cheerful, small-town warmth.",
 "steer": "Cheerleading a risky move.",
 "figure_quit": "Dismissive of the person who left. Quietly.",
 "dirty_money": "Lowered voice. Smooth.",
 "debate_night": "Pep talk.",
 "election_near": "Nervous energy, hidden under confidence.",
 "won": "Overjoyed.",
 "lost": "Comforting, already spinning.",
 "tip": "Helpful, a bit conspiratorial. The advice is genuinely good, in the short term.",
}
out = ["# Carlos Aster: recording script", "",
 "Carlos is the voice of headquarters: the advisor who hypes you up, spins every number, and never quite admits anything went wrong. Think a warm, quick, slightly oily campaign manager. Not a cartoon: he believes most of what he says.",
 "", "**How to save recordings:** one file per line, named by its id, in `godot/assets/voice/carlos/` (for example `pollup_3.ogg`). `.ogg` is best; `.wav` and `.mp3` also work. The game plays a recording automatically when the line comes up; lines without one just show as text. Keep each line short and natural; it doesn't need to match the text word for word, but close is better because the subtitle shows the written line.",
 "", f"{sum(len(v) for v in lines.values())} lines in total.", ""]
for sit, items in lines.items():
    out.append(f"## {sit.replace('_', ' ').capitalize()}")
    out.append(f"*{DIRECTION.get(sit, '')}*")
    out.append("")
    out.append("| File | Line |")
    out.append("|---|---|")
    for it in items: out.append(f"| `{it['id']}` | {it['text']} |")
    out.append("")
open(os.path.join(ROOT, "VOICE.md"), "w", encoding="utf-8").write("\n".join(out))
print("VOICE.md written")
