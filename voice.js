// =====================================================================
// voice.js — what your leader says and how it lands.
//   * delivery: sound bites with hidden tones and group reactions
//   * leader style built from the tones you choose
//   * the record: every statement, who you blamed, who you betrayed
//   * the final debate and the end-of-game profile
// Rules only; the screens are in ui.js.
// =====================================================================
"use strict";

// ---------- Tones (never named on screen) ----------
// Each sound bite carries one tone. Groups have hidden tastes; risk decides
// how often a line goes viral or turns into a gaffe.
const TONES = {
  statesman: {
    react: [{ who: { age: ["46-60", "61+"] }, amt: 0.08 }, { who: { class: "middle" }, amt: 0.08 }, { who: { lean: { rev: "<-25" } }, amt: -0.1 }, { who: { age: "18-29" }, amt: -0.06 }],
    press: { normal: "The press called it measured.", viral: "Commentators called it the most serious answer anyone gave.", gaffe: "Critics called it stiff and evasive." } },
  fiery: {
    react: [{ who: { class: "working" }, amt: 0.1 }, { who: { lean: { rev: "<-15" } }, amt: 0.08 }, { who: { class: "upper" }, amt: -0.12 }, { who: { class: "middle" }, amt: -0.06 }, { who: { age: "61+" }, amt: -0.05 }],
    press: { normal: "Supporters loved the passion; critics called it shouting.", viral: "The clip of you saying it is on every channel.", gaffe: "You lost your temper on camera, and it shows." } },
  folksy: {
    react: [{ who: { age: "18-29" }, amt: 0.08 }, { who: { region: ["erland", "fauraifai"] }, amt: 0.06 }, { who: { class: "upper" }, amt: -0.08 }, { who: { class: "middle" }, amt: -0.05 }],
    press: { normal: "It came across as down to earth.", viral: "The line has become a catchphrase.", gaffe: "The joke fell flat, and people noticed." } },
  provocative: {
    react: [{ who: { lean: { rev: "<-15" } }, amt: 0.14 }, { who: { age: "18-29" }, amt: 0.04 }, { who: { class: ["middle", "upper"] }, amt: -0.2 }, { who: { age: "61+" }, amt: -0.12 }],
    press: { normal: "Outrage on every channel.", viral: "The most shared clip of the month. Love it or hate it, everyone saw it.", gaffe: "Even people who agree with you are wincing." } },
};
const TONE_RISK = { statesman: 0.1, folksy: 0.3, fiery: 0.35, provocative: 0.6 };

// ---------- Group snapshots: "how it played" ----------
const FEEDBACK_GROUPS = [
  ...REGIONS.map((r) => ({ label: r.name, who: { region: r.id } })),
  ...CLASSES.map((c) => ({ label: c.label, who: { class: c.id } })),
  { label: "Under 30s", who: { age: "18-29" } }, { label: "Over 60s", who: { age: "61+" } },
  { label: "Alinnian minority", who: { nationality: "alinnian" } }, { label: "Norbanian-born", who: { nationality: "norbanian" } },
];
function snapshotGroups(state) {
  const ctx = scoreContext(state);
  const sup = new Map(state.pops.map((p) => [p, popSupport(state, p, null, ctx).player]));
  return FEEDBACK_GROUPS.map((g) => {
    let size = 0, v = 0;
    for (const p of state.pops) if (matches(p, g.who)) { size += p.size; v += p.size * sup.get(p); }
    return size ? v / size : 0;
  });
}
// Changes in your support per group, in percentage points, biggest first.
function groupChanges(state, before) {
  const after = snapshotGroups(state);
  return FEEDBACK_GROUPS.map((g, i) => ({ label: g.label, delta: (after[i] - before[i]) * 100 }))
    .filter((x) => Math.abs(x.delta) >= 0.15).sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));
}

