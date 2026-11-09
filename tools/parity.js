// The browser rules playing the same fixed script as godot/tests/parity.gd.
//   node tools/parity.js 42
const fs = require("fs"), vm = require("vm"), path = require("path");
const dir = path.join(__dirname, "..");
const ctx = { console, Math, JSON, Object, Map, Set }; vm.createContext(ctx);
const files = ["map.js", "data.js", "events.js", "soundbites.js", "initiatives.js", "crises.js", "sim.js", "world.js", "voice.js"];
vm.runInContext(files.map((f) => fs.readFileSync(path.join(dir, f), "utf8")).join("\n") + `;this.A={newGame,advanceWeek,resolveEvent,resolveBudget,dismissFront,eventOf,takeInitiative,actOutrage,actGrassroots,answerDebate,buildProfile,REGIONS};`, ctx);
const A = ctx.A;
const seed = +(process.argv[2] || 42);
const M = { nat: 1, econ: 3, prog: 2, war: 2, gov: 3, labor: 1, immig: 3, rev: 1 };
const s = A.newGame({ seed, partyName: "Test", manifesto: M });
let last = -1, guard = 0;
const u32 = (x) => x >>> 0;
while (!s.result && guard++ < 20000) {
  if (!s.queue.length) {
    const m = Math.floor(s.week / 4);
    if (m !== last) {
      last = m;
      if (s.agenda.offered.length && !s.agenda.done && m % 2 === 0) A.takeInitiative(s, s.agenda.offered[0]);
      if (s.actionsLeft > 0 && m % 3 === 0) A.actOutrage(s);
      if (s.actionsLeft > 0 && m % 5 === 1 && s.money > 2) A.actGrassroots(s, A.REGIONS[m % 5].id);
    }
    A.advanceWeek(s); continue;
  }
  const f = s.queue[0];
  if (f.type === "event") {
    const ev = A.eventOf(f); const i = s.week % ev.choices.length; const lines = ev.choices[i].lines || [];
    A.resolveEvent(s, i, lines.length ? Math.floor(s.week / 4) % lines.length : null);
  } else if (f.type === "budget") {
    const money = s.money, tot = A.REGIONS.reduce((a, r) => a + r.adults, 0), alloc = {};
    A.REGIONS.forEach((r) => (alloc[r.id] = money * 0.55 * r.adults / tot));
    alloc.social = money * 0.15; alloc.tv = money * 0.15; alloc.tour = money * 0.15;
    A.resolveBudget(s, alloc, []);
  } else if (f.type === "debate") {
    A.answerDebate(s, s.debate.step % 4);
  } else {
    if (f.type === "poll") { const p = s.polls[f.index]; console.log(`${p.label} w${p.week} you=${p.national.player.toFixed(6)} nup=${p.national.nup.toFixed(6)} trust=${s.trust.toFixed(4)} rng=${u32(s.rng)}`); }
    A.dismissFront(s);
  }
}
const r = s.result;
console.log(`RESULT you=${r.votes.player.toFixed(6)} seats=${r.seats.national.player} won=${r.playerWon} crisis=${s.crisis ? s.crisis.id : "none"}`);
const pr = A.buildProfile(s);
console.log(`PROFILE ${pr.archetype.title} | contra ${pr.contradictions.length} | betrayed ${pr.betrayed.length} | style ${pr.style}`);
