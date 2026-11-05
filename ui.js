// =====================================================================
// ui.js — screens, map and buttons.
// It only READS the state and CALLS sim.js functions. All game rules
// live in sim.js, so the interface can be redesigned without touching them.
// =====================================================================
"use strict";

const SAVE_KEY = "cranebonistan-save-v6";
const SVG_NS = "http://www.w3.org/2000/svg";
let S = null; // the game state (created by newGame or loaded from a save)
const ui = { tab: "electorate", kind: "age", group: "18-29", budget: null, offers: [], draft: null, champ: null };

const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const pct = (x, d = 1) => (x * 100).toFixed(d) + "%";
const millions = (n) => (n / 1e6).toFixed(2) + " million";
const partyById = (id) => S.parties.find((p) => p.id === id);
const latestPoll = () => S.polls[S.polls.length - 1];

// ---------- Saving ----------
function save() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch (e) { /* storage unavailable */ } }
function loadSave() { try { const t = localStorage.getItem(SAVE_KEY); return t ? JSON.parse(t) : null; } catch (e) { return null; } }
function clearSave() { try { localStorage.removeItem(SAVE_KEY); } catch (e) {} }

// ---------- Render everything ----------
function render() {
  if (!S) { if (ui.create) renderCreate(); else renderTitle(); return; }
  renderStatus();
  updateMap();
  renderTabs();
  renderModal();
}

// ---------- Top bar ----------
function renderStatus() {
  const player = partyById("player");
  const weeksLeft = ELECTION_WEEK - S.week;
  const monthsLeft = Math.ceil(weeksLeft / CONFIG.weeksPerMonth);
  $("#election-year").textContent = calendar(ELECTION_WEEK).year;
  $("#status").innerHTML = `
    <div class="stat stat-party">${portraitHTML(player, "portrait-sm")}<span><span class="stat-label">${emblemHTML(player.color, player.emblem, "emblem-xs")} ${esc(player.leader)}</span>
      <span class="party-name">${esc(player.name)}</span></span></div>
    <div class="stat"><span class="stat-label">Date</span><span class="stat-value">${dateLabel(S.week)}</span></div>
    <div class="stat"><span class="stat-label">Election in</span><span class="stat-value">${S.result ? "Held" : `${monthsLeft} months`}</span></div>
    <div class="stat"><span class="stat-label">Campaign funds</span><span class="stat-value">₱${S.money.toFixed(1)}M</span></div>
    <div class="stat"><span class="stat-label">Trust in politics</span><span class="stat-value">${Math.round(S.trust)} ${trustLabel(S.trust).toLowerCase()}</span></div>
    <button class="stat stat-btn" id="stat-actions"><span class="stat-label">Actions left</span><span class="stat-value">${S.actionsLeft} of ${CONFIG.actionsPerMonth}${S.actionsLeft ? " →" : ""}</span></button>`;
  $("#stat-actions").addEventListener("click", () => { ui.tab = "actions"; renderTabs(); });
  const blocked = S.queue.length > 0 || !!S.result;
  $("#btn-sound").innerHTML = iconSVG(SFX.muted ? "volume-x" : "volume-2");
  $("#btn-sound").setAttribute("aria-label", SFX.muted ? "Turn sound on" : "Turn sound off");
  $("#btn-week").disabled = blocked;
  $("#btn-skip").disabled = blocked;
}

// ---------- Map ----------
function svgEl(tag, attrs, parent) {
  const el = document.createElementNS(SVG_NS, tag);
  for (const k in attrs) el.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(el);
  return el;
}
function buildMap() {
  const svg = $("#map");
  svg.innerHTML = "";
  for (const f of FOREIGN) {
    svgEl("polygon", { points: f.shape, class: "foreign" }, svg);
  }
  for (const r of REGIONS) {
    const poly = svgEl("polygon", { points: r.shape, class: "region", "data-id": r.id, tabindex: 0 }, svg);
    poly.addEventListener("click", () => selectRegion(r.id));
    poly.addEventListener("keydown", (e) => { if (e.key === "Enter") selectRegion(r.id); });
    poly.addEventListener("mousemove", (e) => showTip(e, r));
    poly.addEventListener("mouseleave", () => ($("#map-tip").hidden = true));
  }
  for (const f of FOREIGN) {
    if (f.flag && FLAGS[f.flag]) {
      // flag above the country name, or below it if there is no room at the top of the map
      const sc = f.small ? 1.1 : 2.2;
      const h = 40 * sc, lineH = f.small ? 38 : 62;
      let top = f.label[1] - (f.small ? 34 : 56) - h - 10;
      if (top < 12) top = f.label[1] + (f.name.length - 1) * lineH + 26;
      const g = svgEl("g", { transform: `translate(${f.label[0] - 30 * sc} ${top}) scale(${sc})`, class: "map-flag" }, svg);
      g.innerHTML = FLAGS[f.flag]() + `<rect width="60" height="40" fill="none" stroke="#26292b" stroke-width="2"/><title>${FLAG_INFO[f.flag].name}. ${FLAG_INFO[f.flag].note}</title>`;
    }
    f.name.forEach((line, i) => {
      const t = svgEl("text", { x: f.label[0], y: f.label[1] + i * (f.small ? 38 : 62), "text-anchor": "middle",
        class: f.small ? "label-small" : "label-foreign" }, svg);
      t.textContent = line;
    });
  }
  for (const r of REGIONS) {
    const t = svgEl("text", { x: r.label[0], y: r.label[1], "text-anchor": "middle", class: "label-region" }, svg);
    t.textContent = r.name;
    svgEl("text", { x: r.label[0], y: r.label[1] + 46, "text-anchor": "middle", class: "label-share", "data-share": r.id }, svg);
  }
  svgEl("circle", { cx: CAPITAL.x, cy: CAPITAL.y, r: 14, class: "capital" }, svg);
  const cap = svgEl("text", { x: CAPITAL.x + 24, y: CAPITAL.y + 40, class: "label-capital" }, svg);
  cap.textContent = CAPITAL.name;
}
function leaderOf(shares) {
  const ids = Object.keys(shares).sort((a, b) => shares[b] - shares[a]);
  return { id: ids[0], margin: shares[ids[0]] - shares[ids[1]] };
}
function updateMap() {
  const poll = latestPoll();
  for (const r of REGIONS) {
    const poly = document.querySelector(`.region[data-id="${r.id}"]`);
    const shares = poll && poll.regions[r.id];
    if (shares) {
      const lead = leaderOf(shares);
      const strength = Math.round(clamp(28 + lead.margin * 160, 28, 75));
      poly.style.fill = `color-mix(in srgb, ${partyById(lead.id).color} ${strength}%, var(--land))`;
      document.querySelector(`[data-share="${r.id}"]`).textContent = `You ${pct(shares.player, 0)}`;
    } else poly.style.fill = "var(--land)";
    poly.classList.toggle("selected", ui.kind === "region" && ui.group === r.id);
  }
  const legend = S.parties.map((p) => `<span class="party-chip"><span class="dot" style="background:${p.color}"></span>${esc(p.short)}</span>`).join("");
  $("#map-legend").innerHTML = `${legend}<span class="note">Regions are coloured by the leader in the ${poll ? esc(poll.label.toLowerCase()) : "latest poll"} (${poll ? dateLabel(poll.week, false) : "no poll yet"}). Click a region to see its voters.</span>`;
}
function showTip(e, r) {
  const tip = $("#map-tip");
  const poll = latestPoll();
  const shares = poll && poll.regions[r.id];
  const lead = shares ? leaderOf(shares) : null;
  tip.innerHTML = `<strong>${esc(r.name)}</strong> · ${r.adults}M adults<br><span class="muted">${esc(r.blurb)}</span>
    ${lead ? `<br>Leading: ${esc(partyById(lead.id).short)} · You: ${pct(shares.player)}` : ""}`;
  tip.hidden = false;
  const box = $(".map-panel").getBoundingClientRect();
  const x = e.clientX - box.left, y = e.clientY - box.top;
  tip.style.left = Math.min(x + 14, box.width - 250) + "px";
  tip.style.top = Math.max(y - 10, 8) + "px";
}
function selectRegion(id) {
  ui.tab = "electorate"; ui.kind = "region"; ui.group = id;
  render();
}

