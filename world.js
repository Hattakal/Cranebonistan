// =====================================================================
// world.js — the state of the nation, monthly initiatives, and the
// major crisis. Rules only; the content is in initiatives.js and crises.js.
// Loaded after sim.js; it adds its own hooks to the calendar.
// =====================================================================
"use strict";

// ---------- State of the nation ----------
// Five slow indicators, 0-100. They drift back to normal, push each other,
// change what voters care about, and make fitting events more likely.
const INDICATORS = [
  { id: "jobs", label: "Jobs", normal: 55, words: [[65, "Booming"], [50, "Steady"], [38, "Weak"], [0, "Unemployment crisis"]], good: "high" },
  { id: "prices", label: "Prices", normal: 45, words: [[70, "Spiralling"], [55, "Rising fast"], [40, "Rising slowly"], [0, "Stable"]], good: "low" },
  { id: "migration", label: "Migration", normal: 55, words: [[72, "Surging"], [58, "High"], [40, "Normal"], [0, "Low"]], good: null },
  { id: "border", label: "Border tension", normal: 40, words: [[75, "On the brink"], [55, "Hostile"], [35, "Tense"], [0, "Calm"]], good: "low" },
  { id: "unrest", label: "Public mood", normal: 32, words: [[70, "Boiling over"], [50, "Angry"], [30, "Restless"], [0, "Calm"]], good: "low" },
];
function indicatorWord(id, v) {
  const ind = INDICATORS.find((i) => i.id === id);
  return ind.words.find(([min]) => v >= min)[1];
}
function worldMonthly(state) {
  const w = state.world;
  const prev = { ...w };
  // Norbanistan's civil war keeps people coming; the crisis can change that.
  const migrationTarget = 55 + (state.crisis && state.crisis.id === "economy" ? -12 : 0);
  w.migration += (migrationTarget - w.migration) * 0.08 + randNormal(state) * 2.5;
  // Cheap labour helps the economy a little; high prices hurt it.
  w.jobs += (55 - w.jobs) * 0.06 + (w.migration - 55) * 0.03 - Math.max(0, w.prices - 55) * 0.05 + randNormal(state) * 1.8;
  w.prices += (45 - w.prices) * 0.06 + Math.max(0, w.border - 60) * 0.03 + randNormal(state) * 1.8;
  w.border += (40 - w.border) * 0.05 + randNormal(state) * 2;
  // People get angry when jobs vanish, prices rise and the borders heat up.
  const anger = Math.max(0, 50 - w.jobs) * 0.25 + Math.max(0, w.prices - 50) * 0.2 + Math.max(0, w.migration - 65) * 0.12 + Math.max(0, 40 - state.trust) * 0.15;
  w.unrest += (32 + anger - w.unrest) * 0.12 + randNormal(state) * 1.5;
  for (const k in w) w[k] = clamp(w[k], 0, 100);
  // Bad times erode trust and wear down the government.
  if (w.jobs < 42 || w.prices > 60) changeTrust(state, -0.8);
  const ruling = state.parties.find((p) => p.ruling);
  if (ruling && (w.jobs < 42 || w.prices > 60 || w.unrest > 60)) ruling.stability = clamp(ruling.stability - 1.5, 0, 100);
  // ...but a dangerous border rallies people around the government.
  if (ruling && w.border > 65) ruling.stability = clamp(ruling.stability + 1, 0, 100);
  updateClimate(state);
  state.worldPrev = prev;
}
// What the state of the nation makes people care about.
function updateClimate(state) {
  const w = state.world;
  const c = {};
  c.econ = Math.max(0, 55 - w.jobs) / 40 + Math.max(0, w.prices - 50) / 50;
  c.labor = Math.max(0, 55 - w.jobs) / 35;
  c.immig = Math.max(0, w.migration - 55) / 50;
  c.war = Math.max(0, w.border - 40) / 40;
  c.gov = Math.max(0, w.prices - 50) / 60;
  c.rev = Math.max(0, w.unrest - 40) / 45;
  c.nat = Math.max(0, w.border - 50) / 60 + Math.max(0, w.unrest - 50) / 80;
  state.climate = c;
  // Migration is felt most in Yamlin, among those competing for the same jobs.
  state.regionClimate = { yamlin: { immig: Math.max(0, w.migration - 50) / 30, labor: Math.max(0, w.migration - 55) / 50 } };
}

