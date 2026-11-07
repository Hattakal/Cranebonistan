// =====================================================================
// scene.js: the back room. Full-screen dialogue scenes with Pim (your
// advisor) and Marta Teyl (the party secretary). The opening scene is the
// tutorial. Pure presentation: the only thing a scene writes into the game
// state is S.story, a record of which side you took (for later use).
// =====================================================================
"use strict";

const CAST = {
  pim: { name: "Pim Aster", role: "your advisor", color: "#3b4a6b" },
  teyl: { name: "Marta Teyl", role: "party secretary", color: "#7a1f1a" },
};

// {who} is replaced with the leader's first name.
const SCENES = {
  intro: {
    lines: [
      ["pim", "Evening, {who}. Welcome to headquarters. It isn't much yet, but neither was the Founder's first office."],
      ["pim", "The board on the left is for whatever needs you right now. When something lands, it gets a red pin. Deal with it, or put it down and look at the map first."],
      ["pim", "The files along the top are for planning: who the voters are, what we stand for, what we can do this month. Two actions a month, and one slot to put a debate on the national agenda."],
      ["pim", "Every quarter we decide where the money goes. Every month there's a poll. The good ones I'll read out loud."],
      ["pim", "When the press calls, you decide what to say, and then the exact words. The words matter more than people think. I'd trust your instincts on them. They're better than my drafts."],
      ["teyl", "His drafts are fine. Your instincts haven't been tested yet. Sit down, Pim."],
      ["teyl", "Four years to the election, {who}. The voters forget what you said. The papers don't. Neither do I."],
      ["pim", "Marta's point is fair. And I think you've already taken it on board. It's why people trust you."],
      ["teyl", "My point is: don't sell the movement for one good week in the polls."],
    ],
    choice: {
      prompt: "teyl",
      options: [
        { label: "“You're right, Marta.”", story: "heard_teyl", reply: ["teyl", "Good. Remember you said that. I will."] },
        { label: "“Let's not overthink it.”", story: "waved_teyl", reply: ["teyl", "Of course. Wake me when the polls turn."] },
      ],
    },
    close: ["pim", "Right. The first poll is in. Shall we see where we stand?"],
  },
};

const sceneState = { id: null, i: 0, picked: null, done: null, typing: null };