// ---------- Tabs ----------
function renderTabs() {
  document.querySelectorAll("#tabs button").forEach((b) => b.setAttribute("aria-selected", b.dataset.tab === ui.tab));
  const body = $("#tab-body");
  if (ui.tab === "electorate") body.innerHTML = electorateHTML();
  if (ui.tab === "platform") body.innerHTML = platformHTML();
  if (ui.tab === "polls") body.innerHTML = pollsHTML();
  if (ui.tab === "diary") body.innerHTML = diaryHTML();
  if (ui.tab === "actions") body.innerHTML = actionsHTML();
  if (ui.tab === "parties") body.innerHTML = partiesHTML();
}

function supportBars(support, previous, core) {
  const ids = Object.keys(support).sort((a, b) => support[b] - support[a]);
  const max = Math.max(...Object.values(support));
  return `<div class="bars">${ids.map((id) => {
    const p = partyById(id);
    const d = previous ? support[id] - previous[id] : null;
    const delta = d === null ? "" : `<span class="${d >= 0 ? "delta-up" : "delta-down"} small"> ${d >= 0 ? "+" : ""}${(d * 100).toFixed(1)}</span>`;
    return `<div class="bar-row ${p.isPlayer ? "you" : ""}" title="${esc(p.name)}${core ? ` · ${millions(core[id])} core supporters` : ""}">
      <span>${esc(p.short)}</span>
      <div class="bar-track"><div class="bar-fill" style="width:${(support[id] / max) * 100}%;background:${p.color}"></div></div>
      <span class="num">${pct(support[id])}${delta}</span></div>`;
  }).join("")}</div>`;
}

function leanLabel(value, axis) {
  const side = value < 0 ? axis.left : axis.right;
  const a = Math.abs(value);
  if (a > 45) return `Strongly ${side.toLowerCase()}`;
  if (a > 25) return side;
  return `Leans ${side.toLowerCase()}`;
}

function electorateHTML() {
  const kinds = groupKinds();
  const kind = kinds.find((k) => k.id === ui.kind) || kinds[0];
  let group = kind.groups.find((g) => g.id === ui.group);
  if (!group) { group = kind.groups[0]; ui.group = group.id; }
  const sizes = Object.fromEntries(kind.groups.map((g) => [g.id, summarize(S, popsMatching(S, g.who)).size]));
  const sum = summarize(S, popsMatching(S, group.who));
  const issues = AXES.map((a) => ({ a, s: sum.sal[a.id] })).sort((x, y) => y.s - x.s).slice(0, 3);
  const leans = AXES.map((a) => ({ a, v: sum.pos[a.id] })).filter((x) => Math.abs(x.v) > 12)
    .sort((x, y) => Math.abs(y.v) - Math.abs(x.v)).slice(0, 4);
  const poll = latestPoll();
  const entry = poll && poll.groups[`${kind.id}:${group.id}`];
  const prevPoll = S.polls[S.polls.length - 2];
  const prevEntry = prevPoll && prevPoll.groups[`${kind.id}:${group.id}`];
  const region = kind.id === "region" ? byId(REGIONS, group.id) : null;

  return `
  <div class="kinds">${kinds.map((k) => `<button data-kind="${k.id}" aria-pressed="${k.id === kind.id}">${esc(k.label)}</button>`).join("")}</div>
  <div class="electorate">
    <ul class="groups">${kind.groups.map((g) => `<li><button data-group="${g.id}" aria-pressed="${g.id === group.id}">
      <span>${esc(g.label)}</span><span class="size">${(sizes[g.id] / 1e6).toFixed(1)}M</span></button></li>`).join("")}</ul>
    <div class="detail">
      <div>
        <p class="eyebrow">${esc(kind.label)}</p>
        <h3>${esc(group.label)}</h3>
        <div class="big-number">${millions(sum.size)}</div>
        <span class="muted small">adult citizens${kind.id === "views" ? " (groups overlap)" : ""}</span>
        ${region ? `<p class="small" style="margin:8px 0 0">${esc(region.blurb)}</p>` : ""}
      </div>
      <div class="facts">
        <div><p class="eyebrow">Turnout</p><span class="stat-value">${pct(sum.turnout, 0)}</span></div>
        <div><p class="eyebrow">Know your party</p><span class="stat-value">${pct(sum.aware, 0)}</span></div>
        <div><p class="eyebrow">Your core supporters</p><span class="stat-value">${(entry ? entry.core.player / 1e3 : 0).toFixed(0)}k</span></div>
        <div><p class="eyebrow">View of ${esc(partyById("player").leader)}</p><span class="stat-value">${leaderWords(sum.leader)}</span></div>
        <div><p class="eyebrow">Fed up with the system</p><span class="stat-value">${sum.disaffection > 1.25 ? "Very" : sum.disaffection > 1.05 ? "Quite" : sum.disaffection > 0.85 ? "Somewhat" : "Hardly"}</span></div>
      </div>
      ${sum.leaderPull > 1.12 ? `<p class="callout">Looks for a strong, charismatic leader.</p>` : sum.leaderPull < 0.88 ? `<p class="callout">Hard to win over with personality alone.</p>` : ""}
      <div><p class="eyebrow">Cares most about</p><div class="chips">${issues.map((x) => `<span class="chip">${esc(x.a.issue)}</span>`).join("")}</div></div>
      <div><p class="eyebrow">Leanings</p>${leans.length ? leans.map((x) => `<div class="lean-row"><span>${esc(leanLabel(x.v, x.a))}</span><span class="num muted">${x.v > 0 ? "+" : ""}${x.v.toFixed(0)}</span></div>`).join("") : `<span class="muted small">No strong leanings. A swing group.</span>`}</div>
      <div>
        <p class="eyebrow">Vote intention · ${poll ? esc(poll.label) : "no poll yet"}</p>
        ${entry ? supportBars(entry.support, prevEntry && prevEntry.support, entry.core) : ""}
        <p class="muted small" style="margin:6px 0 0">Polls are taken every December. Hover a bar to see each party's core supporters.</p>
      </div>
    </div>
  </div>`;
}

function stanceTrack(ax, party) {
  const pos = (v) => `${(v + 100) / 2}%`;
  const ms = stanceOf(party.manifesto[ax.id]), ps = stanceOf(party.perceived[ax.id]);
  const cells = ax.stances.map((name, i) =>
    `<span class="band ${i === ms ? "band-manifesto" : ""} ${i === ps && i !== ms ? "band-off" : ""}" title="${esc(name)}"></span>`).join("");
  const others = S.parties.filter((p) => !p.isPlayer).map((p) =>
    `<span class="mark mark-party" style="left:${pos(p.perceived[ax.id])};background:${p.color}" title="${esc(p.short)}: ${esc(ax.stances[stanceOf(p.perceived[ax.id])])}"></span>`).join("");
  const off = Math.abs(ps - ms);
  return `<div class="axis">
    <div class="axis-labels"><span>${esc(ax.left)}</span><span>${esc(ax.right)}</span></div>
    <div class="bands">${cells}${others}
      <span class="mark mark-perceived" style="left:${pos(party.perceived[ax.id])}" title="How voters see you: ${party.perceived[ax.id]}"></span></div>
    <div class="axis-status ${off ? "warn" : ""}">${off
      ? `Seen as <strong>${esc(ax.stances[ps])}</strong>, manifesto says ${esc(ax.stances[ms])}${off > 1 ? " · serious" : ""}`
      : `<strong>${esc(ax.stances[ps])}</strong>, as promised`}</div>
  </div>`;
}

