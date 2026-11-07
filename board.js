// =====================================================================
// board.js: the evidence board. Only what is current or urgent goes here:
// the decision waiting for you, this week's headlines, the latest poll,
// notes from your staff, trouble to watch and what comes next.
// Planning lives in the files along the top bar (ui.js).
// =====================================================================
"use strict";

const PIN_COLORS = { red: "#c0392b", yellow: "#d4a017", blue: "#2c6db3", green: "#2f8a4c", black: "#2b2b2b" };
const pinHTML = (color = "red", pulse = false) => `<span class="pin${pulse ? " pin-pulse" : ""}" style="--pin:${PIN_COLORS[color]}"></span>`;

function frontSummary(front) {
  if (!front) return null;
  switch (front.type) {
    case "event": {
      const ev = eventOf(front);
      const kind = { crisis: "Crisis", opportunity: "Opportunity", trap: "Tricky moment", scandal: "Scandal", regional: "Regional issue", foreign: "Foreign affairs", followup: "Consequences" }[ev.kind] || "Event";
      return { kicker: kind, title: ev.title, text: ev.text, stamp: "Decision needed", art: true, ev };
    }
    case "budget": return { kicker: "Quarterly budget", title: "Where does the money go?", text: `₱${S.money.toFixed(1)}M in the account. Rallies, social media, TV and the national tour are waiting for a decision.`, stamp: "Sign off", icon: "banknote" };
    case "poll": { const p = S.polls[front.index]; return { kicker: p.label, title: "The poll is in", text: "The numbers for every party, and the map, are updated.", stamp: "Read it", icon: "chart-line" }; }
    case "news": return { kicker: "Breaking", title: front.items[0].title, text: front.items[0].text, stamp: "Read it", icon: "newspaper" };
    case "debate": return { kicker: "Live on CBC", title: "The final debate", text: "Seven million people are watching. Your rivals have been reading your old quotes.", stamp: "Tonight", icon: "megaphone" };
    case "election": return { kicker: "Election night", title: "The results are in", text: "", stamp: "Open", icon: "landmark" };
  }
  return null;
}

function nextWeekWhere(test) { for (let w = S.week + 1; w <= ELECTION_WEEK; w++) if (test(calendar(w))) return w; return null; }

function pimNote() {
  const n = S.actionsLeft, agenda = !S.agenda.done;
  const nextBudget = nextWeekWhere((c) => c.isQuarterStart);
  if (S.result) return "Whatever happens next, it was an honour, boss. Really.";
  if (n > 0 && agenda) return `Two things this month: ${n} action${n === 1 ? "" : "s"} left and the agenda slot is open. No pressure. You always pick the right ones.`;
  if (n > 0) return `${n} action${n === 1 ? "" : "s"} left this month. Whenever you're ready.`;
  if (agenda) return "The agenda slot is still open. People are waiting to hear what you care about.";
  if (S.money > 6 && nextBudget) return `We're sitting on ₱${S.money.toFixed(1)}M. Next budget in ${dateLabel(nextBudget, false)}. I've kept the donors happy.`;
  return "Quiet week. I've moved the bad news to Monday.";
}
function teylNote() {
  const player = partyById("player");
  if (inconsistencyOf(S, player) >= 2) return "Pick a position and keep it. People are starting to notice.";
  if ((S.record.outrages || 0) >= 3) return "Shouting gets you noticed. It doesn't get you trusted.";
  if ((S.record.money || []).some((m) => m.dirty)) return "I saw the donor list. We'll talk.";
  return null;
}

function watchItems() {
  const items = [];
  if (S.crisis) { const c = byId(CRISES, S.crisis.id); items.push({ strong: c.name, text: c.blurb }); }
  for (const f of FOREIGN) {
    const st = S.countries && S.countries[f.id];
    if (st && st.hot) items.push({ strong: f.name.join(" "), text: st.relation || "Trouble on the border" });
  }
  const hot = AXES.filter((a) => (S.salMod[a.id] || 0) > 0.45).map((a) => a.issue);
  if (hot.length) items.push({ strong: "In the news", text: hot.join(", ") });
  return items.slice(0, 3);
}