function sceneArt(speaker) {
  const dim = (who) => (speaker && speaker !== who ? " is-dim" : "");
  return `<svg class="scene-art" viewBox="0 0 1440 900" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
    <defs>
      <radialGradient id="sc-lamp" cx="50%" cy="18%" r="70%"><stop offset="0" stop-color="#ffe6a8" stop-opacity=".5"/><stop offset=".5" stop-color="#c9893a" stop-opacity=".14"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
      <linearGradient id="sc-wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a1d14"/><stop offset="1" stop-color="#140d08"/></linearGradient>
      <pattern id="sc-paper" width="60" height="60" patternUnits="userSpaceOnUse"><path d="M30 0V60" stroke="#3a2a1d" stroke-width="10" opacity=".35"/></pattern>
      <filter id="sc-grain"><feTurbulence type="fractalNoise" baseFrequency=".8" numOctaves="2"/><feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .18 0"/></filter>
    </defs>
    <rect width="1440" height="900" fill="url(#sc-wall)"/>
    <rect width="1440" height="560" fill="url(#sc-paper)"/>
    <rect x="1120" y="90" width="170" height="210" fill="#4a3220" stroke="#8a6a3a" stroke-width="8"/>
    <rect x="1136" y="106" width="138" height="178" fill="#6b5a44"/>
    <ellipse cx="1205" cy="180" rx="38" ry="46" fill="#3e3226"/><path d="M1150 284Q1160 228 1205 226Q1250 228 1260 284Z" fill="#2a2018"/>
    <rect x="130" y="80" width="260" height="300" fill="#1c2a33"/>
    ${[0, 1, 2, 3, 4, 5, 6, 7, 8].map((i) => `<rect x="130" y="${80 + i * 32}" width="260" height="14" fill="#3d3024" opacity=".85"/>`).join("")}
    <rect x="124" y="74" width="272" height="312" fill="none" stroke="#4a3220" stroke-width="10"/>
    <rect class="flicker" width="1440" height="900" fill="url(#sc-lamp)"/>
    <path d="M700 0V120" stroke="#111" stroke-width="3"/>
    <path d="M640 170Q700 100 760 170Z" fill="#1f5a3a" stroke="#0e2e1d" stroke-width="3"/>
    <ellipse cx="700" cy="172" rx="60" ry="8" fill="#ffe6a8" opacity=".85"/>
    <path class="flicker" d="M640 172L470 620H930L760 172Z" fill="#ffe6a8" opacity=".07"/>
    <g class="sc-who${dim("pim")}">
      <path d="M300 640Q300 470 420 450Q520 460 530 640Z" fill="#3b4a6b"/>
      <path d="M400 452L425 520L450 452Z" fill="#f2efe6"/><path d="M420 460L425 560L432 460Z" fill="#b3261e"/>
      <ellipse cx="430" cy="360" rx="70" ry="86" fill="#efc9a4"/><ellipse cx="362" cy="368" rx="12" ry="18" fill="#efc9a4"/>
      <path d="M360 340Q352 262 440 266Q512 272 500 330Q470 296 430 300Q390 302 360 340Z" fill="#1d1712"/>
      <path d="M395 335Q410 326 425 334M450 334Q465 326 480 335" stroke="#1d1712" stroke-width="5" fill="none" stroke-linecap="round"/>
      <circle cx="410" cy="352" r="6" fill="#1d1712"/><circle cx="464" cy="352" r="6" fill="#1d1712"/>
      <path d="M398 398Q437 428 476 398Q437 410 398 398Z" fill="#fff" stroke="#6b2a22" stroke-width="3"/>
      <g transform="rotate(12 515 580)"><rect x="470" y="520" width="90" height="120" rx="6" fill="#d9c49a" stroke="#6b5238" stroke-width="3"/><path d="M484 548H544M484 568H540M484 588H530" stroke="#6b5238" stroke-width="3"/></g>
    </g>
    <g class="sc-who${dim("teyl")}">
      <path d="M840 640Q830 440 1000 420Q1170 440 1160 640Z" fill="#2b2b2e"/><path d="M960 424L1000 500L1040 424Z" fill="#7a1f1a"/>
      <ellipse cx="1000" cy="320" rx="84" ry="96" fill="#d6ab86"/><ellipse cx="918" cy="330" rx="13" ry="20" fill="#d6ab86"/><ellipse cx="1082" cy="330" rx="13" ry="20" fill="#d6ab86"/>
      <path d="M918 300Q914 222 1000 220Q1086 222 1082 300Q1060 250 1000 252Q940 250 918 300Z" fill="#a9a9a9"/><circle cx="1000" cy="208" r="28" fill="#a9a9a9"/>
      <path d="M950 296L990 304M1010 304L1050 296" stroke="#3b3b3b" stroke-width="7" stroke-linecap="round"/>
      <circle cx="968" cy="322" r="20" fill="none" stroke="#222" stroke-width="4"/><circle cx="1032" cy="322" r="20" fill="none" stroke="#222" stroke-width="4"/><path d="M988 322H1012" stroke="#222" stroke-width="4"/>
      <circle cx="968" cy="324" r="5" fill="#1d1712"/><circle cx="1032" cy="324" r="5" fill="#1d1712"/>
      <path d="M965 378L1035 374" stroke="#6b2a22" stroke-width="5" stroke-linecap="round"/>
      <path d="M1030 376L1080 366" stroke="#eee" stroke-width="7" stroke-linecap="round"/><circle cx="1082" cy="366" r="4" fill="#ff7a2a"/>
      <path class="smoke" d="M1084 360Q1070 320 1094 290Q1118 260 1096 220Q1080 190 1104 160" stroke="#d8d0c4" stroke-width="10" fill="none" stroke-linecap="round" opacity=".4"/>
    </g>
    <path d="M0 610H1440V900H0Z" fill="#3a2414"/><path d="M0 610H1440V630H0Z" fill="#5a3a22"/>
    <ellipse cx="770" cy="650" rx="44" ry="12" fill="#6e6e6e"/><ellipse cx="770" cy="646" rx="34" ry="8" fill="#3a3a3a"/>
    <rect x="560" y="632" width="140" height="24" fill="#efe3c6" transform="rotate(-4 630 644)"/>
    <path class="smoke smoke-slow" d="M770 640Q750 580 780 540Q806 500 780 460" stroke="#d8d0c4" stroke-width="12" fill="none" stroke-linecap="round" opacity=".3"/>
    <rect width="1440" height="900" filter="url(#sc-grain)"/>
  </svg>`;
}