function consistencyState(v) {
  if (v < 0.5) return ["Consistent", "Voters believe you mean what you say."];
  if (v < 2) return ["Wobbling", "A few voters have noticed you changing your tune."];
  if (v < 5) return ["Unreliable", "Your core supporters are leaving, and engaged voters punish you."];
  return ["Flip-flopper", "Nobody knows what you stand for. Your base is collapsing."];
}

function platformHTML() {
  const player = partyById("player");
  const inc = inconsistencyOf(S, player);
  const [label, explain] = consistencyState(inc);
  const nation = summarize(S, S.pops);
  const recent = S.flips.filter((f) => f.party === "player" && S.week - f.week < CONFIG.flipMemoryWeeks).reverse();
  return `
    <div class="cards">
      <div class="card">
        <div class="leader-head">${portraitHTML(player, "portrait-lg")}<div><p class="eyebrow">Your leader</p>
        <h3>${esc(player.leader)}</h3><span class="small muted">${emblemHTML(player.color, player.emblem, "emblem-xs")} ${esc(player.name)}</span></div></div>
        <div class="facts">
          <div><p class="eyebrow">Charisma</p><span class="stat-value">${player.charisma.toFixed(0)}</span></div>
          <div><p class="eyebrow">Personal image</p><span class="stat-value">${leaderScore(nation.leader)}</span></div>
          <div><p class="eyebrow">Devotion among your voters</p><span class="stat-value">${pct(nation.devotion, 0)}</span></div>
          <div><p class="eyebrow">Would follow you anywhere</p><span class="stat-value">${nation.followers >= 1e6 ? (nation.followers / 1e6).toFixed(2) + "M" : Math.round(nation.followers / 1000) + "k"}</span></div>
        </div>
        <span class="small muted">Only voters who are very attached to ${esc(player.leader)} become devoted, and devotion is partial. Devoted voters care less about your positions and forgive flip-flops. The fully devoted slowly adopt your views as their own. Changing your positions still costs you everyone else.</span>
      </div>
      <div class="card">
        <p class="eyebrow">Consistency</p>
        <div><span class="big-number">${inc.toFixed(1)}</span> <strong>${label}</strong></div>
        <div class="drift-meter"><span class="drift-needle" style="left:${clamp(inc / 8, 0, 1) * 100}%"></span></div>
        <span class="small muted">${explain} Only the distance between your manifesto and where voters see you now counts. Moving inside a stance is free; one stance away costs a little, two costs a lot. Drift back to your manifesto and the penalty goes away.</span>
        ${recent.length ? `<ul class="flips">${recent.slice(0, 5).map((f) => `<li><span class="when">${dateLabel(f.week, false)}</span> ${esc(stanceName(f.axis, f.from))} → ${esc(stanceName(f.axis, f.to))}</li>`).join("")}</ul>` : `<span class="small muted">No stance changes yet.</span>`}
      </div>
    </div>
    <div class="legend-inline" style="margin-top:14px">
      <span><span class="band-key band-manifesto"></span>Manifesto stance</span>
      <span><span class="mark mark-perceived"></span>How voters see you</span>
      ${S.parties.filter((p) => !p.isPlayer).map((p) => `<span><span class="mark mark-party" style="background:${p.color}"></span>${esc(p.short)}</span>`).join("")}
    </div>
    <div class="axes">${AXES.map((ax) => stanceTrack(ax, player)).join("")}</div>`;
}

function leaderWords(v) {
  if (v > 0.6) return "Adored";
  if (v > 0.3) return "Popular";
  if (v > 0.1) return "Liked";
  if (v > -0.1) return "No opinion";
  if (v > -0.3) return "Disliked";
  return "Despised";
}
// Leader image as a number from -100 to +100, plus its word.
function leaderScore(v) { const n = Math.round(v * 100); return `${n > 0 ? "+" : ""}${n} ${leaderWords(v)}`; }

function pollsHTML() {
  if (!S.polls.length) return `<p class="muted">No polls yet.</p>`;
  const poll = latestPoll();
  const prev = S.polls[S.polls.length - 2];
  const W = 460, H = 200, pad = { l: 34, r: 12, t: 10, b: 24 };
  const n = S.polls.length;
  const maxV = Math.max(0.4, ...S.polls.flatMap((p) => Object.values(p.national)));
  const x = (i) => pad.l + (n === 1 ? (W - pad.l - pad.r) / 2 : (i / (n - 1)) * (W - pad.l - pad.r));
  const y = (v) => pad.t + (1 - v / maxV) * (H - pad.t - pad.b);
  const ticks = [0, 0.1, 0.2, 0.3, 0.4].filter((t) => t <= maxV);
  const lines = S.parties.map((p) => {
    const pts = S.polls.map((pl, i) => `${x(i)},${y(pl.national[p.id])}`).join(" ");
    const last = S.polls[n - 1].national[p.id];
    return `<polyline points="${pts}" fill="none" stroke="${p.color}" stroke-width="${p.isPlayer ? 3.5 : 2}" stroke-linejoin="round"/>
      <circle cx="${x(n - 1)}" cy="${y(last)}" r="${p.isPlayer ? 5 : 3.5}" fill="${p.color}"/>`;
  }).join("");
  const nextPollYear = calendar(S.week).year;
  return `
    <p class="eyebrow">National vote intention · ${esc(poll.label)} · ${dateLabel(poll.week, false)}</p>
    ${supportBars(poll.national, prev && prev.national)}
    <p class="muted small">Expected turnout ${pct(poll.turnout, 0)}. Margin of error about ±${(CONFIG.pollError * 200).toFixed(1)} points.</p>
    <p class="eyebrow" style="margin-top:18px">Poll history</p>
    <div class="chart-wrap"><svg class="chart" viewBox="0 0 ${W} ${H}" width="100%" style="min-width:320px">
      ${ticks.map((t) => `<line class="grid" x1="${pad.l}" x2="${W - pad.r}" y1="${y(t)}" y2="${y(t)}"/><text x="${pad.l - 6}" y="${y(t) + 4}" text-anchor="end">${t * 100}%</text>`).join("")}
      ${S.polls.map((p, i) => `<text x="${x(i)}" y="${H - 6}" text-anchor="middle">${p.label.startsWith("Opening") ? "Start" : calendar(p.week).year}</text>`).join("")}
      ${lines}
    </svg></div>
    ${S.result ? "" : `<p class="muted small">Next poll: December ${nextPollYear}.</p>`}`;
}

function diaryHTML() {
  if (!S.log.length) return `<p class="muted">Nothing has happened yet.</p>`;
  return `<ul class="diary">${[...S.log].reverse().map((e) => `<li><span class="when">${dateLabel(e.week, false)}</span><span>${esc(e.text)}</span></li>`).join("")}</ul>`;
}

// ---------- Modal sheets (start, events, budget, polls, election) ----------
function openSheet(html) { $("#sheet").innerHTML = html; $("#modal").hidden = false; }
function closeSheet() { $("#modal").hidden = true; $("#sheet").innerHTML = ""; }

function renderModal() {
  const front = S.queue[0];
  if (!front) { closeSheet(); ui.lastFront = null; return; }
  if (front !== ui.lastFront) {
    ui.lastFront = front;
    const sound = { news: "paper", event: "stamp", poll: "poll", budget: "click",
      election: S.result && S.result.playerWon ? "win" : "lose" }[front.type];
    setTimeout(() => SFX.play(sound), 60);
  }
  if (front.type === "news") newsSheet(front);
  if (front.type === "event") eventSheet(front);
  if (front.type === "budget") budgetSheet(front);
  if (front.type === "poll") pollSheet(front);
  if (front.type === "election") electionSheet();
}

