// =====================================================================
// art.js — event illustrations, drawn in code (original artwork).
// Every scene is a 600 × 200 banner in the same flat, inked style.
// EVENT_ART says which scene each event uses (and which flags appear);
// events without an entry fall back to a scene for their kind.
// =====================================================================
"use strict";

const ART = (() => {
  const C = { ink: "#26292b", paper: "#f3efe4", sky: "#dfe7e6", skyWarm: "#f2dcc0", sea: "#9fbcc4", seaD: "#7a9ea8",
    land: "#c9c3a6", grass: "#93a874", red: "#c8402a", gold: "#d9a43a", blue: "#3a64b8", grey: "#9aa0a0", greyD: "#6b7172", white: "#fbfaf5", brick: "#b5674d" };
  const st = `stroke="${C.ink}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"`;
  const P = (d, fill, extra = "") => `<path d="${d}" fill="${fill}" ${st} ${extra}/>`;
  const R = (x, y, w, h, fill, extra = "") => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" ${st} ${extra}/>`;
  const L = (d, w = 2.5, col = C.ink, extra = "") => `<path d="${d}" fill="none" stroke="${col}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" ${extra}/>`;
  const circ = (x, y, r, fill, extra = "") => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" ${st} ${extra}/>`;
  // A little person: head + body, used in crowds
  const person = (x, y, s, col, sign) => {
    let g = P(`M${x - 9 * s} ${y + 30 * s} C${x - 9 * s} ${y + 12 * s} ${x + 9 * s} ${y + 12 * s} ${x + 9 * s} ${y + 30 * s} Z`, col) + circ(x, y + 5 * s, 6 * s, "#e3bf9f");
    if (sign) g += L(`M${x + 6 * s} ${y + 18 * s} L${x + 10 * s} ${y - 14 * s}`, 2) + R(x - 4 * s, y - 34 * s, 28 * s, 18 * s, sign);
    return g;
  };
  // A flag on a pole, using the national flags from flags.js
  const flagPole = (x, y, id, h = 70) => L(`M${x} ${y} L${x} ${y - h}`, 3) +
    `<g transform="translate(${x} ${y - h}) scale(0.7)">${FLAGS[id] ? FLAGS[id]() : ""}<rect width="60" height="40" fill="none" stroke="${C.ink}" stroke-width="2.5"/></g>`;

  const SCENES = {
    // falling currency: a chart line crashing past a coin
    currency: () => R(0, 0, 600, 200, C.paper, 'stroke="none"') +
      [40, 80, 120, 160].map((y) => L(`M40 ${y} L560 ${y}`, 1, C.grey, 'stroke-dasharray="4 6"')).join("") +
      L("M40 50 L120 60 L170 48 L230 80 L280 74 L340 110 L390 104 L450 150 L520 170", 5, C.red) +
      P("M520 170 L506 156 L530 160 Z", C.red) +
      circ(140, 130, 44, C.gold) + circ(140, 130, 34, C.gold) +
      `<text x="140" y="146" text-anchor="middle" font-family="Georgia,serif" font-size="44" font-weight="700" fill="${C.ink}">\u20B1</text>` +
      R(430, 28, 130, 44, C.white) + `<text x="495" y="58" text-anchor="middle" font-family="monospace" font-size="22" font-weight="700" fill="${C.red}">\u221214%</text>`,
    // overcrowded ship arriving at a harbour
    ship: () => R(0, 0, 600, 200, C.sky, 'stroke="none"') + R(0, 130, 600, 70, C.sea, 'stroke="none"') +
      L("M0 150 Q30 142 60 150 T120 150 T180 150 T240 150 T300 150 T360 150 T420 150 T480 150 T540 150 T600 150", 2, C.seaD) +
      R(470, 100, 130, 40, C.greyD) + R(500, 60, 14, 40, C.grey) + L("M507 60 L560 30 L560 100", 3) +
      P("M90 120 L340 120 L320 160 L110 160 Z", C.brick) + R(150, 92, 120, 28, C.white) + R(230, 64, 22, 28, C.red) +
      Array.from({ length: 12 }, (_, i) => circ(118 + i * 18, 112 - (i % 2) * 4, 7, "#e3bf9f")).join("") +
      Array.from({ length: 7 }, (_, i) => circ(162 + i * 16, 86, 6, "#e3bf9f")).join(""),
    // factory with strikers and picket signs
    factory: () => R(0, 0, 600, 200, C.skyWarm, 'stroke="none"') +
      P("M70 40 C60 20 90 10 100 24 C110 8 140 14 136 34", "#cfc7bd") + P("M190 30 C182 12 206 4 216 18 C226 4 250 10 246 28", "#cfc7bd") +
      R(80, 50, 26, 90, C.greyD) + R(200, 40, 26, 100, C.greyD) +
      P("M40 170 L40 110 L110 80 L110 110 L180 80 L180 110 L250 80 L250 110 L320 80 L320 170 Z", C.brick) +
      [70, 140, 210, 280].map((x) => R(x - 12, 125, 24, 22, C.sky)).join("") +
      R(0, 170, 600, 30, C.land, 'stroke="none"') +
      person(380, 120, 1.3, C.blue, C.white) + person(440, 126, 1.2, C.red) + person(500, 118, 1.3, C.greyD, C.gold) + person(560, 124, 1.2, C.blue) +
      `<text x="398" y="88" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="700" fill="${C.red}">STRIKE</text>`,
    // drought: cracked earth, dead wheat, burning sun
    fields: () => R(0, 0, 600, 200, C.skyWarm, 'stroke="none"') + circ(480, 55, 32, C.gold) +
      Array.from({ length: 12 }, (_, i) => { const a = i * Math.PI / 6; return L(`M${480 + Math.cos(a) * 42} ${55 + Math.sin(a) * 42} L${480 + Math.cos(a) * 56} ${55 + Math.sin(a) * 56}`, 3, C.gold); }).join("") +
      R(0, 120, 600, 80, "#d8c08e", 'stroke="none"') +
      L("M40 150 L90 140 L120 160 L180 145 M120 160 L130 190 M260 150 L300 170 L360 150 L400 175 M300 170 L290 195 M470 160 L520 150 L560 180", 2) +
      Array.from({ length: 10 }, (_, i) => { const x = 40 + i * 32; return L(`M${x} 130 Q${x + 4} 100 ${x + 14} 92`, 2.5, "#9b8550") + P(`M${x + 14} 92 c4 -2 8 0 6 4 c-3 3 -7 2 -6 -4 z`, "#c9a560"); }).join(""),
    // flood: houses half under water in the rain
    flood: () => R(0, 0, 600, 200, "#c8d0d2", 'stroke="none"') +
      Array.from({ length: 40 }, (_, i) => L(`M${(i * 37) % 600} ${(i * 23) % 120} l-6 16`, 1.5, C.greyD)).join("") +
      [[80, 60], [220, 50], [380, 66], [500, 56]].map(([x, y]) => P(`M${x} ${y + 30} L${x + 45} ${y} L${x + 90} ${y + 30} Z`, C.brick) + R(x + 8, y + 30, 74, 80, C.white) + R(x + 30, y + 46, 22, 20, C.sky)).join("") +
      R(0, 125, 600, 75, C.sea, 'stroke="none" opacity="0.92"') +
      L("M0 125 Q25 117 50 125 T100 125 T150 125 T200 125 T250 125 T300 125 T350 125 T400 125 T450 125 T500 125 T550 125 T600 125", 2.5, C.seaD) +
      P("M260 150 L330 150 L320 166 L270 166 Z", C.red) + person(295, 128, 0.7, C.gold),
    // steppe: hills, yurts and camels under a big sky
    steppe: () => R(0, 0, 600, 200, C.skyWarm, 'stroke="none"') +
      P("M0 120 C100 80 200 110 300 90 C400 70 500 100 600 85 L600 200 L0 200 Z", "#cdb98a") +
      P("M0 150 C150 130 300 160 450 140 C520 132 560 140 600 138 L600 200 L0 200 Z", "#b9a372") +
      [[120, 120], [190, 128]].map(([x, y]) => P(`M${x - 34} ${y + 20} L${x - 34} ${y} C${x - 20} ${y - 26} ${x + 20} ${y - 26} ${x + 34} ${y} L${x + 34} ${y + 20} Z`, C.white) + R(x - 8, y + 4, 16, 16, C.red)).join("") +
      [[400, 120], [480, 128]].map(([x, y]) => P(`M${x - 30} ${y + 4} C${x - 28} ${y - 18} ${x - 10} ${y - 20} ${x - 4} ${y - 8} C${x} ${y - 22} ${x + 16} ${y - 20} ${x + 18} ${y - 4} L${x + 30} ${y - 16} L${x + 38} ${y - 12} L${x + 26} ${y + 4} Z`, "#b78a55") + L(`M${x - 22} ${y + 4} L${x - 24} ${y + 30} M${x - 10} ${y + 4} L${x - 8} ${y + 30} M${x + 10} ${y + 4} L${x + 8} ${y + 30} M${x + 22} ${y + 4} L${x + 24} ${y + 30}`, 3)).join(""),
    // the National Assembly building
    parliament: () => R(0, 0, 600, 200, C.sky, 'stroke="none"') +
      P("M230 70 C230 30 370 30 370 70 Z", C.grey) + R(292, 18, 16, 16, C.gold) + L("M300 18 L300 2", 2) +
      P("M150 80 L300 50 L450 80 Z", C.white) + R(150, 80, 300, 14, C.white) +
      Array.from({ length: 8 }, (_, i) => R(168 + i * 37, 94, 14, 70, C.white)).join("") +
      R(140, 164, 320, 12, C.white) + R(120, 176, 360, 12, C.white) + R(0, 188, 600, 12, C.land, 'stroke="none"') +
      L("M70 188 L70 80", 3) + `<g transform="translate(70 80) scale(0.7)">${FLAGS.cranebonistan()}<rect width="60" height="40" fill="none" stroke="${C.ink}" stroke-width="2.5"/></g>` +
      L("M530 188 L530 80", 3) + `<g transform="translate(530 80) scale(0.7)">${FLAGS.cranebonistan()}<rect width="60" height="40" fill="none" stroke="${C.ink}" stroke-width="2.5"/></g>`,
    // protest crowd with placards
    crowd: () => R(0, 0, 600, 200, C.skyWarm, 'stroke="none"') +
      R(0, 40, 600, 100, "#d6cfc4", 'stroke="none"') + Array.from({ length: 6 }, (_, i) => R(30 + i * 100, 50, 60, 90, "#e8e1d4")).join("") +
      Array.from({ length: 11 }, (_, i) => person(30 + i * 55, 128 - (i % 3) * 6, 1.2, [C.blue, C.red, C.greyD, C.gold, C.grass][i % 5], i % 3 === 0 ? [C.white, C.gold, C.red][i % 3 === 0 ? (i / 3) % 3 : 0] : null)).join("") +
      R(0, 168, 600, 32, C.greyD, 'stroke="none"'),
    // TV studio: two podiums under lights, a camera
    tv: () => R(0, 0, 600, 200, "#2c3340", 'stroke="none"') +
      P("M120 0 L60 170 L220 170 Z", "#3a4352", 'stroke="none" opacity="0.8"') + P("M480 0 L380 170 L540 170 Z", "#3a4352", 'stroke="none" opacity="0.8"') +
      R(0, 170, 600, 30, "#1d222b", 'stroke="none"') +
      R(110, 110, 70, 60, C.red) + R(420, 110, 70, 60, C.blue) + circ(145, 90, 14, "#e3bf9f") + circ(455, 90, 14, "#e3bf9f") +
      L("M145 110 L145 98 M455 110 L455 98", 2, C.white) +
      R(250, 40, 100, 64, "#4a5566") + `<text x="300" y="80" text-anchor="middle" font-family="sans-serif" font-size="16" font-weight="700" fill="${C.white}">LIVE</text>` + circ(268, 74, 5, C.red) +
      R(270, 130, 60, 32, C.greyD) + circ(330, 146, 12, C.grey) + L("M285 162 L275 196 M300 162 L300 196 M315 162 L325 196", 3, C.grey),
    // newspaper front page with a big headline
    newspaper: () => R(0, 0, 600, 200, "#d9d2c4", 'stroke="none"') +
      P("M150 12 L470 12 L470 196 L150 196 Z", C.white, 'transform="rotate(-3 310 104)"') +
      `<g transform="rotate(-3 310 104)">` +
      `<text x="310" y="40" text-anchor="middle" font-family="Georgia,serif" font-size="22" font-weight="700" fill="${C.ink}">THE CRANEAPOLIS HERALD</text>` +
      L("M166 50 L454 50", 2) + R(170, 62, 280, 34, C.ink) + `<text x="310" y="86" text-anchor="middle" font-family="Georgia,serif" font-size="22" font-weight="700" fill="${C.white}">SCANDAL!</text>` +
      R(170, 106, 120, 76, C.grey) + circ(230, 136, 16, "#e3bf9f") + P("M204 182 C204 160 256 160 256 182 Z", C.greyD) +
      Array.from({ length: 7 }, (_, i) => L(`M304 ${112 + i * 10} L450 ${112 + i * 10}`, 2, C.greyD)).join("") + `</g>`,
    // border fence with a watchtower and two flags
    border: (flags = ["cranebonistan", "trueants"]) => R(0, 0, 600, 200, C.sky, 'stroke="none"') +
      P("M0 140 C150 120 450 130 600 120 L600 200 L0 200 Z", C.grass) +
      Array.from({ length: 16 }, (_, i) => L(`M${20 + i * 38} 170 L${20 + i * 38} 110`, 3)).join("") +
      L("M0 120 L600 120 M0 140 L600 140 M0 160 L600 160", 1.6, C.greyD) + L("M0 112 Q10 104 20 112 T40 112 T60 112 T80 112 T100 112 T120 112 T140 112 T160 112 T180 112 T200 112 T220 112 T240 112 T260 112 T280 112 T300 112 T320 112 T340 112 T360 112 T380 112 T400 112 T420 112 T440 112 T460 112 T480 112 T500 112 T520 112 T540 112 T560 112 T580 112 T600 112", 1.5, C.greyD) +
      R(270, 30, 60, 30, C.brick) + L("M280 60 L268 176 M320 60 L332 176 M274 100 L326 100 M272 140 L328 140", 3) +
      flagPole(130, 176, flags[0], 100) + flagPole(470, 176, flags[1] || flags[0], 100),
    // trophy with confetti
    stadium: () => R(0, 0, 600, 200, "#2f5a3a", 'stroke="none"') + L("M0 150 L600 150", 3, C.white) + `<circle cx="300" cy="150" r="60" fill="none" stroke="${C.white}" stroke-width="3"/>` +
      Array.from({ length: 50 }, (_, i) => `<rect x="${(i * 53) % 600}" y="${(i * 31) % 140}" width="6" height="10" fill="${[C.red, C.gold, C.white, C.blue][i % 4]}" transform="rotate(${i * 37} ${(i * 53) % 600} ${(i * 31) % 140})"/>`).join("") +
      P("M270 40 L330 40 C330 90 314 104 300 104 C286 104 270 90 270 40 Z", C.gold) + P("M270 50 C250 50 250 80 274 82 M330 50 C350 50 350 80 326 82", "none") +
      R(292, 104, 16, 26, C.gold) + R(276, 130, 48, 14, C.gold),
    // city blocks: rents, jobs, crime, hospitals
    city: () => R(0, 0, 600, 200, C.skyWarm, 'stroke="none"') +
      [[20, 60, 90], [120, 30, 80], [210, 80, 70], [290, 40, 100], [400, 70, 80], [490, 20, 100]].map(([x, y, w]) =>
        R(x, y, w, 200 - y, [C.white, "#e2d6c3", C.grey][x % 3]) +
        Array.from({ length: Math.floor((170 - y) / 26) }, (_, r2) => Array.from({ length: Math.floor((w - 10) / 22) }, (_, c2) => R(x + 10 + c2 * 22, y + 12 + r2 * 26, 12, 14, (r2 + c2) % 3 ? C.sky : C.gold, 'stroke-width="1.5"')).join("")).join("")).join("") +
      R(0, 180, 600, 20, C.greyD, 'stroke="none"') + R(300, 120, 80, 30, C.red) + `<text x="340" y="141" text-anchor="middle" font-family="sans-serif" font-size="13" font-weight="700" fill="${C.white}">TO LET</text>`,
    // hospital corridor
    hospital: () => R(0, 0, 600, 200, "#e8eceb", 'stroke="none"') + P("M0 0 L200 60 L400 60 L600 0 Z", "#d5dbda") + P("M0 200 L200 140 L400 140 L600 200 Z", "#cfd6d4") +
      R(200, 60, 200, 80, "#f4f6f5") + R(272, 74, 56, 56, C.white) + R(292, 82, 16, 40, C.red, 'stroke="none"') + R(280, 94, 40, 16, C.red, 'stroke="none"') +
      R(40, 130, 120, 22, C.white) + L("M50 152 L50 176 M150 152 L150 176", 3) + circ(60, 124, 10, "#e3bf9f") +
      R(440, 132, 120, 22, C.white) + L("M450 154 L450 178 M550 154 L550 178", 3) + circ(540, 126, 10, "#e3bf9f"),
    // handshake between two flags: diplomacy and trade
    diplomacy: (flags = ["cranebonistan", "golba"]) => R(0, 0, 600, 200, C.paper, 'stroke="none"') +
      R(110, 150, 380, 14, "#8a6e4b") + L("M140 164 L140 196 M460 164 L460 196", 4) +
      flagPole(80, 196, flags[0], 140) + flagPole(520, 196, flags[1] || "golba", 140) +
      P("M190 120 L270 110 L300 124 L330 110 L410 120 L410 140 L330 142 L300 132 L270 142 L190 140 Z", "#e3bf9f") +
      R(150, 112, 40, 34, C.greyD) + R(410, 112, 40, 34, C.blue),
    // microphone on a podium: speeches, gaffes
    microphone: () => R(0, 0, 600, 200, "#3b3f46", 'stroke="none"') + `<circle cx="300" cy="40" r="140" fill="#4a505a"/>` +
      R(250, 120, 100, 80, "#7a2338") + circ(300, 150, 14, C.gold) +
      L("M300 120 L300 70", 4, C.grey) + R(288, 40, 24, 36, C.greyD, 'rx="12"') + L("M292 50 L308 50 M292 58 L308 58 M292 66 L308 66", 1.5, C.grey) +
      circ(340, 44, 8, C.red, 'stroke="none"') + `<text x="356" y="50" font-family="sans-serif" font-size="16" font-weight="700" fill="${C.red}">REC</text>`,
  };

  // Which picture goes with which event (and which flags it shows).
  const EVENT_ART = {
    pezo_slide: ["currency"], minimum_wage: ["factory"], rent_crisis: ["city"], pension_reform: ["crowd"], youth_video: ["city"],
    port_automation: ["ship"], golba_trade: ["diplomacy", ["cranebonistan", "golba"]], norbanian_boats: ["ship"],
    alinnian_schools: ["parliament"], civil_partnerships: ["parliament"], festival_holiday: ["fields"], crime_wave: ["city"],
    trueant_claim: ["border", ["cranebonistan", "trueants"]], dillihan_border: ["steppe"], james_mines: ["diplomacy", ["james", "potania"]],
    generalissimo: ["border", ["cranebonistan", "bourdeaux"]], golba_sanctions: ["diplomacy", ["golba", "trueants"]],
    dillihan_pipeline: ["steppe"], james_base: ["border", ["cranebonistan", "james"]], yamlin_flood: ["flood"], cup_victory: ["stadium"],
    tv_debate: ["tv"], fauraifai_quake: ["steppe"], celebrity_endorsement: ["stadium"], hospital_queues: ["hospital"],
    smog_cranbia: ["factory"], nomad_schools: ["steppe"], erland_drought: ["fields"], cranbia_strike: ["factory"],
    hot_mic: ["microphone"], interview_trap: ["tv"], tax_promise: ["microphone"], deputy_fight: ["newspaper"],
    minister_corruption: ["newspaper"], rival_plagiarism: ["newspaper"], alinni_protests: ["crowd"], stranded_ship: ["ship"],
    deepfake_exposed: ["newspaper"], leak_dillihan: ["newspaper"], leak_trueants: ["newspaper"], leak_potania: ["newspaper"],
    leak_golba: ["newspaper"], leak_tycoon: ["newspaper"], leak_proof: ["newspaper"],
  };
  const BY_KIND = { crisis: "crowd", opportunity: "microphone", trap: "microphone", scandal: "newspaper", regional: "city", foreign: "diplomacy", followup: "newspaper" };

  function sceneFor(ev) {
    let [name, flags] = EVENT_ART[ev.id] || [];
    if (!name && String(ev.id).startsWith("defectors_")) name = "parliament";
    if (!name) name = BY_KIND[ev.kind] || "parliament";
    return SCENES[name](flags);
  }
  function eventArt(ev) {
    return `<svg class="event-art" viewBox="0 0 600 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true">${sceneFor(ev)}</svg>`;
  }
  return { eventArt, SCENES, EVENT_ART };
})();