// ---------- Initiatives: setting the agenda ----------
// Each month three initiatives are offered. Picking one is free and does not
// use an action, but it seeds future events: what you raise comes back.
function offerInitiatives(state) {
  const used = state.agenda.used;
  const pool = INITIATIVES.filter((i) => !used.includes(i.id) && (!i.minMonth || state.week / WEEKS_PER_MONTH >= i.minMonth));
  const weighted = pool.map((i) => ({ i, w: eventWeight(state, i) * (0.5 + rand(state)) })).sort((a, b) => b.w - a.w);
  state.agenda.offered = weighted.slice(0, 3).map((x) => x.i.id);
  state.agenda.done = false;
}
function takeInitiative(state, id) {
  if (state.agenda.done || !state.agenda.offered.includes(id)) return { ok: false, text: "You have already set this month's agenda." };
  const ini = byId(INITIATIVES, id);
  const flipsBefore = state.flips.length;
  const before = snapshotGroups(state);
  applyEffects(state, ini.effects);
  for (const s of ini.seeds || []) {
    const months = s.months[0] + Math.floor(rand(state) * (s.months[1] - s.months[0] + 1));
    state.scheduled.push({ id: s.event, week: state.week + months * WEEKS_PER_MONTH });
  }
  state.flags["initiative:" + id] = state.week;
  state.agenda.done = true;
  state.agenda.used.push(id);
  recordStatement(state, { text: ini.quote || ini.title, title: ini.title, effects: ini.effects, spoken: !!ini.quote });
  state.log.push({ week: state.week, kind: "initiative", text: `Put on the agenda: ${ini.title}.` });
  return { ok: true, title: ini.title, quote: ini.quote, flips: state.flips.slice(flipsBefore), changes: groupChanges(state, before) };
}

// ---------- The major crisis ----------
// One per game, drawn in year two from five. Your campaign can at most double a crisis's chance (to 40%).
function crisisOdds(state) {
  const boosts = CRISES.map((c) => clamp((state.crisisPressure[c.id] || 0) / CONFIG.crisisBoostAt, 0, CONFIG.crisisBoostMax));
  const weights = boosts.map((b) => 1 + b);
  const total = weights.reduce((a, b) => a + b, 0);
  return Object.fromEntries(CRISES.map((c, i) => [c.id, weights[i] / total]));
}
function startCrisis(state) {
  if (state.crisis) return;
  const odds = crisisOdds(state);
  let r = rand(state), id = CRISES[CRISES.length - 1].id;
  for (const c of CRISES) { r -= odds[c.id]; if (r <= 0) { id = c.id; break; } }
  const c = byId(CRISES, id);
  state.crisis = { id, odds: odds[id], start: state.week, phase: 0 };
  // The crisis changes the country for good.
  applyEffects(state, { ...c.onStart, fromNews: true, awareness: 0 });
  // Its phases arrive over the following months.
  c.phases.forEach((p, i) => {
    if (i === 0) state.queue.push({ type: "event", id: p.event });
    else state.scheduled.push({ id: p.event, week: state.week + p.month * WEEKS_PER_MONTH });
  });
  state.log.push({ week: state.week, kind: "crisis", text: `Crisis: ${c.name}.` });
}
function crisisBlamesYou(state) { return state.crisis && state.crisis.odds > CONFIG.crisisBlameFrom; }

// ---------- Hooks ----------
(function addWorldHooks() {
  const i = HOOKS.findIndex((h) => h.name === "monthly update");
  HOOKS.splice(i + 1, 0,
    { name: "state of the nation", when: (c) => c.isMonthStart && c.week > 0, run: worldMonthly },
    { name: "agenda", when: (c) => c.isMonthStart, run: offerInitiatives },
    { name: "major crisis", when: (c) => c.isMonthStart && !c.done, run: (s) => {
      if (s.crisis) return;
      if (s.crisisMonth === undefined) {
        const [a, b] = CONFIG.crisisMonths;
        s.crisisMonth = a + Math.floor(rand(s) * (b - a + 1));
      }
      if (Math.floor(s.week / WEEKS_PER_MONTH) >= s.crisisMonth) startCrisis(s);
    } },
  );
})();