// ---------- Portraits and emblems ----------
// Portraits are drawn by portraits.js; the same leader always gets the same face.
const portraitCache = new Map();
function portraitSVG(seed, sex, age, pin) {
  const key = `${seed}|${sex}|${age}|${pin}`;
  if (!portraitCache.has(key)) portraitCache.set(key, Portraits.drawPortrait({ seed, sex, age, pin }));
  return portraitCache.get(key);
}
function portraitHTML(party, cls = "") {
  const svg = portraitSVG(party.portraitSeed || party.leader, party.leaderSex || "m", party.leaderAge || 60, party.color);
  return `<span class="portrait ${cls}" style="--pc:${party.color}" role="img" aria-label="${esc(party.leader)}">${svg}</span>`;
}
function choicePortrait(n, color) {
  const p = PLAYER_PORTRAITS[n - 1] || PLAYER_PORTRAITS[0];
  return portraitSVG(p.seed, p.sex, p.age, color);
}
function iconSVG(name, cls = "") {
  return `<svg class="icon ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ICONS.star}</svg>`;
}
function emblemHTML(color, emblem, cls = "") {
  return `<span class="emblem ${cls}" style="--pc:${color}">${iconSVG(emblem)}</span>`;
}

// ---------- Title screen ----------
function titleMapSVG() {
  const foreign = FOREIGN.map((f) => `<polygon points="${f.shape}" class="t-foreign"/>`).join("");
  const regions = REGIONS.map((r, i) => `<polygon points="${r.shape}" class="t-region" style="animation-delay:${i * 0.12}s"/>`).join("");
  return `<svg class="title-map" viewBox="0 0 2296 1623" aria-hidden="true">${foreign}${regions}
    <circle cx="${CAPITAL.x}" cy="${CAPITAL.y}" r="18" class="t-capital"/></svg>`;
}
function renderTitle() {
  closeSheet();
  $("#toast").hidden = true;
  const saved = loadSave();
  const canContinue = saved && !saved.result && saved.version === 6;
  const el = $("#title");
  el.hidden = false;
  el.innerHTML = `
    ${titleMapSVG()}
    <div class="title-inner">
      <p class="title-kicker">${flagSVG("cranebonistan", "flag flag-sm")} The Republic of Cranebonistan · ${CONFIG.startYear}</p>
      <h1 class="title-name">Cranebonistan</h1>
      <p class="title-tag">Five years. One election. Say whatever it takes.</p>
      <div class="title-menu">
        <button class="btn btn-primary btn-big" id="t-new">${iconSVG("flag")} New campaign</button>
        ${canContinue ? `<button class="btn btn-big" id="t-continue">Continue · ${esc(saved.parties.find((p) => p.isPlayer).name)}, ${dateLabel(saved.week, false)}</button>` : ""}
        <button class="btn btn-big" id="t-how">How to play</button>
      </div>
      <div class="title-foot">
        <button class="btn btn-small" id="t-sound">${iconSVG(SFX.muted ? "volume-x" : "volume-2")} Sound ${SFX.muted ? "off" : "on"}</button>
        <button class="link-btn" id="t-credits">Credits</button>
      </div>
    </div>`;
  $("#t-new").addEventListener("click", () => { SFX.play("open"); ui.create = { step: "pick" }; el.hidden = true; renderCreate(); });
  if (canContinue) $("#t-continue").addEventListener("click", () => { SFX.play("open"); S = saved; el.hidden = true; render(); });
  $("#t-how").addEventListener("click", howToPlay);
  $("#t-credits").addEventListener("click", creditsSheet);
  $("#t-sound").addEventListener("click", () => { SFX.toggle(); renderTitle(); });
}
function howToPlay() {
  openSheet(`
    <span class="stamp">How to play</span>
    <h2>Become the largest party in five years</h2>
    <ul class="howto">
      <li><strong>Write a manifesto.</strong> One stance on each of eight issues. Drifting away from it costs you trust and core voters.</li>
      <li><strong>React to events.</strong> Every month a crisis, scandal or opportunity arrives. Each answer says who it appeals to and who it angers.</li>
      <li><strong>Take actions.</strong> Two a month: campaign on your issues, organise locally, dig up dirt on rivals, poach defectors or provoke outrage.</li>
      <li><strong>Spend your money.</strong> Every quarter: rallies in each region, social media, TV and your leader's national tour.</li>
      <li><strong>Watch your rivals.</strong> Parties in crisis can split apart and leave their voters up for grabs.</li>
      <li><strong>Read the polls.</strong> Every December. Click a region on the map or use the Electorate tab to see who likes you.</li>
    </ul>
    <div class="sheet-actions"><button class="btn btn-primary" id="btn-close">Got it</button></div>`);
  $("#btn-close").addEventListener("click", closeSheet);
}
function creditsSheet() {
  openSheet(`
    <span class="stamp">Credits</span>
    <h2>Credits</h2>
    <ul class="howto">
      <li><strong>Portraits, flags and event illustrations:</strong> original artwork drawn in code for this game.</li>
      <li><strong>Icons:</strong> Lucide, ISC License.</li>
      <li><strong>Fonts:</strong> Bricolage Grotesque and IBM Plex, SIL Open Font License, via Google Fonts.</li>
      <li><strong>Sound:</strong> synthesised in the browser; no recordings used.</li>
      <li><strong>Map, setting and design:</strong> Ugur Ozan Denizgünü.</li>
    </ul>
    <div class="sheet-actions"><button class="btn btn-primary" id="btn-close">Close</button></div>`);
  $("#btn-close").addEventListener("click", closeSheet);
}