function firstName(full) { return String(full || "").split(" ")[0] || "boss"; }

function playScene(id, done) {
  Object.assign(sceneState, { id, i: 0, picked: null, done });
  renderScene();
}

function sceneLine() {
  const sc = SCENES[sceneState.id];
  if (sceneState.picked) {
    const opt = sc.choice.options.find((o) => o.story === sceneState.picked);
    return sceneState.i === 0 ? opt.reply : sc.close;
  }
  return sc.lines[sceneState.i];
}

function renderScene() {
  const el = document.querySelector("#scene");
  const sc = SCENES[sceneState.id];
  if (!sc) { el.hidden = true; return; }
  const [who, raw] = sceneLine();
  const text = raw.replace(/\{who\}/g, firstName(S && S.parties.find((p) => p.isPlayer).leader));
  const c = CAST[who];
  const atChoice = !sceneState.picked && sceneState.i === sc.lines.length - 1 && sc.choice;
  const atEnd = sceneState.picked && sceneState.i === 1;
  el.hidden = false;
  el.innerHTML = `${sceneArt(who)}
    <div class="scene-top"><span>The back room · your first night</span><button class="scene-skip" id="sc-skip">Skip</button></div>
    <div class="dialogue">
      <div class="nameplate" style="--pc:${c.color}" data-side="${who === "pim" ? "left" : "right"}">${esc(c.name)} <span>· ${esc(c.role)}</span></div>
      <p class="dialogue-text" id="sc-text"></p>
      <div class="dialogue-foot">
        <span class="dialogue-count">${sceneState.picked ? "" : `${sceneState.i + 1} / ${sc.lines.length}`}</span>
        ${atChoice ? `<div class="dialogue-choices">${sc.choice.options.map((o) => `<button class="dlg-choice" data-story="${o.story}">${esc(o.label)}</button>`).join("")}</div>`
          : `<button class="dlg-next" id="sc-next">${atEnd ? "Begin the campaign" : "Continue"} →</button>`}
      </div>
    </div>`;
  typeText(document.querySelector("#sc-text"), text);
  document.querySelector("#sc-skip").addEventListener("click", endScene);
  const next = document.querySelector("#sc-next");
  if (next) next.addEventListener("click", () => {
    if (sceneState.typing) { finishTyping(); return; }
    if (atEnd) { endScene(); return; }
    sceneState.i++; renderScene();
  });
  document.querySelectorAll("[data-story]").forEach((b) => b.addEventListener("click", () => {
    if (S) (S.story = S.story || {})[sceneState.id] = b.dataset.story;
    sceneState.picked = b.dataset.story; sceneState.i = 0; SFX.play("stamp"); renderScene();
  }));
}

// Lines appear a few letters at a time, with a soft typewriter click.
function typeText(node, text) {
  finishTyping();
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) { node.textContent = text; return; }
  let n = 0;
  sceneState.typing = { node, text, timer: setInterval(() => {
    n = Math.min(text.length, n + 2);
    node.textContent = text.slice(0, n);
    if (n % 6 === 0) SFX.play("type");
    if (n >= text.length) finishTyping();
  }, 22) };
}
function finishTyping() {
  const t = sceneState.typing;
  if (!t) return;
  clearInterval(t.timer); t.node.textContent = t.text; sceneState.typing = null;
}

function endScene() {
  finishTyping();
  document.querySelector("#scene").hidden = true;
  const done = sceneState.done;
  sceneState.id = null; sceneState.done = null;
  if (done) done();
}
