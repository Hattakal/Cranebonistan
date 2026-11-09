// export_content.js: dump the game's content (data, events, sound bites, initiatives,
// crises, map) from the browser version into godot/data/content.json.
//   node tools/export_content.js
const fs = require("fs"), vm = require("vm"), path = require("path");
const dir = path.join(__dirname, "..");
const ctx = { console, Math, JSON, Object, Map, Set }; vm.createContext(ctx);
const files = ["map.js", "flags.js", "data.js", "events.js", "soundbites.js", "initiatives.js", "crises.js", "sim.js", "world.js", "voice.js"];
vm.runInContext(files.map((f) => fs.readFileSync(path.join(dir, f), "utf8")).join("\n") + `
;this.OUT = { CONFIG, AXES, AGES, CLASSES, NATIONALITIES, REGIONS, FOREIGN, CAPITAL, VIEW_GROUPS, PARTIES, LEADER_POOL,
  PARTY_TEMPLATES, PLAYER_COLORS, PLAYER_EMBLEMS, PLAYER_PORTRAITS, CAMPAIGN, EVENTS, FUNDING_OFFERS, INITIATIVES,
  CRISES, INDICATORS, TONES, TONE_RISK, ARCHETYPES, ACTIONS, SCRUTINY_STORIES, MONTH_NAMES, MAP, FLAG_INFO,
  FEEDBACK_GROUPS };`, ctx);
const out = JSON.parse(JSON.stringify(ctx.OUT)); // drops functions
for (const r of out.REGIONS) { delete r.shape; }
for (const f of out.FOREIGN) { delete f.shape; }
fs.writeFileSync(path.join(dir, "godot/data/content.json"), JSON.stringify(out, null, 1));
console.log("events", out.EVENTS.length, "initiatives", out.INITIATIVES.length, "crises", out.CRISES.length,
  "kB", Math.round(fs.statSync(path.join(dir, "godot/data/content.json")).size / 1024));