// ---------- Party creation ----------
function renderCreate() {
  const c = ui.create;
  if (c.step === "pick") {
    openSheet(`
      <span class="stamp">Step 1 of 2 · Choose your movement</span>
      <h2>What kind of party are you founding?</h2>
      <p class="lede">Pick a starting point. You can rename it and change every stance on the next screen.</p>
      <div class="templates">${PARTY_TEMPLATES.map((t) => `
        <button class="template" data-template="${t.id}" style="--pc:${t.color}">
          <span class="template-top">${emblemHTML(t.color, t.emblem)}<span><strong>${esc(t.name || "Your own party")}</strong><span class="template-tag">${esc(t.tagline)}</span></span></span>
          <span class="template-pitch">${esc(t.pitch)}</span>
          <span class="template-targets"><span class="eyebrow">Aims at</span> ${esc(t.targets)}</span>
        </button>`).join("")}</div>
      <div class="sheet-actions"><button class="btn" id="btn-back">Back to title</button></div>`);
    document.querySelectorAll("[data-template]").forEach((b) => b.addEventListener("click", () => {
      const t = PARTY_TEMPLATES.find((x) => x.id === b.dataset.template);
      ui.create = { step: "details", template: t.id, name: t.name || "", leader: t.leader || "", portrait: t.portrait,
        color: t.color, emblem: t.emblem, manifesto: { ...t.manifesto } };
      renderCreate();
      $("#modal").scrollTop = 0;
    }));
    $("#btn-back").addEventListener("click", renderTitle);
    return;
  }
  const keepScroll = (fn) => { const sc = $("#modal").scrollTop; fn(); renderCreate(); $("#modal").scrollTop = sc; };
  openSheet(`
    <span class="stamp">Step 2 of 2 · Your party</span>
    <div class="create-hero" style="--pc:${c.color}">
      <span class="portrait portrait-xl" style="--pc:${c.color}">${choicePortrait(c.portrait, c.color)}</span>
      <div class="create-names">
        ${emblemHTML(c.color, c.emblem, "emblem-lg")}
        <label class="field">Party name <input type="text" id="party-name" maxlength="40" value="${esc(c.name)}" placeholder="Name your party"></label>
        <label class="field">Party leader <input type="text" id="leader-name" maxlength="40" value="${esc(c.leader)}" placeholder="Your leader's name"></label>
      </div>
    </div>
    <div class="pickers">
      <div><p class="eyebrow">Leader's portrait</p><div class="portrait-pick">${PLAYER_PORTRAITS.map((_, i) => i + 1).map((n) => `
        <button class="portrait-opt" data-portrait="${n}" aria-pressed="${c.portrait === n}" aria-label="Portrait ${n}" style="--pc:${c.color}">${choicePortrait(n, c.color)}</button>`).join("")}</div></div>
      <div class="pick-row">
        <div><p class="eyebrow">Colour</p><div class="swatches">${PLAYER_COLORS.map((col) => `<button class="swatch" data-color="${col}" style="background:${col}" aria-pressed="${c.color === col}" aria-label="Colour ${col}"></button>`).join("")}</div></div>
        <div><p class="eyebrow">Emblem</p><div class="emblem-pick">${PLAYER_EMBLEMS.map((e) => `<button class="emblem-opt" data-emblem="${e}" aria-pressed="${c.emblem === e}" aria-label="${e}">${iconSVG(e)}</button>`).join("")}</div></div>
      </div>
    </div>
    <p class="eyebrow" style="margin:6px 0 0">Manifesto</p>
    <div class="legend-inline">${PARTIES.filter((p) => !p.isPlayer).map((p) => `<span><span class="mark mark-party" style="background:${p.color}"></span>${esc(p.name)}</span>`).join("")}</div>
    <div class="axes" style="margin-top:0">${AXES.map((a) => `
      <fieldset class="stance-pick">
        <legend>${esc(a.issue)}</legend>
        <div class="segments">${a.stances.map((name, i) => {
          const here = PARTIES.filter((p) => !p.isPlayer && stanceOf(p.manifesto[a.id] || 0) === i);
          return `<button type="button" data-axis="${a.id}" data-stance="${i}" aria-pressed="${c.manifesto[a.id] === i}" style="--pc:${c.color}">
            <span>${esc(name)}</span><span class="seg-dots">${here.map((p) => `<span class="dot" style="background:${p.color}" title="${esc(p.short)}"></span>`).join("")}</span></button>`;
        }).join("")}</div>
      </fieldset>`).join("")}</div>
    <div class="sheet-actions">
      <button class="btn" id="btn-back">Back</button>
      <button class="btn btn-primary" id="btn-start">Start the campaign</button>
    </div>`);
  $("#party-name").addEventListener("input", (e) => (c.name = e.target.value));
  $("#leader-name").addEventListener("input", (e) => (c.leader = e.target.value));
  document.querySelectorAll("[data-portrait]").forEach((b) => b.addEventListener("click", () => keepScroll(() => (c.portrait = +b.dataset.portrait))));
  document.querySelectorAll("[data-color]").forEach((b) => b.addEventListener("click", () => keepScroll(() => (c.color = b.dataset.color))));
  document.querySelectorAll("[data-emblem]").forEach((b) => b.addEventListener("click", () => keepScroll(() => (c.emblem = b.dataset.emblem))));
  document.querySelectorAll("[data-stance]").forEach((b) => b.addEventListener("click", () => keepScroll(() => (c.manifesto[b.dataset.axis] = +b.dataset.stance))));
  $("#btn-back").addEventListener("click", () => { ui.create = { step: "pick" }; renderCreate(); });
  $("#btn-start").addEventListener("click", () => {
    S = newGame({ partyName: c.name.trim() || "New Dawn Movement", leaderName: c.leader.trim() || "Dorin Vask",
      manifesto: c.manifesto, color: c.color, emblem: c.emblem, portrait: c.portrait });
    ui.create = null; SFX.play("open"); save(); render();
  });
}

function groupList(list) {
  return list.map((g) => `<span class="grp">${esc(g.text)} <span class="muted">${(g.size / 1e6).toFixed(1)}M${g.strength ? ", " + g.strength : ""}</span></span>`).join("");
}
function eventSheet(front) {
  const ev = eventOf(front);
  const kindLabel = { crisis: "Crisis", opportunity: "Opportunity", trap: "Tricky moment", scandal: "Scandal", regional: "Regional issue", foreign: "Foreign affairs", followup: "Consequences" }[ev.kind] || "Event";
  openSheet(`
    <div class="art-wrap">${ART.eventArt(ev)}</div>
    <span class="stamp">${kindLabel} · ${dateLabel(S.week, false)}</span>
    <h2>${esc(ev.title)}</h2>
    <p class="lede">${esc(ev.text)}</p>
    <p class="eyebrow">How do you respond?</p>
    <div class="choices">${ev.choices.map((c, i) => {
      const d = describeChoice(S, c.effects);
      const stanceLines = d.stances.filter((s) => s.from !== s.to).map((s) => {
        const toward = s.to === s.manifesto ? "back to your manifesto" : Math.abs(s.to - s.manifesto) > Math.abs(s.from - s.manifesto) ? "away from your manifesto" : "";
        return `<span class="tag ${toward.startsWith("away") ? "tag-warn" : "tag-good"}">Stance change: ${esc(stanceName(s.axis, s.from))} → ${esc(stanceName(s.axis, s.to))}${toward ? ` (${toward})` : ""}</span>`;
      });
      const nudges = d.stances.filter((s) => s.from === s.to).map((s) => byId(AXES, s.axis)).map((a) => a.issue.toLowerCase());
      return `<button class="choice" data-choice="${i}">
        <strong>${esc(c.label)}</strong>
        ${d.appeals.length ? `<div class="effect-line"><span class="lbl lbl-good">Appeals to</span>${groupList(d.appeals)}</div>` : ""}
        ${d.angers.length ? `<div class="effect-line"><span class="lbl lbl-bad">Angers</span>${groupList(d.angers)}</div>` : ""}
        ${stanceLines.length || d.tags.length || nudges.length ? `<div class="tags">${stanceLines.join("")}${d.tags.map((t) => `<span class="tag">${esc(t)}</span>`).join("")}${nudges.length ? `<span class="tag tag-quiet">Nudges your image on ${esc(nudges.join(", "))}</span>` : ""}</div>` : ""}
      </button>`;
    }).join("")}</div>`);
  document.querySelectorAll("[data-choice]").forEach((b) => b.addEventListener("click", () => {
    const res = resolveEvent(S, +b.dataset.choice);
    SFX.play(res.flips.length ? "bad" : "click");
    toast((res.flips.length
      ? `Stance changed: ${res.flips.map((f) => `${stanceName(f.axis, f.from)} → ${stanceName(f.axis, f.to)}`).join(", ")}.`
      : "Your stances held.") + res.extra);
    save(); render();
  }));
}