// ---------- The record ----------
// Every statement is kept: the debate and the end screen use it.
function recordStatement(state, { text, title, effects = {}, tone = null, spoken = true }) {
  const rec = state.record;
  const week = state.week;
  rec.quotes.push({ week, text, title, tone, spoken, shift: effects.shift || {} });
  // who you blamed
  if (effects.blame) rec.blamed.push({ week, group: effects.blame, text });
  for (const g of effects.goodwill || []) {
    if (g.amt <= -0.8 && g.who.nationality && !effects.blame) rec.blamed.push({ week, group: describeWho(g.who), text });
  }
  // promises and betrayals: groups remember what you told them, for a while
  for (const g of effects.goodwill || []) {
    const key = describeWho(g.who);
    if (g.amt <= -0.3) {
      const p = rec.promises.find((x) => x.key === key && week - x.week < 72);
      if (p) {
        rec.betrayed.push({ group: key, promised: p.text, promisedSpoken: p.spoken, promisedWeek: p.week, now: text, nowSpoken: spoken, week });
        rec.promises = rec.promises.filter((x) => x !== p);
        // the betrayed group takes it personally
        for (const pop of state.pops) if (matches(pop, g.who)) pop.goodwill.player = clamp(pop.goodwill.player - 0.15, -2, 2);
      }
    }
    if (g.amt >= 0.35) rec.promises.push({ key, week, text, spoken });
  }
}
// Pairs of statements that pulled the same issue in opposite directions.
function contradictions(state) {
  const q = state.record.quotes;
  const out = [];
  for (let i = 0; i < q.length; i++) for (let j = i + 1; j < q.length; j++) {
    for (const ax of Object.keys(q[i].shift)) {
      const a = q[i].shift[ax], b = q[j].shift[ax] || 0;
      if (Math.abs(a) >= 8 && Math.abs(b) >= 8 && Math.sign(a) !== Math.sign(b) && q[j].week - q[i].week >= 12) {
        out.push({ axis: ax, first: q[i], second: q[j], size: Math.abs(a) + Math.abs(b) });
      }
    }
  }
  return out.sort((x, y) => y.size - x.size);
}

// ---------- Delivery ----------
// Apply one sound bite: tone tastes + its own hidden reactions + luck.
function deliverLine(state, line) {
  const player = playerParty(state);
  const tone = TONES[line.tone] ? line.tone : "statesman";
  const risk = line.risk ?? TONE_RISK[tone];
  const r = rand(state);
  const charm = player.charisma / 100;
  let outcome = "normal";
  if (r < risk * (0.3 + charm * 0.6)) outcome = "viral";
  else if (r > 1 - risk * (0.55 - charm * 0.35)) outcome = "gaffe";
  const pos = outcome === "viral" ? 1.6 : 1, neg = outcome === "gaffe" ? 1.8 : outcome === "viral" ? 1.3 : 1;
  const reacts = [...TONES[tone].react, ...(line.react || [])];
  const scaled = reacts.map((g) => ({ who: g.who, amt: g.amt * (g.amt > 0 ? pos : neg) }));
  applyEffects(state, { goodwill: scaled, awareness: outcome === "viral" ? 0.06 : outcome === "gaffe" ? 0.035 : 0.01 });
  // People judge the leader by how they speak, too.
  for (const g of scaled) for (const pop of state.pops) {
    if (matches(pop, g.who)) pop.leader.player = clamp(pop.leader.player + g.amt * 0.35, -2, 2);
  }
  // Style: a consistent voice builds charisma; switching tone all the time looks fake.
  for (const k in state.style) state.style[k] *= CONFIG.styleMemory;
  state.style[tone] = (state.style[tone] || 0) + 1;
  const total = Object.values(state.style).reduce((a, b) => a + b, 0);
  const [dom, domW] = Object.entries(state.style).sort((a, b) => b[1] - a[1])[0];
  const share = domW / total;
  let styleNote = "";
  if (total > 3 && tone === dom && share > 0.45) { player.charisma = clamp(player.charisma + 0.8, 10, 100); styleNote = "It sounded like you. People are starting to recognise your voice."; }
  else if (total > 3 && tone !== dom && share > 0.5) { player.charisma = clamp(player.charisma - 0.6, 10, 100); styleNote = "It didn't sound like you. Some voters wonder who the real you is."; }
  if (outcome === "viral") { state.record.memes++; player.charisma = clamp(player.charisma + 1.5, 10, 100); }
  if (outcome === "gaffe") { state.record.gaffes++; player.charisma = clamp(player.charisma - 1, 10, 100); }
  return { outcome, press: TONES[tone].press[outcome], styleNote };
}
// The leader's style in words, from the tones used so far.
function styleProfile(state) {
  const total = Object.values(state.style).reduce((a, b) => a + b, 0);
  if (total < 2) return { label: "Still finding a voice", shares: {} };
  const shares = Object.fromEntries(Object.entries(state.style).map(([k, v]) => [k, v / total]));
  const s = (k) => shares[k] || 0;
  let label = "A bit of everything";
  if (s("folksy") + s("provocative") > 0.65 && s("provocative") > 0.25) label = "Charismatic buffoon";
  else if (s("fiery") + s("provocative") > 0.65) label = "Firebrand";
  else if (s("statesman") > 0.55) label = "Statesman";
  else if (s("folksy") > 0.5) label = "Man of the people";
  else if (s("statesman") + s("fiery") > 0.7) label = "Strongman";
  else if (s("statesman") + s("folksy") > 0.7) label = "Reassuring uncle";
  if (label === "Man of the people" && playerParty(state).leaderSex === "f") label = "Woman of the people";
  if (label === "Reassuring uncle" && playerParty(state).leaderSex === "f") label = "Reassuring aunt";
  return { label, shares };
}

