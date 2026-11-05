// =====================================================================
// sim.js — the simulation engine.
// No DOM, no buttons, no drawing: it only reads data.js / events.js and
// changes the game state. It can also run in Node for balance testing.
//
// The whole game is one plain object, `state`. Saving = JSON.stringify(state).
//
// Sections:
//   helpers · calendar · stances · new game & pops · consistency
//   opinion (how a pop scores a party) · groups & summaries · effects
//   trust · issue ownership · rival parties · monthly update
//   actions · campaign budget · events · news · polls · elections · time
//   descriptions for the screens
// =====================================================================
"use strict";

// ---------- Small helpers ----------
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const byId = (list, id) => list.find((x) => x.id === id);
const playerParty = (state) => state.parties.find((p) => p.isPlayer);
const partyOf = (state, id) => state.parties.find((p) => p.id === id);
const rivals = (state) => state.parties.filter((p) => !p.isPlayer);

// Seeded random numbers (mulberry32). The seed lives in state.rng,
// so a saved game continues with exactly the same luck.
function rand(state) {
  let t = (state.rng = (state.rng + 0x6d2b79f5) | 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
function randNormal(state) {
  const u = Math.max(rand(state), 1e-9), v = rand(state);
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
function shuffle(state, arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rand(state) * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}
function pick(state, arr) { return arr[Math.floor(rand(state) * arr.length)]; }

// ---------- Calendar ----------
// One tick = one week. 4 weeks a month, 12 months a year.
const MONTH_NAMES = ["January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"];
const WEEKS_PER_MONTH = CONFIG.weeksPerMonth;
const WEEKS_PER_YEAR = CONFIG.weeksPerMonth * CONFIG.monthsPerYear;
const ELECTION_WEEK = CONFIG.electionYears * WEEKS_PER_YEAR;

function calendar(week) {
  const month = Math.floor(week / WEEKS_PER_MONTH);
  return {
    week,
    weekOfMonth: week % WEEKS_PER_MONTH,
    monthIndex: month % CONFIG.monthsPerYear,
    year: CONFIG.startYear + Math.floor(month / CONFIG.monthsPerYear),
    isMonthStart: week % WEEKS_PER_MONTH === 0,
    isQuarterStart: week % (WEEKS_PER_MONTH * 3) === 0,
    isYearEnd: week % WEEKS_PER_YEAR === WEEKS_PER_YEAR - 1,
  };
}
function dateLabel(week, withWeek = true) {
  const c = calendar(week);
  const base = `${MONTH_NAMES[c.monthIndex]} ${c.year}`;
  return withWeek ? `Week ${c.weekOfMonth + 1} · ${base}` : base;
}

// ---------- Stances ----------
// Each axis is cut into 5 stances (0 = far left label, 4 = far right label).
function stanceOf(value) {
  let i = 0;
  for (const b of CONFIG.stanceBounds) if (value >= b) i++;
  return i;
}
function stanceName(axisId, index) { return byId(AXES, axisId).stances[index]; }
// Sides of an issue, used by issue ownership: "nat:L" = the Nationalism side.
const sideKey = (axis, side) => `${axis}:${side}`;
function sideLabel(key) {
  const [ax, side] = key.split(":");
  const a = byId(AXES, ax);
  return side === "L" ? a.left : a.right;
}

// ---------- Starting a new game ----------
// manifesto: { axisId: stance index 0..4 }
function newGame({ seed, partyName = "New Dawn Movement", leaderName = "Dorin Vask", manifesto = {} } = {}) {
  seed = seed ?? Math.floor(Math.random() * 2147483647);
  const playerPoint = {};
  for (const ax of AXES) playerPoint[ax.id] = CONFIG.stanceCenters[manifesto[ax.id] ?? 2];
  const state = {
    version: 4, seed, rng: seed, week: 0, money: 0,
    trust: CONFIG.trustStart, trustHistory: [],
    salMod: {},          // temporary national salience boosts ("hot issues")
    ownership: {},       // { "nat:L": { partyId: 0..1 } }
    queue: [],           // things waiting for the player: news, events, budgets, polls
    news: [],            // headlines collected during the month, shown as one sheet
    polls: [], log: [], deck: [],
    flips: [],           // stance changes caused by your statements
    flags: {},           // remembers choices for follow-up events
    scheduled: [],       // follow-up events waiting for their month
    scandals: [],        // hidden dirty money that may leak
    dossiers: [],        // dirt you have dug up on rivals
    signature: [],       // the issues your party campaigns on ("immig:R"), at most CONFIG.maxSignatureIssues
    actionsLeft: CONFIG.actionsPerMonth,
    lastSupport: null,   // national support last month, to see who is rising or falling
    lastBudget: null,    // your previous allocation, to reuse
    result: null,
    parties: PARTIES.map((p) => ({
      id: p.id,
      name: p.isPlayer ? partyName : p.name,
      short: p.isPlayer ? initials(partyName) : p.short,
      leader: p.isPlayer ? leaderName : p.leader,
      charisma: p.isPlayer ? CONFIG.startCharisma : (p.charisma ?? 50),
      stability: p.stability ?? 60,
      establishment: p.establishment ?? 0.5,
      color: p.color,
      isPlayer: !!p.isPlayer,
      ruling: !!p.ruling,
      manifesto: fullVector(p.isPlayer ? playerPoint : p.manifesto),
      perceived: fullVector(p.isPlayer ? playerPoint : p.manifesto),
    })),
    pops: [],
  };
  for (const p of PARTIES) for (const [key, v] of Object.entries(p.owns || {})) {
    (state.ownership[key] = state.ownership[key] || {})[p.id] = v;
  }
  state.pops = buildPops(state);
  seedLoyalty(state);
  state.lastSupport = summarize(state, state.pops).support;
  runHooks(state); // week 0: opening poll, first budget, first event
  return state;
}

function fullVector(v) {
  const out = {};
  for (const ax of AXES) out[ax.id] = clamp(v[ax.id] || 0, -100, 100);
  return out;
}
function initials(name) {
  const words = name.trim().split(/\s+/).filter(Boolean);
  return (words.length > 1 ? words.map((w) => w[0]).join("") : name.slice(0, 3)).toUpperCase().slice(0, 4) || "YOU";
}

// Pops: one per region × age × class × nationality combination.
function buildPops(state) {
  const pops = [];
  for (const r of REGIONS) for (const a of AGES) for (const c of CLASSES) for (const n of NATIONALITIES) {
    const size = r.adults * 1e6 * a.share * (r.classes[c.id] || 0) * (r.nationalities[n.id] || 0);
    if (size < 15000) continue; // too small to matter
    const local = (r.local && r.local[n.id]) || {};
    const pos = {}, sal = {};
    for (const ax of AXES) {
      const lean = (r.lean[ax.id] || 0) + (a.lean[ax.id] || 0) + (c.lean[ax.id] || 0)
        + (n.lean[ax.id] || 0) + ((local.lean || {})[ax.id] || 0);
      pos[ax.id] = Math.round(clamp(lean + randNormal(state) * 7, -100, 100));
      sal[ax.id] = +((r.sal[ax.id] || 1) * (a.sal[ax.id] || 1) * (c.sal[ax.id] || 1)
        * (n.sal[ax.id] || 1) * ((local.sal || {})[ax.id] || 1)).toFixed(2);
    }
    const pop = {
      id: `${r.id}/${a.id}/${c.id}/${n.id}`,
      region: r.id, age: a.id, class: c.id, nationality: n.id,
      size: Math.round(size), pos, sal,
      turnout: clamp(a.turnout + c.turnout + n.turnout + (r.turnout || 0), 0.25, 0.95),
      engagement: a.engagement * c.engagement,   // how much this pop notices flip-flopping
      leaderPull: +((a.leaderAppeal || 1) * (c.leaderAppeal || 1) * (n.leaderAppeal || 1) * (r.leaderAppeal || 1)).toFixed(2),
      // disaffection: how strongly this pop turns to outsiders when trust in the system falls
      disaffection: +clamp(1 + (-pos.rev) / 60 + (c.disaffect || 0) + (r.disaffect || 0), 0.3, 2).toFixed(2),
      mobilized: 0,   // extra turnout among YOUR supporters here, from grassroots work
      loyal: {}, goodwill: {}, aware: {}, leader: {},
    };
    for (const p of state.parties) {
      const reach = (byId(PARTIES, p.id) || {}).reach || {};
      pop.loyal[p.id] = 0;
      pop.goodwill[p.id] = 0;
      pop.leader[p.id] = 0;       // opinion of the party's leader as a person (-2..2); used for your leader
      pop.aware[p.id] = p.isPlayer ? CONFIG.startAwareness : (reach[r.id] ?? reach.default ?? 1);
    }
    pops.push(pop);
  }
  return pops;
}

// Existing parties start with core voters; the new player party has none.
function seedLoyalty(state) {
  const ctx = scoreContext(state);
  for (const pop of state.pops) {
    const sup = popSupport(state, pop, "player", ctx);
    for (const id in sup) pop.loyal[id] = CONFIG.startLoyalty * sup[id];
  }
}

// ---------- Consistency: stances and flips ----------
// Inconsistency = how far your current stances are from your manifesto.
// How you got there doesn't matter: only where voters see you now.
function inconsistencyOf(state, party) {
  let steps = 0;
  for (const ax of AXES) {
    const off = Math.abs(stanceOf(party.perceived[ax.id]) - stanceOf(party.manifesto[ax.id]));
    steps += CONFIG.stepPenalty[off];
  }
  return steps;
}

// ---------- Opinion: how a pop feels about a party ----------
function salienceOf(state, pop, axis) {
  return pop.sal[axis] * (1 + (state.salMod[axis] || 0));
}
// Weighted distance between a pop and a position (0 = identical, 200 = opposite).
function distance(state, pop, pos) {
  let d = 0, w = 0;
  for (const ax of AXES) {
    const s = salienceOf(state, pop, ax.id);
    d += s * Math.abs(pop.pos[ax.id] - pos[ax.id]);
    w += s;
  }
  return d / w;
}
// Devotion: 0..1. Only voters who like the leader a LOT become devoted.
// A devoted voter judges the leader, not the party's positions.
function devotionOf(pop, party) {
  if (!party.isPlayer) return 0;
  const attachment = pop.leader[party.id] * pop.leaderPull * (party.charisma / 50);
  return clamp((attachment - CONFIG.devotionStart) / CONFIG.devotionRange, 0, 1);
}
// Everything that is the same for every pop is worked out once per calculation.
function scoreContext(state) {
  const inc = {}, own = {};
  for (const p of state.parties) { inc[p.id] = inconsistencyOf(state, p); own[p.id] = []; }
  for (const [key, owners] of Object.entries(state.ownership)) {
    const total = Object.values(owners).reduce((a, b) => a + b, 0);
    const [axis, side] = key.split(":");
    for (const [pid, v] of Object.entries(owners)) {
      if (v < 0.02 || !own[pid]) continue;
      // your share of the issue, but a weak lone claim is still weak
      own[pid].push({ axis, side, value: v / Math.max(total, CONFIG.ownShareFloor + v * 0.5) });
    }
  }
  return { inc, own, distrust: (50 - state.trust) / 50 };
}
function partyScore(state, pop, party, ctx) {
  const dev = devotionOf(pop, party);
  // 1) ideology: how close the party is to me (devoted followers stop checking)
  let s = -distance(state, pop, party.perceived) / CONFIG.distanceScale * (1 - CONFIG.devotionBlind * dev);
  // 2) recent goodwill from statements and campaigning
  s += pop.goodwill[party.id];
  // 3) awareness: unknown parties don't get votes
  s += Math.log(pop.aware[party.id]);
  // 4) the leader as a person
  if (party.isPlayer) s += CONFIG.leaderWeight * pop.leader[party.id] * pop.leaderPull * (party.charisma / 50);
  else s += CONFIG.rivalLeaderWeight * ((party.charisma - 50) / 50) * pop.leaderPull;
  // 5) consistency (devoted followers forgive flip-flops)
  const penalty = Math.max(0, ctx.inc[party.id] - CONFIG.inconsistencyTolerance) / 4;
  s -= penalty * pop.engagement * (1 - CONFIG.devotionBlind * dev);
  // 6) trust in the system: when trust is low, outsiders gain and the establishment loses
  s += CONFIG.trustWeight * ctx.distrust * (0.5 - party.establishment) * pop.disaffection;
  // 7) issue ownership: single-issue voters back the party that owns their side of the issue.
  //    When an issue is in the news, more voters care enough to become single-issue voters.
  for (const o of ctx.own[party.id]) {
    const p = pop.pos[o.axis];
    if ((o.side === "L" && p < -15) || (o.side === "R" && p > 15)) {
      const care = salienceOf(state, pop, o.axis) - CONFIG.singleIssueFrom;
      if (care > 0) s += CONFIG.ownWeight * o.value * care;
    }
  }
  return s;
}
// Share of a pop backing each party: core voters first, the rest split by score.
function popSupport(state, pop, exclude, ctx) {
  ctx = ctx || scoreContext(state);
  const parties = state.parties.filter((p) => p.id !== exclude);
  const scores = parties.map((p) => partyScore(state, pop, p, ctx));
  const top = Math.max(...scores);
  const weights = scores.map((s) => Math.exp(s - top));
  const total = weights.reduce((a, b) => a + b, 0);
  const loyalTotal = parties.reduce((a, p) => a + pop.loyal[p.id], 0);
  const out = {};
  parties.forEach((p, i) => { out[p.id] = pop.loyal[p.id] + (1 - loyalTotal) * (weights[i] / total); });
  return out;
}
// Actual votes from one pop: your supporters turn out more if you mobilised them.
function popVotes(pop, sup) {
  const out = {};
  for (const id in sup) {
    const t = id === "player" ? Math.min(0.97, pop.turnout + pop.mobilized) : pop.turnout;
    out[id] = pop.size * t * sup[id];
  }
  return out;
}

// ---------- Groups (everything on the Electorate screen is computed from pops) ----------
function groupKinds() {
  return [
    { id: "age", label: "Age groups", groups: AGES.map((a) => ({ id: a.id, label: a.label, who: { age: a.id } })) },
    { id: "views", label: "Political views", groups: VIEW_GROUPS },
    { id: "nationality", label: "Nationality", groups: NATIONALITIES.map((n) => ({ id: n.id, label: n.label, who: { nationality: n.id } })) },
    { id: "class", label: "Social class", groups: CLASSES.map((c) => ({ id: c.id, label: c.label, who: { class: c.id } })) },
    { id: "region", label: "Region", groups: REGIONS.map((r) => ({ id: r.id, label: r.name, who: { region: r.id } })) },
  ];
}
function matches(pop, who) {
  for (const [key, val] of Object.entries(who || {})) {
    if (key === "lean") {
      for (const [ax, cond] of Object.entries(val)) {
        const n = parseFloat(cond.slice(1));
        if (cond[0] === ">" ? !(pop.pos[ax] > n) : !(pop.pos[ax] < n)) return false;
      }
    } else if (key === "loyalTo") {
      if (!(pop.loyal[val] > 0.2)) return false;
    } else if (Array.isArray(val)) {
      if (!val.includes(pop[key])) return false;
    } else if (pop[key] !== val) return false;
  }
  return true;
}
function popsMatching(state, who) { return state.pops.filter((p) => matches(p, who)); }
function sizeOf(state, who) { return popsMatching(state, who).reduce((a, p) => a + p.size, 0); }

function summarize(state, pops, ctx) {
  ctx = ctx || scoreContext(state);
  const res = { size: 0, voters: 0, turnout: 0, support: {}, core: {}, pos: {}, sal: {},
    aware: 0, leader: 0, leaderPull: 0, backers: 0, devotion: 0, followers: 0, disaffection: 0, mobilized: 0 };
  const player = playerParty(state);
  for (const p of state.parties) { res.support[p.id] = 0; res.core[p.id] = 0; }
  for (const ax of AXES) { res.pos[ax.id] = 0; res.sal[ax.id] = 0; }
  for (const pop of pops) {
    const sup = popSupport(state, pop, null, ctx);
    const votes = popVotes(pop, sup);
    res.size += pop.size;
    for (const p of state.parties) {
      res.support[p.id] += votes[p.id];
      res.voters += votes[p.id];
      res.core[p.id] += pop.size * pop.loyal[p.id];
    }
    for (const ax of AXES) {
      res.pos[ax.id] += pop.size * pop.pos[ax.id];
      res.sal[ax.id] += pop.size * salienceOf(state, pop, ax.id);
    }
    const dev = devotionOf(pop, player);
    res.aware += pop.size * pop.aware.player;
    res.leader += pop.size * pop.leader.player;
    res.leaderPull += pop.size * pop.leaderPull;
    res.disaffection += pop.size * pop.disaffection;
    res.mobilized += pop.size * pop.mobilized;
    res.backers += pop.size * sup.player;            // people who would vote for you
    res.devotion += pop.size * sup.player * dev;     // ...weighted by how devoted they are
    if (dev >= 0.8) res.followers += pop.size * sup.player; // ...who would follow you anywhere
  }
  if (res.size) {
    for (const id in res.support) res.support[id] /= res.voters || 1;
    for (const ax of AXES) { res.pos[ax.id] /= res.size; res.sal[ax.id] /= res.size; }
    res.turnout = res.voters / res.size;
    for (const k of ["aware", "leader", "leaderPull", "disaffection", "mobilized"]) res[k] /= res.size;
    res.devotion = res.backers ? res.devotion / res.backers : 0;
  }
  return res;
}

// ---------- Effects: what events, offers, actions and campaigns do ----------
// Shifts your public image and records a flip whenever a stance boundary is crossed.
function shiftPerceived(state, shift, record = true) {
  const player = playerParty(state);
  for (const [ax, d] of Object.entries(shift || {})) {
    const before = stanceOf(player.perceived[ax]);
    player.perceived[ax] = clamp(player.perceived[ax] + d, -100, 100);
    const after = stanceOf(player.perceived[ax]);
    if (record && before !== after) state.flips.push({ party: player.id, week: state.week, axis: ax, from: before, to: after });
  }
}
// Preview: which stances a shift would change, without changing anything.
function previewShift(state, shift) {
  const player = playerParty(state);
  const out = [];
  for (const [ax, d] of Object.entries(shift || {})) {
    const from = stanceOf(player.perceived[ax]);
    const to = stanceOf(clamp(player.perceived[ax] + d, -100, 100));
    out.push({ axis: ax, delta: d, from, to, manifesto: stanceOf(player.manifesto[ax]) });
  }
  return out;
}
function applyEffects(state, fx) {
  const player = playerParty(state);
  shiftPerceived(state, fx.shift);
  for (const g of fx.goodwill || []) {
    const party = g.party || player.id;
    for (const pop of state.pops) {
      if (matches(pop, g.who)) pop.goodwill[party] = clamp(pop.goodwill[party] + g.amt * CONFIG.goodwillScale, -2, 2);
    }
  }
  if (fx.leader) {
    const scale = player.charisma / 50;
    for (const pop of state.pops) {
      for (const g of [].concat(fx.leader)) {
        const who = typeof g === "number" ? {} : g.who;
        const amt = typeof g === "number" ? g : g.amt;
        if (matches(pop, who)) pop.leader.player = clamp(pop.leader.player + amt * scale, -2, 2);
      }
    }
  }
  if (fx.charisma) player.charisma = clamp(player.charisma + fx.charisma, 10, 100);
  for (const [ax, d] of Object.entries(fx.salience || {})) {
    state.salMod[ax] = clamp((state.salMod[ax] || 0) + d, -0.5, 1.5);
  }
  if (fx.trust) changeTrust(state, fx.trust);
  for (const [pid, d] of Object.entries(fx.stability || {})) {
    const p = partyOf(state, pid);
    if (p) p.stability = clamp(p.stability + d, 0, 100);
  }
  const coverage = fx.awareness ?? CONFIG.eventAwareness;
  for (const pop of state.pops) {
    pop.aware[player.id] = clamp(pop.aware[player.id] + (1 - pop.aware[player.id]) * coverage, 0.01, 1);
  }
  if (fx.money) state.money = Math.max(0, state.money + fx.money);
  if (fx.flag) state.flags[fx.flag] = state.week;
  if (fx.scandal) state.scandals.push({ ...fx.scandal, week: state.week });
  if (fx.followup) {
    const [lo, hi] = fx.followup.months;
    const months = lo + Math.floor(rand(state) * (hi - lo + 1));
    state.scheduled.push({ id: fx.followup.event, week: state.week + months * WEEKS_PER_MONTH });
  }
}

// ---------- Trust in the system ----------
function changeTrust(state, d) { state.trust = clamp(state.trust + d, 0, 100); }
function trustLabel(t) {
  if (t >= 60) return "High";
  if (t >= 45) return "Steady";
  if (t >= 30) return "Low";
  if (t >= 15) return "Very low";
  return "Collapsed";
}

// ---------- Issue ownership ----------
function addOwnership(state, partyId, key, amount) {
  const owners = (state.ownership[key] = state.ownership[key] || {});
  owners[partyId] = clamp((owners[partyId] || 0) + amount, 0, 1);
}
// Who owns which issue, largest first. Used by the Parties and Actions screens.
function ownershipTable(state) {
  return Object.entries(state.ownership).map(([key, owners]) => {
    const total = Object.values(owners).reduce((a, b) => a + b, 0);
    const list = Object.entries(owners).filter(([, v]) => v >= 0.02).sort((a, b) => b[1] - a[1])
      .map(([pid, v]) => ({ party: pid, value: v, share: total ? v / total : 0 }));
    return { key, axis: key.split(":")[0], label: sideLabel(key), heat: state.salMod[key.split(":")[0]] || 0, owners: list };
  }).filter((r) => r.owners.length);
}
function ownershipOf(state, partyId, key) { return ((state.ownership[key] || {})[partyId]) || 0; }

// ---------- Rival parties ----------
function pushNews(state, item) { state.news.push({ week: state.week, ...item }); }

function freeCoreVoters(state, party, share) {
  let freed = 0;
  for (const pop of state.pops) {
    const lost = pop.loyal[party.id] * share;
    pop.loyal[party.id] -= lost;
    freed += lost * pop.size;
  }
  return freed;
}
// The axes where your public image differs most from a party's.
function biggestDifferences(state, a, b, n = 2) {
  return AXES.map((ax) => ({ ax: ax.id, d: b.perceived[ax.id] - a.perceived[ax.id] }))
    .sort((x, y) => Math.abs(y.d) - Math.abs(x.d)).slice(0, n);
}

const RIVAL_HAPPENINGS = [
  { id: "scandal", weight: (p) => 1 + (60 - p.stability) / 40,
    run(state, p) {
      p.stability = clamp(p.stability - 18, 0, 100);
      p.charisma = clamp(p.charisma - 5, 10, 100);
      changeTrust(state, -4);
      for (const pop of state.pops) pop.goodwill[p.id] = clamp(pop.goodwill[p.id] - 0.25, -2, 2);
      pushNews(state, { party: p.id, kind: "bad", title: `${p.short} rocked by scandal`,
        text: `Leaked messages show ${p.leader} arranging state contracts for party donors. ${p.short} is in turmoil and trust in politics has fallen.` });
    } },
  { id: "infighting", weight: (p) => 0.8 + (55 - p.stability) / 30,
    run(state, p) {
      p.stability = clamp(p.stability - 12, 0, 100);
      pushNews(state, { party: p.id, kind: "bad", title: `Open infighting in ${p.short}`,
        text: `A faction inside ${p.name} is openly attacking ${p.leader}. Party members are taking sides.` });
    } },
  { id: "new_leader", weight: (p) => (p.charisma < 48 || p.stability < 40 ? 1.2 : 0.3),
    run(state, p) {
      const old = p.leader;
      const used = state.parties.map((x) => x.leader);
      p.leader = pick(state, LEADER_POOL.filter((n) => !used.includes(n)));
      p.charisma = Math.round(28 + rand(state) * 50);
      p.stability = 58;
      // A new leader takes the party somewhere new on one issue.
      const ax = pick(state, AXES).id;
      const dir = rand(state) < 0.5 ? -1 : 1;
      p.perceived[ax] = clamp(p.perceived[ax] + dir * 22, -100, 100);
      p.manifesto[ax] = p.perceived[ax]; // an official change of line, not a flip-flop
      const a = byId(AXES, ax);
      const style = p.charisma >= 62 ? "a charismatic crowd-pleaser" : p.charisma <= 40 ? "a dull party insider" : "a capable but unexciting figure";
      pushNews(state, { party: p.id, kind: p.charisma >= 55 ? "good" : "neutral", title: `${p.short} replaces ${old} with ${p.leader}`,
        text: `${p.leader} is ${style}, and is moving ${p.short} toward ${(dir < 0 ? a.left : a.right).toLowerCase()}.` });
    } },
  { id: "rebound", weight: (p) => (p.stability < 50 ? 0.7 : 0.4),
    run(state, p) {
      p.stability = clamp(p.stability + 15, 0, 100);
      p.charisma = clamp(p.charisma + 6, 10, 100);
      for (const pop of state.pops) if (pop.loyal[p.id] > 0.15) pop.goodwill[p.id] = clamp(pop.goodwill[p.id] + 0.2, -2, 2);
      pushNews(state, { party: p.id, kind: "good", title: `${p.leader} wins back the room`,
        text: `A strong conference speech has united ${p.short} again. Its base is energised.` });
    } },
];
function rivalHappening(state) {
  const cands = rivals(state).flatMap((p) => RIVAL_HAPPENINGS.map((h) => ({ p, h, w: Math.max(0.05, h.weight(p)) })));
  let r = rand(state) * cands.reduce((a, c) => a + c.w, 0);
  for (const c of cands) { r -= c.w; if (r <= 0) { c.h.run(state, c.p); return; } }
}
// A party that falls apart releases its core voters: a power vacuum.
function collapseParty(state, p) {
  const freed = freeCoreVoters(state, p, 0.3);
  for (const pop of state.pops) pop.goodwill[p.id] = clamp(pop.goodwill[p.id] - 0.3, -2, 2);
  p.stability = 45;
  p.charisma = clamp(p.charisma - 8, 10, 100);
  p.collapses = (p.collapses || 0) + 1;
  p.lastCollapse = state.week;
  p.stability = 55;
  changeTrust(state, -3);
  pushNews(state, { party: p.id, kind: "vacuum", title: `${p.name} splits apart`,
    text: `After months of infighting, a third of ${p.short}'s MPs have walked out. About ${(freed / 1e6).toFixed(1)} million of its loyal voters are now up for grabs. Whoever stands closest to them will pick them up.` });
  // Offer the player the defectors.
  state.queue.push({ type: "event", event: defectorEvent(state, p, freed) });
}
function defectorEvent(state, p, freed) {
  const diffs = biggestDifferences(state, playerParty(state), p);
  const shift = Object.fromEntries(diffs.map((x) => [x.ax, Math.sign(x.d) * 10]));
  const small = Object.fromEntries(diffs.slice(0, 1).map((x) => [x.ax, Math.sign(x.d) * 5]));
  return {
    id: `defectors_${p.id}`, kind: "opportunity", title: `${p.short} rebels want to join you`,
    text: `Fifteen MPs who walked out of ${p.name} are offering to join your party, with their local organisations. They expect you to make room for their views.`,
    choices: [
      { label: "Welcome all of them", effects: { shift, awareness: 0.05, defect: { from: p.id, share: 0.22 },
        goodwill: [{ who: { loyalTo: p.id }, amt: 0.3 }] } },
      { label: "Take only the local organisers, not the MPs", effects: { shift: small, defect: { from: p.id, share: 0.1 },
        goodwill: [{ who: { loyalTo: p.id }, amt: 0.12 }] } },
      { label: "Refuse: we are not a home for failed politicians", effects: { awareness: 0.02, trust: 1,
        goodwill: [{ who: { lean: { rev: "<-20" } }, amt: 0.15 }] } },
    ],
  };
}
// Move a share of another party's core voters into yours, where they agree with you.
function defect(state, fromId, share) {
  const from = partyOf(state, fromId);
  const player = playerParty(state);
  let moved = 0;
  for (const pop of state.pops) {
    const closeness = clamp(1.4 - distance(state, pop, player.perceived) / 60, 0, 1);
    const m = pop.loyal[fromId] * share * closeness;
    pop.loyal[fromId] -= m;
    pop.loyal.player = clamp(pop.loyal.player + m, 0, 0.9);
    pop.aware.player = Math.max(pop.aware.player, Math.min(1, pop.aware.player + m * 2));
    moved += m * pop.size;
  }
  from.stability = clamp(from.stability - 5, 0, 100);
  return moved;
}
// Each year, parties that are losing voters to you copy your most popular position.
function rivalsAdapt(state, before, now) {
  const player = playerParty(state);
  const nation = summarize(state, state.pops);
  for (const p of rivals(state)) {
    const lost = before[p.id] - now[p.id];
    const youGained = now.player - before.player;
    if (lost < 0.015 || youGained < 0.01) continue;
    const ax = AXES.map((a) => ({ a, score: nation.sal[a.id] * Math.abs(player.perceived[a.id] - p.perceived[a.id]) }))
      .sort((x, y) => y.score - x.score)[0].a;
    const d = clamp(player.perceived[ax.id] - p.perceived[ax.id], -15, 15);
    p.perceived[ax.id] = clamp(p.perceived[ax.id] + d, -100, 100);
    p.manifesto[ax.id] = p.perceived[ax.id];
    const side = d < 0 ? "L" : "R";
    addOwnership(state, p.id, sideKey(ax.id, side), 0.12);
    pushNews(state, { party: p.id, kind: "threat", title: `${p.short} copies your line on ${ax.issue.toLowerCase()}`,
      text: `Worried about losing voters to you, ${p.leader} has moved ${p.short} toward ${(d < 0 ? ax.left : ax.right).toLowerCase()}. They will compete for the same voters.` });
  }
}
function rivalsMonthly(state, nowSupport) {
  for (const p of rivals(state)) {
    const trend = state.lastSupport ? nowSupport[p.id] - state.lastSupport[p.id] : 0;
    let d = (60 - p.stability) * 0.08 + randNormal(state) * 3 + clamp(trend * 120, -4, 4);
    if (p.ruling) d -= 0.8 + Math.max(0, 35 - state.trust) * 0.05; // governing wears you down
    p.stability = clamp(p.stability + d, 0, 100);
  }
  if (rand(state) < CONFIG.rivalEventChance) rivalHappening(state);
  const falling = rivals(state).find((p) => p.stability < CONFIG.collapseAt
    && state.week - (p.lastCollapse ?? -999) > CONFIG.collapseCooldownMonths * WEEKS_PER_MONTH);
  if (falling) collapseParty(state, falling);
}

// Leading the polls makes you the target: the press digs and rivals gang up.
const SCRUTINY_STORIES = [
  { title: "Newspaper digs into your party's finances", text: "A long investigation questions where your money comes from. Nothing illegal yet, but the headlines hurt.",
    fx: { goodwill: [{ who: { class: ["middle", "upper"] }, amt: -0.25 }, { who: {}, amt: -0.08 }] } },
  { title: "Old videos of your leader resurface", text: "Clips of your leader's past speeches are circulating, edited to look as extreme as possible.",
    fx: { leader: -0.15, goodwill: [{ who: { lean: { rev: ">10" } }, amt: -0.2 }] } },
  { title: "Rivals unite against you", text: "The other party leaders appeared together to warn that your party is \"a danger to Cranebonistan\".",
    fx: { goodwill: [{ who: { loyalTo: "nup" }, amt: -0.3 }, { who: { loyalTo: "oc" }, amt: -0.3 }, { who: { class: "middle" }, amt: -0.12 }] } },
  { title: "Your candidates' gaffes go viral", text: "A local candidate of yours was filmed saying something unrepeatable. The clip is everywhere.",
    fx: { goodwill: [{ who: {}, amt: -0.12 }] } },
];
function frontrunnerScrutiny(state, now) {
  if (now.player < CONFIG.scrutinyFrom || rand(state) > CONFIG.scrutinyChance) return;
  const story = pick(state, SCRUTINY_STORIES);
  applyEffects(state, { ...story.fx, awareness: 0.02 });
  pushNews(state, { kind: "threat", title: story.title, text: story.text + " Leading the polls makes you a target." });
}

// ---------- Monthly dynamics ----------
function monthlyUpdate(state) {
  for (const ax in state.salMod) state.salMod[ax] *= CONFIG.salienceDecay;
  // Sometimes one issue suddenly dominates the news.
  if (rand(state) < CONFIG.newsWaveChance) {
    const ax = pick(state, AXES);
    state.salMod[ax.id] = clamp((state.salMod[ax.id] || 0) + CONFIG.newsWaveSize, -0.5, 1.5);
    const owners = ownershipTable(state).filter((r) => r.axis === ax.id && r.owners.length);
    const who = owners.map((r) => `${partyOf(state, r.owners[0].party).short} (${r.label.toLowerCase()})`).join(" and ");
    pushNews(state, { kind: "issue", title: `${ax.issue} dominates the headlines`,
      text: `Everyone is suddenly talking about ${ax.issue.toLowerCase()}, and for many voters it is now the only issue that matters. ${who ? `The parties that own it gain most: ${who}.` : "Nobody owns this issue yet."}` });
  }
  for (const key in state.ownership) for (const pid in state.ownership[key]) state.ownership[key][pid] *= CONFIG.ownDecay;
  state.trust += (50 - state.trust) * CONFIG.trustRecovery;
  state.actionsLeft = CONFIG.actionsPerMonth;

  const player = playerParty(state);
  // People slowly forget: your image drifts back toward your manifesto. Not counted as a flip.
  const pull = {};
  for (const ax of AXES) pull[ax.id] = (player.manifesto[ax.id] - player.perceived[ax.id]) * CONFIG.perceivedPull;
  shiftPerceived(state, pull, false);

  const ctx = scoreContext(state);
  for (const pop of state.pops) {
    const sup = popSupport(state, pop, null, ctx);
    const dev = devotionOf(pop, player);
    // The cult: devoted followers start adopting the leader's views.
    if (dev > 0.5) for (const ax of AXES) pop.pos[ax.id] += (player.perceived[ax.id] - pop.pos[ax.id]) * CONFIG.cultPull * dev;
    pop.mobilized *= CONFIG.mobilizeDecay;
    let loyalTotal = 0;
    for (const p of state.parties) {
      pop.goodwill[p.id] *= CONFIG.goodwillDecay;
      pop.leader[p.id] *= CONFIG.leaderDecay;
      if (p.isPlayer) {
        pop.aware[p.id] = CONFIG.awarenessFloor + (pop.aware[p.id] - CONFIG.awarenessFloor) * CONFIG.awarenessDecay;
      }
      // Floating supporters slowly become core supporters...
      const floating = sup[p.id] - pop.loyal[p.id];
      let core = pop.loyal[p.id] * (1 - CONFIG.loyaltyChurn) + floating * CONFIG.loyaltyGain;
      // ...unless the party keeps contradicting itself. Devoted followers stay anyway.
      const erosion = CONFIG.coreErosion * Math.max(0, ctx.inc[p.id] - CONFIG.inconsistencyTolerance);
      core *= 1 - erosion * (1 - devotionOf(pop, p));
      pop.loyal[p.id] = clamp(core, 0, 0.9);
      loyalTotal += pop.loyal[p.id];
    }
    if (loyalTotal > 0.85) for (const p of state.parties) pop.loyal[p.id] *= 0.85 / loyalTotal;
  }
  const now = summarize(state, state.pops).support;
  rivalsMonthly(state, now);
  frontrunnerScrutiny(state, now);
  state.trustHistory.push({ week: state.week, trust: state.trust });
  state.lastSupport = now;
}

// ---------- Actions: things you choose to do each month ----------
// Each returns { ok, text } for the screen. All cost one action point.
const ACTIONS = {
  champion: { label: "Champion an issue", cost: 0,
    help: "Campaign hard on one of your manifesto's issues to win its single-issue voters: people who care about that issue above everything else. You can campaign on two issues at a time. Claims are cheapest while nobody is talking about the issue; when it later dominates the news, many more voters become single-issue voters and its owner gains most." },
  grassroots: { label: "Grassroots organising", cost: 1.5,
    help: "Door-to-door work and local branches in one region. Turns supporters into core voters and gets them to the polls. Slow, but it lasts." },
  research: { label: "Opposition research", cost: 2,
    help: "Pay investigators to dig into a rival. You may find something you can release later. You may also get caught." },
  release: { label: "Release a dossier", cost: 0,
    help: "Leak what you found to the press. It weakens the rival's support and stability, and lowers trust in politics, which helps outsiders like you." },
  poach: { label: "Recruit defectors", cost: 2,
    help: "Only possible when a rival is unstable, and once every six months per party. Win over some of their local organisers and core voters, but they bring their views with them." },
  outrage: { label: "Provoke outrage", cost: 0,
    help: "Say something deliberately shocking. Huge coverage and excitement among anti-system voters; the educated middle class is appalled." },
};
function canAct(state, cost = 0) {
  if (state.result) return "The election is over.";
  if (state.actionsLeft <= 0) return "No actions left this month.";
  if (state.money < cost) return `Needs ₱${cost}M.`;
  return null;
}
function spendAction(state, cost) { state.actionsLeft--; state.money -= cost; }

// Which side of an issue your manifesto takes: "L", "R" or null (neutral).
function manifestoSide(state, axis) {
  const st = stanceOf(playerParty(state).manifesto[axis]);
  return st <= 1 ? "L" : st >= 3 ? "R" : null;
}
// Why you can't champion this side, or null if you can.
function championBlock(state, axis, side) {
  const mine = manifestoSide(state, axis);
  if (!mine) return "Your manifesto is neutral on this issue.";
  if (mine !== side) return "Your manifesto takes the other side.";
  const key = sideKey(axis, side);
  if (!state.signature.includes(key) && state.signature.length >= CONFIG.maxSignatureIssues)
    return `You already campaign on ${CONFIG.maxSignatureIssues} issues. Drop one first.`;
  return null;
}
function championPreview(state, axis, side) {
  const heat = Math.max(0, state.salMod[axis] || 0);
  const gain = 0.22 / (1 + 2 * heat);
  const ax = byId(AXES, axis);
  // how many people care enough about this issue to vote on it alone, on your side
  let single = 0;
  for (const pop of state.pops) {
    const p = pop.pos[axis];
    if (((side === "L" && p < -15) || (side === "R" && p > 15)) && salienceOf(state, pop, axis) > CONFIG.singleIssueFrom) single += pop.size;
  }
  return { gain, heat, single, block: championBlock(state, axis, side), shift: previewShift(state, { [axis]: side === "L" ? -6 : 6 })[0], ax };
}
function dropSignature(state, key) {
  state.signature = state.signature.filter((k) => k !== key);
  state.log.push({ week: state.week, kind: "action", text: `Stopped campaigning on ${sideLabel(key).toLowerCase()}.` });
}
function actChampion(state, axis, side) {
  const err = canAct(state, 0); if (err) return { ok: false, text: err };
  const block = championBlock(state, axis, side); if (block) return { ok: false, text: block };
  const { gain } = championPreview(state, axis, side);
  if (!state.signature.includes(sideKey(axis, side))) state.signature.push(sideKey(axis, side));
  const key = sideKey(axis, side);
  spendAction(state, 0);
  addOwnership(state, "player", key, gain);
  state.salMod[axis] = clamp((state.salMod[axis] || 0) + 0.12, -0.5, 1.5);
  shiftPerceived(state, { [axis]: side === "L" ? -6 : 6 });
  for (const pop of state.pops) {
    const p = pop.pos[axis];
    const onSide = side === "L" ? p < -15 : p > 15;
    const against = side === "L" ? p > 25 : p < -25;
    if (onSide) {
      pop.aware.player = clamp(pop.aware.player + (1 - pop.aware.player) * 0.03, 0, 1);
      pop.goodwill.player = clamp(pop.goodwill.player + 0.06 * pop.sal[axis], -2, 2);
    } else if (against) pop.goodwill.player = clamp(pop.goodwill.player - 0.05 * pop.sal[axis], -2, 2);
  }
  const text = `You are campaigning hard for ${sideLabel(key).toLowerCase()}. Your claim on the issue is now ${Math.round(ownershipOf(state, "player", key) * 100)}.`;
  state.log.push({ week: state.week, kind: "action", text });
  return { ok: true, text };
}
function actGrassroots(state, regionId) {
  const cost = ACTIONS.grassroots.cost;
  const err = canAct(state, cost); if (err) return { ok: false, text: err };
  spendAction(state, cost);
  const player = playerParty(state);
  const ctx = scoreContext(state);
  let newCore = 0;
  for (const pop of state.pops) if (pop.region === regionId) {
    const sup = popSupport(state, pop, null, ctx);
    const floating = Math.max(0, sup.player - pop.loyal.player);
    const m = floating * 0.08;
    pop.loyal.player = clamp(pop.loyal.player + m, 0, 0.9);
    newCore += m * pop.size;
    pop.mobilized = clamp(pop.mobilized + 0.05, 0, 0.15);
    pop.leader.player = clamp(pop.leader.player + 0.04 * pop.leaderPull * (player.charisma / 50), -2, 2);
  }
  const r = byId(REGIONS, regionId);
  const text = `Volunteers knocked on doors across ${r.name}. ${Math.round(newCore / 1000)}k supporters became core voters, and turnout among your supporters there is up.`;
  state.log.push({ week: state.week, kind: "action", text });
  return { ok: true, text };
}
function actResearch(state, partyId) {
  const cost = ACTIONS.research.cost;
  const err = canAct(state, cost); if (err) return { ok: false, text: err };
  spendAction(state, cost);
  const p = partyOf(state, partyId);
  const r = rand(state);
  let text;
  if (r < 0.15) {
    applyEffects(state, { awareness: 0.03, leader: -0.08,
      goodwill: [{ who: { class: ["middle", "upper"] }, amt: -0.25 }, { who: {}, amt: -0.05 }] });
    text = `Your investigators were caught going through ${p.short}'s bins. The press is calling it a dirty trick.`;
  } else if (r < 0.65) {
    const severity = rand(state) < 0.3 ? 3 : rand(state) < 0.6 ? 2 : 1;
    const what = ["an unpaid tax bill", "an expenses fiddle", "secret payments from a tycoon"][severity - 1];
    state.dossiers.push({ party: partyId, severity, what, week: state.week });
    text = `Found it: ${what} involving ${p.leader}. The dossier is ready to release whenever you choose.`;
  } else {
    text = `Your investigators found nothing useful on ${p.short}.`;
  }
  state.log.push({ week: state.week, kind: "action", text });
  return { ok: true, text };
}
function actRelease(state, index) {
  const err = canAct(state, 0); if (err) return { ok: false, text: err };
  const dos = state.dossiers[index];
  if (!dos) return { ok: false, text: "No such dossier." };
  spendAction(state, 0);
  state.dossiers.splice(index, 1);
  const p = partyOf(state, dos.party);
  const sev = dos.severity;
  p.stability = clamp(p.stability - 5 * sev, 0, 100);
  p.charisma = clamp(p.charisma - 3 * sev, 10, 100);
  for (const pop of state.pops) {
    pop.goodwill[p.id] = clamp(pop.goodwill[p.id] - 0.12 * sev, -2, 2);
    pop.loyal[p.id] *= 1 - 0.03 * sev;
  }
  changeTrust(state, -2 * sev);
  applyEffects(state, { awareness: 0.03 });
  const text = `The story broke: ${dos.what} involving ${p.leader}. ${p.short} is reeling.`;
  state.log.push({ week: state.week, kind: "action", text });
  return { ok: true, text };
}
function canPoach(state, partyId) {
  const p = partyOf(state, partyId);
  return p.stability < 40 && state.week - (p.lastPoached ?? -999) >= CONFIG.poachCooldownMonths * WEEKS_PER_MONTH;
}
function actPoach(state, partyId) {
  const cost = ACTIONS.poach.cost;
  const err = canAct(state, cost); if (err) return { ok: false, text: err };
  if (!canPoach(state, partyId)) return { ok: false, text: "Nobody in that party is ready to leave right now." };
  spendAction(state, cost);
  const p = partyOf(state, partyId);
  p.lastPoached = state.week;
  const moved = defect(state, partyId, 0.07);
  const diffs = biggestDifferences(state, playerParty(state), p, 1);
  shiftPerceived(state, { [diffs[0].ax]: Math.sign(diffs[0].d) * 5 });
  const text = `Local ${p.short} organisers crossed over to you, bringing about ${Math.round(moved / 1000)}k core voters. Your image moved a little toward theirs.`;
  state.log.push({ week: state.week, kind: "action", text });
  return { ok: true, text };
}
function actOutrage(state) {
  const err = canAct(state, 0); if (err) return { ok: false, text: err };
  spendAction(state, 0);
  // Outrage wears off: each recent stunt (last 6 months) makes the next one less effective.
  state.outrages = (state.outrages || []).filter((w) => state.week - w < 24);
  const f = 1 / (1 + state.outrages.length);
  state.outrages.push(state.week);
  applyEffects(state, { shift: { rev: -5 }, awareness: 0.07 * f, trust: -1,
    leader: [{ who: { lean: { rev: "<-10" } }, amt: 0.1 * f }, { who: { class: "working" }, amt: 0.05 * f }],
    goodwill: [{ who: { class: "middle" }, amt: -0.25 }, { who: { class: "upper" }, amt: -0.3 }, { who: { lean: { rev: "<-15" } }, amt: 0.15 * f }] });
  const text = f === 1 ? "Your comments are on every channel. Anti-system voters loved it; the middle class is horrified."
    : "Another provocation. The media is getting used to you: less coverage, same backlash.";
  state.log.push({ week: state.week, kind: "action", text });
  return { ok: true, text };
}
// ---------- Campaign budget ----------
const BUDGET_KEYS = [...REGIONS.map((r) => r.id), "social", "tv", "tour"];

// Pure function: what an allocation would do to each pop. Used for the preview and for real.
function campaignImpact(state, alloc) {
  const impact = new Map(); // pop -> { aware, goodwill, leader }
  const add = (pop, k, v) => {
    if (!impact.has(pop)) impact.set(pop, { aware: pop.aware.player, goodwill: 0, leader: 0 });
    impact.get(pop)[k] += v;
  };
  const awareGain = (pop, rate) => {
    const cur = impact.has(pop) ? impact.get(pop).aware : pop.aware.player;
    add(pop, "aware", (1 - cur) * clamp(rate, 0, 0.6));
  };
  for (const key of BUDGET_KEYS) {
    const m = +alloc[key] || 0;
    if (m <= 0) continue;
    const region = byId(REGIONS, key);
    if (region) {
      const f = m / region.adults;
      for (const pop of state.pops) if (pop.region === key) {
        awareGain(pop, CAMPAIGN.rally.aware * f);
        add(pop, "goodwill", CAMPAIGN.rally.goodwill * f);
        add(pop, "leader", CAMPAIGN.rally.leader * f);
      }
    } else if (key === "social" || key === "tv") {
      const c = CAMPAIGN[key];
      for (const pop of state.pops) if (c.ages.includes(pop.age)) awareGain(pop, c.aware * m);
    } else if (key === "tour") {
      for (const pop of state.pops) {
        awareGain(pop, CAMPAIGN.tour.aware * m);
        add(pop, "leader", CAMPAIGN.tour.leader * m * pop.leaderPull);
      }
    }
  }
  return impact;
}
// Awareness of your party, before and after, for each region and age group.
function previewBudget(state, alloc) {
  const impact = campaignImpact(state, alloc);
  const rows = {};
  const groups = [...REGIONS.map((r) => ({ id: r.id, who: { region: r.id } })),
    { id: "young", who: { age: ["18-29", "30-45"] } }, { id: "old", who: { age: ["46-60", "61+"] } },
    { id: "all", who: {} }];
  for (const g of groups) {
    let size = 0, before = 0, after = 0, leaderBefore = 0, leaderAfter = 0;
    for (const pop of popsMatching(state, g.who)) {
      const imp = impact.get(pop);
      size += pop.size;
      before += pop.size * pop.aware.player;
      after += pop.size * (imp ? imp.aware : pop.aware.player);
      leaderBefore += pop.size * pop.leader.player;
      leaderAfter += pop.size * (pop.leader.player + (imp ? imp.leader : 0));
    }
    rows[g.id] = { before: before / size, after: after / size, leaderBefore: leaderBefore / size, leaderAfter: leaderAfter / size };
  }
  return rows;
}
// offersTaken: ids of funding offers accepted this quarter.
function resolveBudget(state, alloc, offersTaken = []) {
  const player = playerParty(state);
  const notes = [];
  for (const id of offersTaken) {
    const offer = byId(FUNDING_OFFERS, id);
    if (!offer) continue;
    applyEffects(state, { ...offer.effects, awareness: 0 });
    notes.push(offer.source);
  }
  const clean = {};
  let spent = 0;
  for (const key of BUDGET_KEYS) {
    const m = clamp(+alloc[key] || 0, 0, Math.max(0, state.money - spent));
    clean[key] = m;
    spent += m;
  }
  const preview = previewBudget(state, clean);
  const impact = campaignImpact(state, clean);
  const swing = clean.social > 0 ? (rand(state) * 2 - 0.8) * CAMPAIGN.social.swing * clean.social : 0; // can backfire
  for (const [pop, imp] of impact) {
    pop.aware.player = clamp(imp.aware, 0.01, 1);
    pop.goodwill.player = clamp(pop.goodwill.player + imp.goodwill, -2, 2);
    pop.leader.player = clamp(pop.leader.player + imp.leader * (player.charisma / 50), -2, 2);
  }
  if (swing) for (const pop of state.pops) if (CAMPAIGN.social.ages.includes(pop.age)) {
    pop.goodwill.player = clamp(pop.goodwill.player + swing, -2, 2);
  }
  state.money -= spent;
  state.lastBudget = { ...clean };
  state.log.push({ week: state.week, kind: "budget",
    text: `Spent ₱${spent.toFixed(1)}M on campaigning${notes.length ? `. Took money from ${notes.join(", ")}` : ""}.` });
  finishFront(state, "budget");
  return { spent, preview, socialSwing: swing };
}
function drawOffers(state) {
  const pool = FUNDING_OFFERS.filter((o) => rand(state) < o.chance);
  return shuffle(state, pool).slice(0, 2).map((o) => o.id);
}

// ---------- Events ----------
function eligibleEvents(state) {
  return EVENTS.filter((e) => e.deck !== false
    && (!e.minYear || calendar(state.week).year >= e.minYear)
    && (!e.requires || state.flags[e.requires] !== undefined)
    && !(e.once && state.flags["seen:" + e.id] !== undefined));
}
function drawEvent(state) {
  // 1) a follow-up that is due
  const due = state.scheduled.findIndex((s) => s.week <= state.week);
  if (due >= 0) return state.scheduled.splice(due, 1)[0].id;
  // 2) dirty money leaking
  for (let i = 0; i < state.scandals.length; i++) {
    const sc = state.scandals[i];
    if (rand(state) < sc.chance * CONFIG.scandalChanceScale) { state.scandals.splice(i, 1); return sc.event; }
  }
  // 3) the shuffled deck
  const eligible = eligibleEvents(state).map((e) => e.id);
  state.deck = state.deck.filter((id) => eligible.includes(id));
  if (!state.deck.length) state.deck = shuffle(state, eligible);
  return state.deck.pop();
}
// Events come from events.js (by id) or are generated on the spot (front.event).
function eventOf(front) { return front.event || byId(EVENTS, front.id); }
function queueEvent(state, id) {
  const ev = byId(EVENTS, id);
  if (ev && ev.trust) changeTrust(state, ev.trust); // the news itself moves trust, whatever you say
  state.queue.push({ type: "event", id });
}
function resolveEvent(state, choiceIndex) {
  const front = state.queue[0];
  const ev = eventOf(front);
  const choice = ev.choices[choiceIndex];
  const before = { ...playerParty(state).perceived };
  const flipsBefore = state.flips.length;
  applyEffects(state, choice.effects);
  let extra = "";
  if (choice.effects.defect) {
    const moved = defect(state, choice.effects.defect.from, choice.effects.defect.share);
    extra = ` About ${Math.round(moved / 1000)}k core voters came with them.`;
  }
  state.flags["seen:" + ev.id] = state.week;
  state.log.push({ week: state.week, kind: "event", text: `${ev.title}: ${choice.label}.${extra}` });
  finishFront(state, "event");
  return { before, after: { ...playerParty(state).perceived }, flips: state.flips.slice(flipsBefore), extra };
}

// ---------- News: everything that happened this month, shown together ----------
function flushNews(state) {
  if (!state.news.length) return;
  state.queue.unshift({ type: "news", items: state.news });
  for (const n of state.news) state.log.push({ week: n.week, kind: "news", text: n.title + "." });
  state.news = [];
}

// ---------- Polls ----------
function noisy(state, shares, sd) {
  const out = {};
  let total = 0;
  for (const id in shares) { out[id] = Math.max(0.001, shares[id] + randNormal(state) * sd); total += out[id]; }
  for (const id in out) out[id] /= total;
  return out;
}
function takePoll(state, label) {
  const ctx = scoreContext(state);
  const nation = summarize(state, state.pops, ctx);
  const poll = { week: state.week, label, national: noisy(state, nation.support, CONFIG.pollError),
    turnout: nation.turnout, trust: state.trust, regions: {}, groups: {} };
  for (const kind of groupKinds()) for (const g of kind.groups) {
    const s = summarize(state, popsMatching(state, g.who), ctx);
    if (!s.size) continue;
    const entry = { support: noisy(state, s.support, CONFIG.pollError * 2), core: s.core };
    poll.groups[`${kind.id}:${g.id}`] = entry;
    if (kind.id === "region") poll.regions[g.id] = entry.support;
  }
  const prev = state.polls[state.polls.length - 1];
  state.polls.push(poll);
  if (prev) rivalsAdapt(state, prev.national, poll.national);
  state.queue.push({ type: "poll", index: state.polls.length - 1 });
}

// ---------- Elections (three separate stages) ----------
// 1) opinion happens in popSupport, 2) turnout in popVotes, 3) seats in allocateSeats.
function countVotes(state) {
  const byRegion = {};
  const ctx = scoreContext(state);
  for (const r of REGIONS) {
    byRegion[r.id] = {};
    for (const p of state.parties) byRegion[r.id][p.id] = 0;
  }
  for (const pop of state.pops) {
    const votes = popVotes(pop, popSupport(state, pop, null, ctx));
    for (const p of state.parties) byRegion[pop.region][p.id] += votes[p.id];
  }
  return byRegion;
}
// Electoral system: seats split between regions by population,
// then D'Hondt proportional allocation inside each region.
// Swap this one function to try winner-takes-all or national lists.
function allocateSeats(votesByRegion) {
  const totalAdults = REGIONS.reduce((a, r) => a + r.adults, 0);
  const quotas = REGIONS.map((r) => ({ id: r.id, exact: CONFIG.seats * r.adults / totalAdults }));
  quotas.forEach((q) => (q.seats = Math.floor(q.exact)));
  const left = CONFIG.seats - quotas.reduce((a, q) => a + q.seats, 0);
  [...quotas].sort((a, b) => (b.exact % 1) - (a.exact % 1)).slice(0, left).forEach((q) => q.seats++);

  const seats = { national: {}, regions: {} };
  for (const q of quotas) {
    const votes = votesByRegion[q.id];
    const won = Object.fromEntries(Object.keys(votes).map((id) => [id, 0]));
    for (let i = 0; i < q.seats; i++) {
      let best = null, bestVal = -1;
      for (const id in votes) {
        const v = votes[id] / (won[id] + 1);
        if (v > bestVal) { bestVal = v; best = id; }
      }
      won[best]++;
    }
    seats.regions[q.id] = won;
    for (const id in won) seats.national[id] = (seats.national[id] || 0) + won[id];
  }
  return seats;
}
function runElection(state) {
  const votes = countVotes(state);
  const seats = allocateSeats(votes);
  const national = {};
  let total = 0;
  for (const r in votes) for (const id in votes[r]) { national[id] = (national[id] || 0) + votes[r][id]; total += votes[r][id]; }
  for (const id in national) national[id] /= total;
  const ranking = Object.keys(seats.national).sort((a, b) => seats.national[b] - seats.national[a]);
  state.result = { votes: national, seats, ranking, playerWon: ranking[0] === "player",
    majority: seats.national.player > CONFIG.seats / 2 };
  state.queue.push({ type: "election" });
}

// ---------- Time: weekly ticks and hooks ----------
// Each hook checks the calendar and may put something in the queue.
// New phases of the game (governing, parliament votes) = new hooks.
const HOOKS = [
  { name: "election", final: true, when: (c) => c.week === ELECTION_WEEK, run: runElection },
  { name: "opening poll", when: (c) => c.week === 0, run: (s) => takePoll(s, "Opening poll") },
  { name: "monthly update", when: (c) => c.isMonthStart && c.week > 0, run: monthlyUpdate },
  { name: "quarterly budget", when: (c) => c.isQuarterStart,
    run: (s) => { s.money += CONFIG.quarterIncome; s.queue.push({ type: "budget", offers: drawOffers(s) }); } },
  { name: "monthly event", when: (c) => c.isMonthStart, run: (s) => queueEvent(s, drawEvent(s)) },
  { name: "annual poll", when: (c) => c.isYearEnd, run: (s) => takePoll(s, `Annual poll ${calendar(s.week).year}`) },
  { name: "news", when: () => true, run: flushNews }, // news always shows first
];
function runHooks(state) {
  const c = calendar(state.week);
  for (const hook of HOOKS) {
    if (!hook.when(c)) continue;
    hook.run(state);
    if (hook.final) break;
  }
}
function advanceWeek(state) {
  if (state.queue.length || state.result) return false;
  state.week++;
  runHooks(state);
  return true;
}
// Fast-forward until the player has something to decide.
function advanceToDecision(state) {
  let moved = false;
  while (advanceWeek(state)) { moved = true; if (state.queue.length) break; }
  return moved;
}
function finishFront(state, type) {
  if (state.queue[0] && state.queue[0].type === type) state.queue.shift();
}
function dismissFront(state) { state.queue.shift(); flushNews(state); }

// ---------- Describing effects in plain words (used by the screens) ----------
function describeWho(who) {
  if (!who || !Object.keys(who).length) return "everyone";
  const list = (v, f) => [].concat(v).map(f).join(" or ");
  let noun = "voters";
  if (who.nationality) noun = list(who.nationality, (id) => byId(NATIONALITIES, id).plural);
  if (who.lean) {
    noun = Object.entries(who.lean).map(([ax, c]) => {
      const a = byId(AXES, ax);
      return c[0] === "<" ? a.leftGroup : a.rightGroup;
    }).join(" and ");
  }
  if (who.loyalTo) noun = who.loyalTo === "player" ? "your core supporters" : `${byId(PARTIES, who.loyalTo).short} core supporters`;
  let text = noun;
  if (who.class) text = `${list(who.class, (id) => byId(CLASSES, id).adj)} ${text}`;
  if (who.age) text += ` aged ${list(who.age, (id) => byId(AGES, id).label)}`;
  if (who.region) {
    const regions = list(who.region, (id) => byId(REGIONS, id).name).replace(/ or /g, " and ");
    text = noun === "voters" && !who.class && !who.age ? regions : `${text} in ${regions}`;
  }
  return text;
}
// Turns a choice's effects into "Appeals to / Angers / other" lines, largest groups first.
function describeChoice(state, fx) {
  const groups = (fx.goodwill || []).filter((g) => !g.party).map((g) => {
    // core supporters are counted as people, not as whole pops
    const size = g.who.loyalTo
      ? state.pops.reduce((a, p) => a + p.size * p.loyal[g.who.loyalTo], 0)
      : sizeOf(state, g.who);
    return { text: describeWho(g.who), amt: g.amt, size, weight: Math.abs(g.amt) * size };
  }).sort((a, b) => b.weight - a.weight);
  const strength = (amt) => (Math.abs(amt) >= 0.5 ? "strongly" : Math.abs(amt) < 0.2 ? "slightly" : "");
  const fmt = (g) => ({ text: g.text, size: g.size, strength: strength(g.amt) });
  const tags = [];
  if (fx.leader) {
    const total = [].concat(fx.leader).reduce((a, g) => a + (typeof g === "number" ? g : g.amt), 0);
    tags.push(total >= 0 ? "Builds your leader's image" : "Hurts your leader's image");
  }
  if ((fx.awareness ?? CONFIG.eventAwareness) >= 0.05) tags.push("Big media coverage");
  if (fx.awareness === 0) tags.push("No media coverage");
  if (fx.money) tags.push(fx.money > 0 ? `+₱${fx.money}M` : `Costs ₱${-fx.money}M`);
  if (fx.scandal) tags.push("Scandal risk");
  if (fx.trust) tags.push(fx.trust < 0 ? "Lowers trust in politics" : "Raises trust in politics");
  if (fx.defect) tags.push(`Gains ${partyOf(state, fx.defect.from).short} core voters`);
  return {
    appeals: groups.filter((g) => g.amt > 0 && g.size > 0).map(fmt),
    angers: groups.filter((g) => g.amt < 0 && g.size > 0).map(fmt),
    stances: previewShift(state, fx.shift),
    tags,
  };
}