function budgetSheet(front) {
  if (!ui.budget) {
    ui.budget = Object.fromEntries(BUDGET_KEYS.map((k) => [k, 0]));
    ui.offers = [];
    if (S.lastBudget) applyLastBudget();
  }
  const offerMoney = ui.offers.reduce((a, id) => a + (byId(FUNDING_OFFERS, id).effects.money || 0), 0);
  const available = S.money + offerMoney;
  const spent = Object.values(ui.budget).reduce((a, b) => a + b, 0);
  const left = available - spent;
  const c = calendar(S.week);
  const preview = previewBudget(S, ui.budget);
  const known = (row) => `<span class="known">Know you: ${pct(row.before)}${row.after - row.before > 0.0005 ? ` → <strong>${pct(row.after)}</strong>` : ""}</span>`;
  const rows = [
    ...REGIONS.map((r) => ({ id: r.id, label: `Rallies in ${r.name}`, note: `${r.adults}M adults. Awareness and goodwill there, a little leader image.`, info: known(preview[r.id]) })),
    { id: "social", label: "Social media", note: "Cheap reach to voters under 46. The reaction is unpredictable.", info: known(preview.young) },
    { id: "tv", label: "TV and newspapers", note: "Reaches voters over 45 across the country.", info: known(preview.old) },
    { id: "tour", label: `${partyById("player").leader}'s national tour`, note: "Builds the leader as a person. Strongest with the young, the working class and Fauraifai.",
      info: `<span class="known">Leader image: ${leaderScore(preview.all.leaderBefore)}${preview.all.leaderAfter - preview.all.leaderBefore > 0.005 ? ` → <strong>${leaderScore(preview.all.leaderAfter)}</strong>` : ""}</span>` },
  ];
  const offers = (front.offers || []).map((id) => byId(FUNDING_OFFERS, id));
  openSheet(`
    <span class="stamp">Quarterly budget · Q${Math.floor(c.monthIndex / 3) + 1} ${c.year}</span>
    <h2>Where does the money go?</h2>
    <p class="lede">You received ₱${CONFIG.quarterIncome}M this quarter. Nationally, ${pct(preview.all.before, 0)} of adults know your party. Whatever you don't spend is saved. Spending in the same place has diminishing returns.</p>
    ${offers.length ? `<div class="offers"><p class="eyebrow">Money on the table</p>${offers.map((o) => `
      <label class="donor ${o.effects.scandal ? "donor-dirty" : ""}"><input type="checkbox" data-offer="${o.id}" ${ui.offers.includes(o.id) ? "checked" : ""}>
        <span><strong>${esc(o.title)}</strong><br><span class="small muted">${esc(o.note)}</span>
        ${o.effects.shift ? `<br><span class="small">Image: ${previewShift(S, o.effects.shift).map((s) => s.from !== s.to ? `${esc(stanceName(s.axis, s.from))} → ${esc(stanceName(s.axis, s.to))}` : `nudged on ${esc(byId(AXES, s.axis).issue.toLowerCase())}`).join(", ")}</span>` : ""}</span></label>`).join("")}</div>` : ""}
    <div class="budget-tools">
      <button class="btn btn-small" id="btn-same" ${S.lastBudget ? "" : "disabled"}>Same as last quarter</button>
      <button class="btn btn-small" id="btn-clear">Clear</button>
    </div>
    <div class="budget">${rows.map((r) => `
      <div class="budget-row"><div><strong>${esc(r.label)}</strong><br><span class="small muted">${esc(r.note)}</span><br>${r.info}</div>
        <div class="stepper"><button data-step="${r.id}" data-d="-0.5" aria-label="Less for ${esc(r.label)}">−</button>
          <span class="num">₱${ui.budget[r.id].toFixed(1)}M</span>
          <button data-step="${r.id}" data-d="0.5" aria-label="More for ${esc(r.label)}">+</button></div></div>`).join("")}</div>
    <div class="sheet-actions" style="justify-content:space-between;align-items:center">
      <span>Unspent: <span class="money-left">₱${left.toFixed(1)}M</span></span>
      <button class="btn btn-primary" id="btn-budget">Confirm spending</button>
    </div>`);
  const keepScroll = (fn) => () => { const sc = $("#modal").scrollTop; fn(); budgetSheet(front); $("#modal").scrollTop = sc; };
  document.querySelectorAll("[data-offer]").forEach((cb) => cb.addEventListener("change", keepScroll(() => {
    ui.offers = cb.checked ? [...ui.offers, cb.dataset.offer] : ui.offers.filter((x) => x !== cb.dataset.offer);
    trimBudget();
  })));
  document.querySelectorAll("[data-step]").forEach((b) => b.addEventListener("click", keepScroll(() => {
    const k = b.dataset.step, d = +b.dataset.d;
    if (d > 0 && left < d - 1e-9) return;
    ui.budget[k] = Math.max(0, ui.budget[k] + d);
  })));
  $("#btn-same").addEventListener("click", keepScroll(applyLastBudget));
  $("#btn-clear").addEventListener("click", keepScroll(() => { for (const k in ui.budget) ui.budget[k] = 0; }));
  $("#btn-budget").addEventListener("click", () => {
    const before = previewBudget(S, {});
    const res = resolveBudget(S, ui.budget, ui.offers);
    SFX.play("coins");
    const after = previewBudget(S, {});
    ui.budget = null; ui.offers = [];
    const gains = REGIONS.map((r) => ({ r, d: after[r.id].before - before[r.id].before })).filter((x) => x.d > 0.004)
      .sort((a, b) => b.d - a.d).slice(0, 3).map((x) => `${x.r.name} +${(x.d * 100).toFixed(0)}`);
    let msg = `Spent ₱${res.spent.toFixed(1)}M. Awareness ${pct(before.all.before)} → ${pct(after.all.before)}`;
    if (gains.length) msg += ` (${gains.join(", ")})`;
    if (res.socialSwing) msg += res.socialSwing > 0 ? ". Your social media posts went down well." : ". Your social media posts backfired.";
    toast(msg + ".");
    save(); render();
  });
}
function availableForBudget() {
  return S.money + (ui.offers || []).reduce((a, id) => a + (byId(FUNDING_OFFERS, id).effects.money || 0), 0);
}
// Fill the budget with last quarter's choices, scaled down if there is less money now.
function applyLastBudget() {
  if (!S.lastBudget) return;
  const total = Object.values(S.lastBudget).reduce((a, b) => a + b, 0);
  const scale = total > availableForBudget() ? availableForBudget() / total : 1;
  for (const k of BUDGET_KEYS) ui.budget[k] = Math.floor(((S.lastBudget[k] || 0) * scale) * 2) / 2;
}
// If declining an offer leaves you overspent, trim from the end.
function trimBudget() {
  let over = Object.values(ui.budget).reduce((a, b) => a + b, 0) - availableForBudget();
  for (const k of [...BUDGET_KEYS].reverse()) {
    if (over <= 0) break;
    const cut = Math.min(over, ui.budget[k]);
    ui.budget[k] -= cut; over -= cut;
  }
}

function pollSheet(front) {
  const poll = S.polls[front.index];
  const prev = S.polls[front.index - 1];
  const rank = Object.keys(poll.national).sort((a, b) => poll.national[b] - poll.national[a]).indexOf("player") + 1;
  openSheet(`
    <span class="stamp">${esc(poll.label)} · ${dateLabel(poll.week, false)}</span>
    <h2>${front.index === 0 ? "Where Cranebonistan stands" : rank === 1 ? "You lead the polls" : `You are ${["", "first", "second", "third", "fourth", "fifth"][rank]} in the polls`}</h2>
    <p class="lede">${front.index === 0 ? "Almost nobody has heard of your party yet. The map and the Electorate tab now show this poll's numbers." : "The map and the Electorate tab now show this poll's numbers, including how many core supporters each party has."}</p>
    ${supportBars(poll.national, prev && prev.national)}
    <div class="sheet-actions"><button class="btn btn-primary" id="btn-ok">Continue</button></div>`);
  $("#btn-ok").addEventListener("click", () => { dismissFront(S); save(); render(); });
}

function electionSheet() {
  const r = S.result;
  const winner = partyById(r.ranking[0]);
  const title = r.playerWon ? (r.majority ? "A majority. Cranebonistan is yours." : "You are the largest party in the Assembly.") : `${winner.name} wins the election.`;
  openSheet(`
    <span class="stamp">General election · ${dateLabel(S.week, false)}</span>
    <div class="winner">${portraitHTML(winner, "portrait-xl")}<h2>${esc(title)}</h2></div>
    <p class="lede">${r.playerWon ? "Governing, coalitions and keeping your promises come in a later version of the game." : "Look at the Electorate tab to see which groups you never reached."}</p>
    <div class="seatbar">${r.ranking.map((id) => `<div style="width:${(r.seats.national[id] / CONFIG.seats) * 100}%;background:${partyById(id).color}" title="${esc(partyById(id).short)}"></div>`).join("")}</div>
    <table class="results"><thead><tr><th>Party</th><th class="num">Votes</th><th class="num">Seats</th></tr></thead><tbody>
      ${r.ranking.map((id) => `<tr><td><span class="party-chip"><span class="dot" style="background:${partyById(id).color}"></span>${esc(partyById(id).name)}</span></td>
        <td class="num">${pct(r.votes[id])}</td><td class="num">${r.seats.national[id]}</td></tr>`).join("")}
    </tbody></table>
    <p class="muted small">${CONFIG.seats} seats, ${Math.floor(CONFIG.seats / 2) + 1} for a majority. Seats are shared out region by region.</p>
    <div class="sheet-actions">
      <button class="btn" id="btn-view">Look at the map</button>
      <button class="btn btn-primary" id="btn-new">Start a new game</button>
    </div>`);
  $("#btn-view").addEventListener("click", closeSheet);
  $("#btn-new").addEventListener("click", () => { clearSave(); S = null; ui.create = null; render(); });
}