// ---------- The final debate ----------
// A month before the election: three rounds, broadcast to the whole country.
function debateRounds(state) {
  const player = playerParty(state);
  const rival = [...rivals(state)].sort((a, b) => (state.lastSupport[b.id] || 0) - (state.lastSupport[a.id] || 0))[0];
  const con = contradictions(state)[0];
  const blamed = state.record.blamed[0];
  const dirty = state.record.money.find((m) => m.dirty);
  let attack;
  if (con) attack = `"In ${dateLabel(con.first.week, false)} you said: '${con.first.text}' In ${dateLabel(con.second.week, false)} you said: '${con.second.text}' Which one do you actually believe?"`;
  else if (blamed) attack = `"Your whole campaign has been about blaming ${blamed.group}. Is that all you have to offer?"`;
  else if (dirty) attack = `"Where does your party's money come from? Because it isn't from ordinary Cranebonians."`;
  else attack = `"You have never run anything in your life. Why should anyone trust you with a country?"`;
  const hurt = con || blamed || dirty ? [{ who: { class: "middle" }, amt: -0.12 }, { who: { age: "61+" }, amt: -0.08 }] : [];
  return [
    { title: "Opening statement", prompt: `The moderator turns to ${player.leader}: "Your party didn't exist four years ago. Why should anyone vote for it?"`,
      lines: [
        { tone: "statesman", text: `"Because Cranebonistan deserves a government that keeps its word. That is all ${player.name} has ever asked for."` },
        { tone: "fiery", text: `"Because for thirty years the people on this stage have robbed you blind, and tonight that ends."` },
        { tone: "folksy", text: `"I'm not a career politician. I'm someone who got tired of waiting for a bus that never comes."` },
        { tone: "provocative", text: `"Look at the people next to me. Would you lend any of them your car?"` },
      ] },
    { title: `${rival.leader} attacks`, prompt: `${rival.leader} of the ${rival.short} turns to you: ${attack}`, rival: rival.id, hurt,
      lines: [
        { tone: "statesman", text: `"I have listened and I have learned. A leader who never changes their mind isn't listening."` },
        { tone: "fiery", text: `"How dare you lecture anyone? Your party has lied to this country for a generation."` },
        { tone: "folksy", text: `"At least I change my mind now and then. ${rival.leader} hasn't changed a thing since the cassette tape."`, react: [{ who: { loyalTo: rival.id }, amt: -0.1 }] },
        { tone: "provocative", text: `"That's invented. Everybody knows your people make things up."`, react: [{ who: { class: "middle" }, amt: -0.1 }] },
      ] },
    { title: "Closing statement", prompt: `"You have thirty seconds. Speak to the voters."`,
      lines: [
        { tone: "statesman", text: `"On election day, vote for the country you want your children to grow up in."` },
        { tone: "fiery", text: `"They are afraid of you. On election day, prove them right."` },
        { tone: "folksy", text: `"If you want more of the same, you know who to vote for. If you don't, you know where to find me."` },
        { tone: "provocative", text: `"If they win again, don't say I didn't warn you."` },
      ] },
  ];
}
function startDebate(state) {
  state.debate = { rounds: debateRounds(state), step: 0, results: [] };
  state.queue.push({ type: "debate" });
}
function answerDebate(state, lineIndex) {
  const d = state.debate;
  const round = d.rounds[d.step];
  const line = round.lines[lineIndex];
  const before = snapshotGroups(state);
  if (round.hurt && round.hurt.length) applyEffects(state, { goodwill: round.hurt, awareness: 0 });
  // A national audience: every line counts double.
  const big = { ...line, react: [...(line.react || []), ...TONES[line.tone].react] };
  const res = deliverLine(state, big);
  applyEffects(state, { awareness: 0.04 });
  recordStatement(state, { text: line.text.replace(/^"|"$/g, ""), title: "The final debate", tone: line.tone, spoken: true });
  const result = { ...res, quote: line.text, changes: groupChanges(state, before), round: round.title };
  d.results.push(result);
  d.step++;
  if (d.step >= d.rounds.length) finishFront(state, "debate");
  return result;
}