function renderBoard() {
  const host = document.querySelector("#board-items");
  if (!host || !S) return;
  const front = S.queue[0];
  const sum = frontSummary(front);
  const poll = latestPoll();
  const cards = [];

  // 1. The decision waiting for you
  if (sum) {
    cards.push(`<button class="bcard bcard-decision" data-board="decision" style="--tilt:-1deg">
      ${pinHTML("red", true)}
      <span class="clip-kicker">${esc(sum.kicker)} · ${dateLabel(S.week, false)}</span>
      ${sum.art ? `<span class="clip-art">${ART.eventArt(sum.ev)}</span>` : `<span class="clip-icon">${iconSVG(sum.icon)}</span>`}
      <span class="clip-title">${esc(sum.title)}</span>
      ${sum.text ? `<span class="clip-text">${esc(sum.text)}</span>` : ""}
      <span class="clip-stamp">${esc(sum.stamp)}</span>
    </button>`);
  } else if (S.result) {
    cards.push(`<button class="bcard bcard-decision" data-board="results" style="--tilt:-1deg">${pinHTML("red")}
      <span class="clip-kicker">Election night</span><span class="clip-title">The results</span><span class="clip-stamp">Open</span></button>`);
  } else {
    cards.push(`<div class="bcard bcard-clear" style="--tilt:-.6deg">${pinHTML("black")}
      <span class="clip-kicker">${dateLabel(S.week)}</span>
      <span class="clip-title">Nothing on fire</span>
      <span class="clip-text">Plan your month in the files above, or move the clock forward.</span></div>`);
  }

  // 2. The latest poll
  if (poll) {
    const ids = Object.keys(poll.national).sort((a, b) => poll.national[b] - poll.national[a]);
    const max = poll.national[ids[0]];
    cards.push(`<button class="bcard bcard-poll" data-board="polls" data-string style="--tilt:2deg">${pinHTML("blue")}
      <span class="clip-kicker">${esc(poll.label)} · ${dateLabel(poll.week, false)}</span>
      <span class="poll-rows">${ids.map((id) => { const p = partyById(id); return `<span class="poll-row ${p.isPlayer ? "is-you" : ""}"><span>${esc(p.short)}</span><span class="poll-bar"><span style="width:${(poll.national[id] / max) * 100}%;background:${p.color}"></span></span><span>${pct(poll.national[id], 0)}</span></span>`; }).join("")}</span>
    </button>`);
  }

  // 3. Staff notes
  cards.push(`<button class="bcard bcard-note" data-board="actions" style="--tilt:-3deg">${pinHTML("green")}
    <span class="note-text">${esc(pimNote())}</span><span class="note-sign">— Pim</span></button>`);
  const teyl = teylNote();
  if (teyl) cards.push(`<div class="bcard bcard-index" data-string style="--tilt:1.5deg">${pinHTML("black")}
    <span class="note-text">${esc(teyl)}</span><span class="note-sign">— M. Teyl</span></div>`);

  // 4. This week's headlines
  const recent = [...S.log].reverse().slice(0, 3);
  if (recent.length) cards.push(`<button class="bcard bcard-news" data-board="diary" style="--tilt:-1.2deg">${pinHTML("yellow")}
    <span class="news-mast">The Craneapolis Herald</span>
    ${recent.map((l, i) => `<span class="news-item ${i ? "" : "lead"}"><span class="when">${dateLabel(l.week, false)}</span>${esc(l.text)}</span>`).join("")}
  </button>`);

  // 5. Trouble to watch
  const watch = watchItems();
  if (watch.length) cards.push(`<button class="bcard bcard-watch" data-board="parties" data-string style="--tilt:2.4deg">${pinHTML("red")}
    <span class="clip-kicker">${iconSVG("triangle-alert")} Watch</span>
    ${watch.map((w) => `<span class="watch-item"><strong>${esc(w.strong)}</strong> ${esc(w.text)}</span>`).join("")}
  </button>`);

  // 6. Coming up
  const nb = nextWeekWhere((c) => c.isQuarterStart), np = nextWeekWhere((c) => c.weekOfMonth === 2);
  const monthsLeft = Math.ceil((ELECTION_WEEK - S.week) / CONFIG.weeksPerMonth);
  cards.push(`<div class="bcard bcard-calendar" style="--tilt:-2deg">${pinHTML("yellow")}
    <span class="cal-head">Coming up</span>
    ${nb ? `<span class="cal-row"><span>Budget</span><span>${dateLabel(nb, false)}</span></span>` : ""}
    ${np ? `<span class="cal-row"><span>Next poll</span><span>${dateLabel(np, false)}</span></span>` : ""}
    <span class="cal-row cal-big"><span>Election</span><span>${S.result ? "Held" : `${monthsLeft} month${monthsLeft === 1 ? "" : "s"}`}</span></span>
  </div>`);

  const key = cards.join("");
  if (host.dataset.key !== key) {
    const isNew = sum && host.dataset.front !== String(S.week) + (sum.title || "");
    host.innerHTML = key;
    host.dataset.key = key;
    host.dataset.front = sum ? String(S.week) + (sum.title || "") : "";
    if (isNew) { const d = host.querySelector(".bcard-decision"); if (d) d.classList.add("is-new"); }
    requestAnimationFrame(drawStrings);
  }
}

// Red string from the decision pin to the related cards.
function drawStrings() {
  const svg = document.querySelector("#strings");
  const board = document.querySelector("#board");
  if (!svg || !board) return;
  const box = board.getBoundingClientRect();
  svg.setAttribute("viewBox", `0 0 ${box.width} ${box.height}`);
  const at = (el) => { const r = el.querySelector(".pin").getBoundingClientRect(); return [r.left + r.width / 2 - box.left + board.scrollLeft, r.top + r.height / 2 - box.top + board.scrollTop]; };
  const from = board.querySelector(".bcard-decision");
  if (!from) { svg.innerHTML = ""; return; }
  const [x1, y1] = at(from);
  svg.innerHTML = [...board.querySelectorAll("[data-string]")].map((el) => {
    const [x2, y2] = at(el);
    const sag = Math.min(60, Math.hypot(x2 - x1, y2 - y1) * 0.18);
    return `<path d="M${x1} ${y1} Q${(x1 + x2) / 2} ${(y1 + y2) / 2 + sag} ${x2} ${y2}"/>`;
  }).join("");
}
window.addEventListener("resize", () => requestAnimationFrame(drawStrings));