// ---------- Actions tab ----------
function actionsHTML() {
  const left = S.actionsLeft;
  const blocked = S.queue.length > 0 || !!S.result;
  const dis = (cost = 0) => (blocked || left <= 0 || S.money < cost ? "disabled" : "");
  const sel = ui.champ;
  const table = ownershipTable(S);
  const ownerOf = (key) => (table.find((r) => r.key === key) || { owners: [] }).owners;
  const claimCell = (ax, side) => {
    const key = sideKey(ax.id, side);
    const owners = ownerOf(key);
    const top = owners[0];
    const mine = ownershipOf(S, "player", key);
    const isSel = sel && sel.axis === ax.id && sel.side === side;
    const yours = manifestoSide(S, ax.id) === side;
    const sig = S.signature.includes(key);
    return `<button class="claim ${isSel ? "is-sel" : ""} ${yours ? "is-yours" : "not-yours"} ${sig ? "is-sig" : ""}" data-claim="${ax.id}" data-side="${side}" aria-pressed="${isSel}" title="${yours ? "Your manifesto's side" : "Not your manifesto's side"}">
      <span class="claim-label">${sig ? "★ " : ""}${esc(side === "L" ? ax.left : ax.right)}</span>
      <span class="claim-owner">${top ? `<span class="dot" style="background:${partyById(top.party).color}"></span>${esc(partyById(top.party).short)} ${Math.round(top.value * 100)}` : `<span class="muted">Unclaimed</span>`}
      ${mine >= 0.02 && (!top || top.party !== "player") ? ` · you ${Math.round(mine * 100)}` : ""}</span></button>`;
  };
  let preview = "";
  if (sel) {
    const ax = byId(AXES, sel.axis);
    const pv = championPreview(S, sel.axis, sel.side);
    const st = pv.shift;
    const sideName = (sel.side === "L" ? ax.left : ax.right).toLowerCase();
    preview = pv.block ? `<div class="act-preview"><span class="tag tag-warn">${esc(pv.block)}</span></div>` : `<div class="act-preview">
      <span>Single-issue voters on this side right now: <strong>${(pv.single / 1e6).toFixed(2)}M</strong>${pv.heat > 0.45 ? " (it's in the news)" : ""}</span>
      <span>Claim gain <strong>+${Math.round(pv.gain * 100)}</strong>${pv.heat > 0.25 ? " (reduced: everyone is already talking about it)" : " (cheap: nobody is talking about it yet)"}</span>
      ${st.from !== st.to ? `<span class="tag tag-warn">Stance change: ${esc(stanceName(ax.id, st.from))} → ${esc(stanceName(ax.id, st.to))}</span>` : `<span class="tag tag-quiet">Your ${esc(ax.issue.toLowerCase())} stance holds</span>`}
      <button class="btn btn-primary btn-small" data-act="champion" ${dis()}>Champion ${esc(sideName)}</button></div>`;
  }
  const rv = rivals(S);
  return `
    <div class="act-head">
      <div><p class="eyebrow">Actions this month</p><span class="big-number">${left}</span> <span class="muted">of ${CONFIG.actionsPerMonth} left · refills at the start of each month</span></div>
      <div><p class="eyebrow">Funds</p><span class="stat-value">₱${S.money.toFixed(1)}M</span></div>
    </div>
    ${blocked && !S.result ? `<p class="callout">Finish the decision on screen first.</p>` : ""}

    <section class="act">
      <h4>${ACTIONS.champion.label} <span class="cost">Free</span></h4>
      <p class="small muted">${esc(ACTIONS.champion.help)} Numbers show the strongest claim on each side, out of 100. Your manifesto's sides are outlined.</p>
      <div class="sig-list"><span class="eyebrow">Your issues (${S.signature.length} of ${CONFIG.maxSignatureIssues})</span>
        ${S.signature.length ? S.signature.map((k) => `<span class="chip">★ ${esc(sideLabel(k))} · claim ${Math.round(ownershipOf(S, "player", k) * 100)}
          <button class="link-btn" data-drop="${k}" ${blocked ? "disabled" : ""}>drop</button></span>`).join("") : `<span class="small muted">None yet</span>`}</div>
      <div class="claims">${AXES.map((ax) => {
        const heat = S.salMod[ax.id] || 0;
        return `<div class="claim-row"><span class="claim-issue">${esc(ax.issue)}${heat > 0.45 ? ` <span class="hot">Hot</span>` : ""}</span>${claimCell(ax, "L")}${claimCell(ax, "R")}</div>`;
      }).join("")}</div>
      ${preview || `<p class="small muted">Pick a side above to see what championing it would do.</p>`}
    </section>

    <section class="act">
      <h4>${ACTIONS.grassroots.label} <span class="cost">₱${ACTIONS.grassroots.cost}M</span></h4>
      <p class="small muted">${esc(ACTIONS.grassroots.help)}</p>
      <div class="act-buttons">${REGIONS.map((r) => `<button class="btn btn-small" data-act="grassroots" data-target="${r.id}" ${dis(ACTIONS.grassroots.cost)}>${esc(r.name)}</button>`).join("")}</div>
    </section>

    <section class="act">
      <h4>${ACTIONS.research.label} <span class="cost">₱${ACTIONS.research.cost}M</span></h4>
      <p class="small muted">${esc(ACTIONS.research.help)} About half the time you find something; one time in seven you get caught.</p>
      <div class="act-buttons">${rv.map((p) => `<button class="btn btn-small" data-act="research" data-target="${p.id}" ${dis(ACTIONS.research.cost)}><span class="dot" style="background:${p.color}"></span> ${esc(p.short)}</button>`).join("")}</div>
      ${S.dossiers.length ? `<p class="eyebrow" style="margin-top:10px">Your dossiers</p>
        <ul class="dossiers">${S.dossiers.map((d, i) => `<li><span><strong>${esc(partyById(d.party).short)}:</strong> ${esc(d.what)} <span class="muted">(${["", "minor", "damaging", "explosive"][d.severity]})</span></span>
          <button class="btn btn-small" data-act="release" data-target="${i}" ${dis()}>Release</button></li>`).join("")}</ul>
        <p class="small muted">${esc(ACTIONS.release.help)}</p>` : ""}
    </section>

    <section class="act">
      <h4>${ACTIONS.poach.label} <span class="cost">₱${ACTIONS.poach.cost}M</span></h4>
      <p class="small muted">${esc(ACTIONS.poach.help)}</p>
      <div class="act-buttons">${rv.map((p) => {
        const ok = canPoach(S, p.id);
        return `<button class="btn btn-small" data-act="poach" data-target="${p.id}" ${ok ? dis(ACTIONS.poach.cost) : "disabled"} title="${ok ? "Ready to defect" : p.stability < 40 ? "Raided recently" : "Too stable"}">
          <span class="dot" style="background:${p.color}"></span> ${esc(p.short)} <span class="muted">· ${stabilityWord(p.stability)}</span></button>`;
      }).join("")}</div>
    </section>

    <section class="act">
      <h4>${ACTIONS.outrage.label} <span class="cost">Free</span></h4>
      <p class="small muted">${esc(ACTIONS.outrage.help)} Each stunt in the last six months makes the next one less effective.</p>
      <div class="act-buttons"><button class="btn btn-small" data-act="outrage" ${dis()}>Say the unsayable</button></div>
    </section>`;
}
function runAction(btn) {
  const t = btn.dataset.target;
  let res;
  switch (btn.dataset.act) {
    case "champion": res = actChampion(S, ui.champ.axis, ui.champ.side); break;
    case "grassroots": res = actGrassroots(S, t); break;
    case "research": res = actResearch(S, t); break;
    case "release": res = actRelease(S, +t); break;
    case "poach": res = actPoach(S, t); break;
    case "outrage": res = actOutrage(S); break;
  }
  if (res) {
    toast(res.text);
    SFX.play(!res.ok || /caught|nothing useful/.test(res.text) ? "bad" : "good");
  }
  save(); render();
}