// ---------- The end-of-game profile ----------
const ARCHETYPES = {
  weathervane: { title: "The Weathervane", line: "Said whatever the wind was blowing that week, and the wind kept changing." },
  believer: { title: "The True Believer", line: "Never moved an inch. Whether that was principle or stubbornness, the voters decided." },
  strongman: { title: "The Strongman", line: "Loud, certain, and adored by a crowd that would follow anywhere." },
  clown: { title: "The Clown Prince", line: "Every week a new outrage, and every outrage a few more followers." },
  technocrat: { title: "The Technocrat", line: "Measured, careful, and forgettable to everyone except the middle class." },
  fixer: { title: "The Fixer", line: "Knew where the money was, and where the bodies were buried." },
  demagogue: { title: "The Demagogue", line: "Always had someone to blame, and never ran out of people." },
};
function buildProfile(state) {
  const player = playerParty(state);
  const rec = state.record;
  const cons = contradictions(state);
  const style = styleProfile(state).shares;
  const s = (k) => style[k] || 0;
  const nation = summarize(state, state.pops);
  const dirty = rec.money.filter((m) => m.dirty);
  const drift = inconsistencyOf(state, player);
  const scores = {
    weathervane: Math.min(cons.length, 6) * 0.8 + Math.min(rec.betrayed.length, 5) * 1.2 + Math.min(state.flips.filter((f) => f.party === "player").length, 10) * 0.3,
    believer: (player.extremity || 0) * 8 + (drift < 1 ? 3 : 0) - Math.min(cons.length, 6),
    strongman: s("fiery") * 8 + s("statesman") * 3 + nation.devotion * 20,
    clown: (s("folksy") + s("provocative")) * 7 + rec.memes * 1.5 + rec.gaffes * 1.5,
    technocrat: s("statesman") * 9 + (1 - (player.extremity || 0)) * 3,
    fixer: dirty.length * 3 + rec.dossiers * 2,
    demagogue: rec.blamed.length * 3 + rec.outrages * 1.2,
  };
  const archetype = Object.entries(scores).sort((a, b) => b[1] - a[1])[0][0];
  const r = state.result;
  const L = player.leader.toUpperCase(), P = player.name.toUpperCase();
  let headline;
  if (r.majority) headline = `${L} SWEEPS TO POWER`;
  else if (r.playerWon) headline = `${P} BECOMES THE LARGEST PARTY`;
  else if (r.votes.player < 0.1) headline = `${P} FADES INTO THE FOOTNOTES`;
  else headline = `${L}'S GAMBLE FALLS SHORT`;
  const quotes = rec.quotes.filter((q) => q.title !== "The final debate");
  const crisis = state.crisis ? byId(CRISES, state.crisis.id) : null;
  return {
    archetype: ARCHETYPES[archetype], headline,
    contradictions: cons.slice(0, 3),
    blamed: [...new Set(rec.blamed.map((b) => b.group))],
    betrayed: rec.betrayed.slice(0, 3),
    money: rec.money,
    crisis: crisis ? { name: crisis.name, odds: state.crisis.odds, blamed: crisisBlamesYou(state) } : null,
    memes: rec.memes, gaffes: rec.gaffes, statements: rec.quotes.length,
    style: styleProfile(state).label,
    signature: quotes.filter((q) => q.spoken).length ? quotes.filter((q) => q.spoken).reduce((best, q) => (Object.values(q.shift).reduce((a, b) => a + Math.abs(b), 0) > Object.values(best.shift).reduce((a, b) => a + Math.abs(b), 0) ? q : best), quotes.filter((q) => q.spoken)[0]) : null,
  };
}

// ---------- Hooks ----------
(function addVoiceHooks() {
  const i = HOOKS.findIndex((h) => h.name === "monthly event");
  HOOKS.splice(i, 0, { name: "final debate", when: (c) => c.week === ELECTION_WEEK - WEEKS_PER_MONTH, run: startDebate });
})();