// ---------- Parties tab ----------
function stabilityWord(v) {
  if (v >= 65) return "United";
  if (v >= 45) return "Stable";
  if (v >= 30) return "Shaky";
  return "In crisis";
}
function trustSparkline() {
  const h = S.trustHistory.slice(-36);
  if (h.length < 2) return "";
  const W = 220, H = 44;
  const x = (i) => (i / (h.length - 1)) * (W - 6) + 3;
  const y = (v) => H - 4 - (v / 100) * (H - 8);
  return `<svg class="spark" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" aria-label="Trust over time">
    <line class="grid" x1="0" x2="${W}" y1="${y(50)}" y2="${y(50)}"/>
    <polyline points="${h.map((p, i) => `${x(i)},${y(p.trust)}`).join(" ")}" fill="none" stroke="var(--accent)" stroke-width="2"/>
    <circle cx="${x(h.length - 1)}" cy="${y(h[h.length - 1].trust)}" r="3" fill="var(--accent)"/></svg>`;
}
function partiesHTML() {
  const poll = latestPoll();
  const nation = summarize(S, S.pops);
  const table = ownershipTable(S);
  const owned = (pid) => table.map((r) => ({ r, me: r.owners.find((o) => o.party === pid) }))
    .filter((x) => x.me && x.me.value >= 0.15 && x.r.owners[0].party === pid)
    .sort((a, b) => b.me.value - a.me.value).slice(0, 3);
  const estWord = (e) => (e >= 0.8 ? "The establishment" : e >= 0.55 ? "Mainstream" : e >= 0.3 ? "Semi-outsider" : "Outsider");
  return `
    <div class="card trust-card">
      <p class="eyebrow">Trust in the political system</p>
      <div class="trust-row"><div><span class="big-number">${Math.round(S.trust)}</span> <strong>${trustLabel(S.trust)}</strong></div>${trustSparkline()}</div>
      <span class="small muted">When trust is low, voters who are fed up turn to outsiders and punish the establishment. Scandals, crises and anti-system rhetoric lower it; it slowly recovers toward 50 on its own.</span>
    </div>
    <div class="party-list">${S.parties.map((p) => {
      const issues = owned(p.id);
      return `<div class="party-card ${p.isPlayer ? "is-you" : ""}">
        <div class="party-top">${portraitHTML(p, "portrait-md")}<div class="party-title"><span class="party-chip">${emblemHTML(p.color, p.emblem, "emblem-xs")}${esc(p.name)}</span>
          <span class="small muted">${esc(p.leader)}</span></div>
          <span class="num">${poll ? pct(poll.national[p.id]) : ""}</span></div>
        <div class="party-meta small">
          <span>Charisma ${Math.round(p.charisma)}</span>
          <span>${estWord(p.establishment)}${p.ruling ? " · governing" : ""}</span>
          <span>${(nation.core[p.id] / 1e6).toFixed(2)}M core voters</span>
        </div>
        ${p.isPlayer ? "" : `<div class="stab"><span class="small">${stabilityWord(p.stability)}</span><div class="stab-track"><div class="stab-fill stab-${p.stability >= 45 ? "ok" : p.stability >= 30 ? "warn" : "bad"}" style="width:${p.stability}%"></div></div></div>`}
        <div class="small">${issues.length ? `Owns: ${issues.map((x) => `<span class="chip">${esc(x.r.label)} ${Math.round(x.me.value * 100)}${x.r.heat > 0.45 ? " · hot" : ""}</span>`).join(" ")}` : `<span class="muted">Owns no issue yet</span>`}</div>
      </div>`;
    }).join("")}</div>
    <p class="small muted">A party in crisis can split, freeing its core voters for whoever stands closest to them. Parties losing voters to you will copy your most popular positions after each annual poll.</p>`;
}

// ---------- News sheet ----------
function newsSheet(front) {
  const label = { vacuum: "Power vacuum", bad: "Trouble", good: "Comeback", neutral: "Change", threat: "Threat", issue: "Hot issue" };
  openSheet(`
    <span class="stamp">This month in politics · ${dateLabel(S.week, false)}</span>
    <h2>${front.items.length === 1 ? esc(front.items[0].title) : "The political landscape is shifting"}</h2>
    <ul class="news">${front.items.map((n) => `<li class="news-${n.kind} ${n.party ? "has-portrait" : ""}">${n.party ? portraitHTML(partyById(n.party), "portrait-md") : ""}<div class="news-body">
      <span class="news-kind">${label[n.kind] || "News"}${n.party ? ` · <span class="dot" style="background:${partyById(n.party).color}"></span> ${esc(partyById(n.party).short)}` : ""}</span>
      ${front.items.length === 1 ? "" : `<strong>${esc(n.title)}</strong>`}
      <span>${esc(n.text)}</span></div></li>`).join("")}</ul>
    <div class="sheet-actions"><button class="btn btn-primary" id="btn-ok">Continue</button></div>`);
  $("#btn-ok").addEventListener("click", () => { dismissFront(S); save(); render(); });
}

// ---------- Toast ----------
let toastTimer = null;
function toast(text) {
  const t = $("#toast");
  t.textContent = text; t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 4200);
}

// ---------- Wiring ----------
document.querySelector("#tabs").addEventListener("click", (e) => {
  const b = e.target.closest("button[data-tab]");
  if (b) { ui.tab = b.dataset.tab; renderTabs(); }
});
$("#tab-body").addEventListener("click", (e) => {
  const dr = e.target.closest("[data-drop]");
  if (dr && !dr.disabled) { dropSignature(S, dr.dataset.drop); save(); renderTabs(); return; }
  const c = e.target.closest("[data-claim]");
  if (c) { ui.champ = { axis: c.dataset.claim, side: c.dataset.side }; renderTabs(); return; }
  const a = e.target.closest("[data-act]");
  if (a && !a.disabled) { runAction(a); return; }
  const k = e.target.closest("[data-kind]");
  if (k) { ui.kind = k.dataset.kind; ui.group = null; renderTabs(); updateMap(); return; }
  const g = e.target.closest("[data-group]");
  if (g) { ui.group = g.dataset.group; renderTabs(); updateMap(); }
});
$("#btn-sound").addEventListener("click", () => { SFX.toggle(); renderStatus(); });
$("#btn-week").addEventListener("click", () => { SFX.play("click"); advanceWeek(S); save(); render(); });
$("#btn-skip").addEventListener("click", () => { advanceToDecision(S); save(); render(); });

// Small tick on ordinary buttons (choices and big moments have their own sounds).
document.addEventListener("click", (e) => {
  const b = e.target.closest("button");
  if (b && !b.disabled && !b.matches("[data-choice], #btn-budget, #t-new, #t-continue, #btn-start, [data-act], #btn-sound, #t-sound")) SFX.play("click");
});

buildMap();
$("#brand-flag").innerHTML = flagSVG("cranebonistan", "flag flag-brand");
const existing = loadSave();
if (existing && existing.result) clearSave();
render();
