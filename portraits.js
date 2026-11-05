// =====================================================================
// portraits.js — drawn portraits of politicians, generated in code.
// Original artwork: no image files and no licences involved.
//
// drawPortrait({ seed, sex: "m"|"f", age: 40..80, pin: "#hex" }) -> SVG string
// The same seed always gives the same face.
// =====================================================================
"use strict";

const Portraits = (() => {
  const INK = "#26292b";
  // tiny seeded random generator so a name always gives the same face
  function rng(seed) {
    let h = 1779033703 ^ String(seed).length;
    for (const ch of String(seed)) { h = Math.imul(h ^ ch.charCodeAt(0), 3432918353); h = (h << 13) | (h >>> 19); }
    return () => {
      h = Math.imul(h ^ (h >>> 16), 2246822507); h = Math.imul(h ^ (h >>> 13), 3266489909);
      return ((h ^= h >>> 16) >>> 0) / 4294967296;
    };
  }
  const pick = (r, list) => list[Math.floor(r() * list.length)];
  // darken/lighten a #rrggbb colour by a factor
  function shade(hex, f) {
    const n = parseInt(hex.slice(1), 16);
    const c = [n >> 16, (n >> 8) & 255, n & 255].map((v) => Math.round(Math.max(0, Math.min(255, f < 0 ? v * (1 + f) : v + (255 - v) * f))));
    return "#" + c.map((v) => v.toString(16).padStart(2, "0")).join("");
  }

  const SKIN = ["#f2d4ba", "#ecc6a6", "#e3b893", "#f2d4ba", "#d9a983", "#ecc6a6", "#c4936e", "#a8775a"];
  const SUITS = ["#2b3445", "#353a40", "#4a4f57", "#1f2a3a", "#4d3f35", "#3a3f4f", "#5b6168"];
  const SHIRTS = ["#ffffff", "#f3f1ea", "#dfe8f2"];
  const TIES = ["#8c2f2f", "#2f4f8c", "#6b5a2e", "#3d6b4f", "#5a3a6b", "#7a7f88"];
  const BLOUSES = ["#ffffff", "#f2e6d9", "#e3eaf2", "#2c2c2c"];
  const BLAZERS = ["#2b3445", "#6d2b3a", "#3d4a5c", "#4a4f57", "#8a6e4b", "#2f4a44", "#7b8794"];
  const GREYS = ["#d9d9d6", "#bdbdb8", "#9a9a95", "#7c7b77", "#ece9e2"];
  const DARK = ["#3a2f2a", "#2b2522", "#4b3a2f", "#5a4636"];
  const DYED = ["#b88a5a", "#8a4b2f", "#c9b48a", "#6b3b2a"];

  function drawPortrait({ seed = "x", sex = "m", age = 60, pin = "#c8402a" } = {}) {
    const r = rng(seed + "|" + sex);
    const old = Math.max(0, Math.min(1, (age - 40) / 35)); // 0 at 40, 1 at 75
    const skin = pick(r, SKIN);
    const skinD = shade(skin, -0.14);
    const w = 31 + r() * 6;          // cheek half-width
    const jaw = w * (0.55 + r() * 0.25 + (sex === "m" ? 0.08 : 0)); // jaw half-width
    const chin = 128 + r() * 6;
    const cx = 100, eyeY = 88, browY = 78;
    const grey = r() < 0.25 + old * 0.75;
    let hairCol = grey ? pick(r, GREYS) : pick(r, DARK);
    if (sex === "f" && grey && r() < 0.45) hairCol = pick(r, DYED); // many older women politicians dye their hair
    const hairD = shade(hairCol, -0.25);
    const glasses = r() < 0.45 ? pick(r, ["rect", "round", "half"]) : null;
    const s = (d, fill, extra = "") => `<path d="${d}" fill="${fill}" stroke="${INK}" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" ${extra}/>`;
    const line = (d, w2 = 2, col = INK, op = 1) => `<path d="${d}" fill="none" stroke="${col}" stroke-width="${w2}" stroke-linecap="round" stroke-linejoin="round" opacity="${op}"/>`;
    const parts = [];

    // Head geometry: top of skull ~y42, widest at y88, chin ~130.
    const headTop = 26;  // bezier control height for the skull
    const headPath = `M${cx - w} 88 C${cx - w} ${headTop} ${cx + w} ${headTop} ${cx + w} 88 C${cx + w} 110 ${cx + jaw} 122 ${cx} ${chin} C${cx - jaw} 122 ${cx - w} 110 ${cx - w} 88 Z`;
    // Hair helper: an outer shell slightly bigger than the skull, and a hairline drawn across the forehead.
    // vol = extra volume above the head, side = how far down the sides it reaches, line = the forehead hairline path (right temple -> left temple)
    const hairShape = (vol, side, hairline, widen = 3) =>
      `M${cx - w - widen} ${side} C${cx - w - widen - 2} ${headTop - vol} ${cx + w + widen + 2} ${headTop - vol} ${cx + w + widen} ${side} L${cx + w - 1} ${side} ${hairline} L${cx - w - widen} ${side} Z`;
    const hairStyle = sex === "m"
      ? pick(r, old > 0.6 ? ["bald", "receding", "receding", "side", "swept", "full"] : ["side", "swept", "full", "receding"])
      : pick(r, ["bob", "bob", "coif", "bun", "shoulder", "short"]);

    // ---------- behind the head: long hair and buns ----------
    if (hairStyle === "bob") parts.push(s(`M${cx - w - 8} 80 C${cx - w - 14} 30 ${cx + w + 14} 30 ${cx + w + 8} 80 C${cx + w + 10} 100 ${cx + w + 10} 116 ${cx + w + 4} 126 C${cx + w - 4} 128 ${cx + jaw + 2} 122 ${cx + jaw} 116 L${cx - jaw} 116 C${cx - jaw - 2} 122 ${cx - w + 4} 128 ${cx - w - 4} 126 C${cx - w - 10} 116 ${cx - w - 10} 100 ${cx - w - 8} 80 Z`, hairCol));
    if (hairStyle === "shoulder") parts.push(s(`M${cx - w - 8} 80 C${cx - w - 14} 30 ${cx + w + 14} 30 ${cx + w + 8} 80 C${cx + w + 12} 110 ${cx + w + 16} 140 ${cx + w + 12} 152 C${cx + w} 154 ${cx + w - 6} 146 ${cx + jaw} 120 L${cx - jaw} 120 C${cx - w + 6} 146 ${cx - w} 154 ${cx - w - 12} 152 C${cx - w - 16} 140 ${cx - w - 12} 110 ${cx - w - 8} 80 Z`, hairCol));
    if (hairStyle === "bun") parts.push(`<circle cx="${cx + 4}" cy="34" r="14" fill="${hairCol}" stroke="${INK}" stroke-width="2.4"/>`);

    // ---------- body: jacket, shirt or blouse ----------
    const suit = sex === "m" ? pick(r, SUITS) : pick(r, BLAZERS);
    const suitD = shade(suit, -0.3);
    const shirt = sex === "m" ? pick(r, SHIRTS) : pick(r, BLOUSES);
    parts.push(s("M8 210 C12 170 40 150 72 144 L128 144 C160 150 188 170 192 210 Z", suit));
    parts.push(s(`M${cx - 15} 116 L${cx - 15} 144 C${cx - 6} 152 ${cx + 6} 152 ${cx + 15} 144 L${cx + 15} 116 Z`, skinD)); // neck
    if (sex === "m") {
      parts.push(s("M84 144 L100 176 L116 144 L108 140 L100 150 L92 140 Z", shirt));
      const tie = pick(r, TIES);
      parts.push(s("M95 148 L105 148 L103 157 L97 157 Z", tie));
      parts.push(s("M97 157 L103 157 L108 190 L100 196 L92 190 Z", tie));
      parts.push(s("M92 140 L100 150 L96 160 L86 146 Z", shirt) + s("M108 140 L100 150 L104 160 L114 146 Z", shirt));
    } else {
      const neckline = pick(r, ["v", "round", "bow"]);
      if (neckline === "round") parts.push(s("M84 145 C90 166 110 166 116 145 Z", shirt));
      else parts.push(s("M83 144 L100 178 L117 144 L110 142 L100 160 L90 142 Z", shirt));
      if (neckline === "bow") parts.push(s("M100 154 L88 148 L88 162 Z", shirt) + s("M100 154 L112 148 L112 162 Z", shirt));
      if (r() < 0.6) {
        const pearls = [];
        for (let i = 0; i <= 8; i++) { const t = i / 8; const x = 87 + 26 * t; const y = 145 + Math.sin(t * Math.PI) * 9; pearls.push(`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="2.2" fill="#f6f3ea" stroke="${INK}" stroke-width="1"/>`); }
        parts.push(pearls.join(""));
      }
    }
    parts.push(s("M72 144 L86 144 L101 192 L86 198 L78 172 L70 162 Z", suitD));   // lapels
    parts.push(s("M128 144 L114 144 L99 192 L114 198 L122 172 L130 162 Z", suitD));
    parts.push(`<circle cx="121" cy="160" r="4.2" fill="${pin}" stroke="${INK}" stroke-width="1.6"/>`); // party pin

    // ---------- head ----------
    parts.push(s(`M${cx - w + 1} 90 C${cx - w - 10} 82 ${cx - w - 11} 106 ${cx - w + 2} 106 Z`, skin)); // ears
    parts.push(s(`M${cx + w - 1} 90 C${cx + w + 10} 82 ${cx + w + 11} 106 ${cx + w - 2} 106 Z`, skin));
    parts.push(s(headPath, skin));

    // ---------- age lines ----------
    const lineOp = 0.35 + old * 0.45;
    if (old > 0.25) {
      parts.push(line(`M${cx - 9} 99 C${cx - 15} 106 ${cx - 15} 112 ${cx - 11} 116`, 1.6, INK, lineOp));
      parts.push(line(`M${cx + 9} 99 C${cx + 15} 106 ${cx + 15} 112 ${cx + 11} 116`, 1.6, INK, lineOp));
      parts.push(line(`M${cx - w + 5} ${eyeY + 1} l-4 -2 M${cx - w + 5} ${eyeY + 4} l-4 1`, 1.3, INK, lineOp));
      parts.push(line(`M${cx + w - 5} ${eyeY + 1} l4 -2 M${cx + w - 5} ${eyeY + 4} l4 1`, 1.3, INK, lineOp));
    }
    if (old > 0.5 && (hairStyle === "bald" || hairStyle === "receding")) {
      parts.push(line(`M${cx - 13} 62 C${cx - 4} 59 ${cx + 4} 59 ${cx + 13} 62 M${cx - 10} 68 C${cx - 3} 66 ${cx + 3} 66 ${cx + 10} 68`, 1.3, INK, lineOp));
    }
    if (old > 0.55 && sex === "m") parts.push(line(`M${cx - jaw - 1} ${chin - 12} C${cx - jaw + 3} ${chin - 4} ${cx - 9} ${chin - 1} ${cx - 4} ${chin}`, 1.4, INK, lineOp));

    // ---------- hair over the head ----------
    const temples = (y) => `M${cx - w} 72 C${cx - w - 4} 80 ${cx - w - 4} 92 ${cx - w + 1} 96 C${cx - w + 3} 88 ${cx - w + 3} 80 ${cx - w + 3} ${y} Z M${cx + w} 72 C${cx + w + 4} 80 ${cx + w + 4} 92 ${cx + w - 1} 96 C${cx + w - 3} 88 ${cx + w - 3} 80 ${cx + w - 3} ${y} Z`;
    if (hairStyle === "bald") {
      parts.push(s(temples(70), hairCol));
    } else if (hairStyle === "receding") {
      parts.push(s(temples(66), hairCol));
      // thin band over the crown with deep "M" shaped hairline
      parts.push(s(`M${cx - w - 2} 74 C${cx - w - 3} ${headTop - 2} ${cx + w + 3} ${headTop - 2} ${cx + w + 2} 74 C${cx + w - 6} 62 ${cx + 14} 48 ${cx + 6} 54 C${cx + 2} 50 ${cx - 2} 50 ${cx - 6} 54 C${cx - 14} 48 ${cx - w + 6} 62 ${cx - w - 2} 74 Z`, hairCol));
    } else if (hairStyle === "side") {
      parts.push(s(hairShape(4, 86, `C${cx + w - 2} 70 ${cx + 10} 60 ${cx - 8} 60 C${cx - 18} 60 ${cx - w + 2} 66 ${cx - w + 1} 86`), hairCol));
      parts.push(line(`M${cx - 12} 40 C${cx - 14} 46 ${cx - 15} 52 ${cx - 16} 58`, 1.6, hairD));
    } else if (hairStyle === "swept") {
      parts.push(s(hairShape(10, 84, `C${cx + w - 3} 66 ${cx + 14} 56 ${cx} 56 C${cx - 14} 56 ${cx - w + 3} 66 ${cx - w + 1} 84`), hairCol));
      parts.push(line(`M${cx - 20} 48 C${cx - 6} 40 ${cx + 8} 40 ${cx + 22} 48 M${cx - 16} 54 C${cx - 4} 48 ${cx + 6} 48 ${cx + 18} 54`, 1.3, hairD));
    } else if (hairStyle === "full") {
      parts.push(s(hairShape(6, 88, `C${cx + w - 2} 72 ${cx + 16} 60 ${cx} 61 C${cx - 16} 60 ${cx - w + 2} 72 ${cx - w + 1} 88`), hairCol));
    } else if (hairStyle === "bob" || hairStyle === "shoulder") {
      // side-swept fringe across the forehead
      parts.push(s(hairShape(8, 96, `C${cx + w - 4} 72 ${cx + 18} 58 ${cx + 2} 60 C${cx - 10} 62 ${cx - w + 4} 74 ${cx - w + 1} 96`, 6), hairCol));
      parts.push(line(`M${cx + 6} 40 C${cx + 4} 48 ${cx + 6} 54 ${cx + 10} 60`, 1.4, hairD));
    } else if (hairStyle === "coif") {
      parts.push(s(hairShape(22, 92, `C${cx + w - 4} 70 ${cx + 16} 58 ${cx} 60 C${cx - 16} 58 ${cx - w + 4} 70 ${cx - w + 1} 92`, 8), hairCol));
      parts.push(line(`M${cx - 22} 40 C${cx - 8} 30 ${cx + 8} 30 ${cx + 22} 40 M${cx - 14} 50 C${cx - 4} 44 ${cx + 6} 44 ${cx + 16} 50`, 1.4, hairD));
    } else if (hairStyle === "bun") {
      parts.push(s(hairShape(4, 84, `C${cx + w - 3} 68 ${cx + 14} 58 ${cx} 58 C${cx - 14} 58 ${cx - w + 3} 68 ${cx - w + 1} 84`), hairCol));
      parts.push(line(`M${cx - 18} 50 C${cx - 6} 44 ${cx + 6} 44 ${cx + 18} 50`, 1.3, hairD));
    } else if (hairStyle === "short") {
      parts.push(s(hairShape(8, 86, `C${cx + w - 3} 68 ${cx + 20} 56 ${cx + 4} 58 C${cx - 8} 60 ${cx - 16} 64 ${cx - w + 1} 86`, 4), hairCol));
      parts.push(line(`M${cx - 6} 40 C${cx + 4} 46 ${cx + 12} 52 ${cx + 22} 56`, 1.4, hairD));
    }

    // ---------- face ----------
    const browCol = grey ? shade(hairCol, -0.35) : hairD;
    const browW = sex === "m" ? 3.6 : 2.4;
    const browTilt = (r() - 0.5) * 4;
    parts.push(line(`M${cx - 21} ${browY + browTilt} C${cx - 15} ${browY - 4} ${cx - 9} ${browY - 3} ${cx - 5} ${browY}`, browW, browCol));
    parts.push(line(`M${cx + 21} ${browY + browTilt} C${cx + 15} ${browY - 4} ${cx + 9} ${browY - 3} ${cx + 5} ${browY}`, browW, browCol));
    // eyes with heavy lids for older faces
    for (const dx of [-13, 13]) {
      parts.push(`<ellipse cx="${cx + dx}" cy="${eyeY}" rx="3" ry="${2.6 - old * 0.6}" fill="${INK}"/>`);
      parts.push(line(`M${cx + dx - 6} ${eyeY - 2} C${cx + dx - 2} ${eyeY - 5} ${cx + dx + 2} ${eyeY - 5} ${cx + dx + 6} ${eyeY - 2}`, 1.6));
      if (old > 0.3) parts.push(line(`M${cx + dx - 5} ${eyeY + 5} C${cx + dx - 1} ${eyeY + 7} ${cx + dx + 2} ${eyeY + 7} ${cx + dx + 5} ${eyeY + 5}`, 1.2, INK, lineOp));
    }
    // nose
    const noseL = 12 + r() * 6;
    parts.push(line(`M${cx - 2} ${eyeY + 2} C${cx - 3} ${eyeY + noseL - 4} ${cx - 7} ${eyeY + noseL} ${cx - 4} ${eyeY + noseL + 2} C${cx - 1} ${eyeY + noseL + 4} ${cx + 3} ${eyeY + noseL + 3} ${cx + 5} ${eyeY + noseL}`, 2));
    // mouth: politician's practised expression
    const mouthY = Math.min(eyeY + noseL + 12, chin - 12);
    const mood = pick(r, ["smile", "smile", "stern", "smirk"]);
    const lip = sex === "f" && r() < 0.7 ? pick(r, ["#a3414a", "#b85a5a", "#8e3b46"]) : null;
    if (mood === "smile") parts.push(lip ? s(`M${cx - 10} ${mouthY} C${cx - 4} ${mouthY + 6} ${cx + 4} ${mouthY + 6} ${cx + 10} ${mouthY} C${cx + 4} ${mouthY + 2} ${cx - 4} ${mouthY + 2} ${cx - 10} ${mouthY} Z`, lip) : line(`M${cx - 10} ${mouthY} C${cx - 4} ${mouthY + 6} ${cx + 4} ${mouthY + 6} ${cx + 10} ${mouthY}`, 2.2));
    if (mood === "stern") parts.push(lip ? s(`M${cx - 9} ${mouthY + 1} C${cx - 3} ${mouthY - 1} ${cx + 3} ${mouthY - 1} ${cx + 9} ${mouthY + 1} C${cx + 3} ${mouthY + 3} ${cx - 3} ${mouthY + 3} ${cx - 9} ${mouthY + 1} Z`, lip) : line(`M${cx - 9} ${mouthY + 1} C${cx - 3} ${mouthY - 1} ${cx + 3} ${mouthY - 1} ${cx + 9} ${mouthY + 1}`, 2.2));
    if (mood === "smirk") parts.push(lip ? s(`M${cx - 9} ${mouthY + 1} C${cx - 2} ${mouthY + 2} ${cx + 5} ${mouthY + 1} ${cx + 10} ${mouthY - 3} C${cx + 4} ${mouthY + 4} ${cx - 3} ${mouthY + 4} ${cx - 9} ${mouthY + 1} Z`, lip) : line(`M${cx - 9} ${mouthY + 1} C${cx - 2} ${mouthY + 2} ${cx + 5} ${mouthY + 1} ${cx + 10} ${mouthY - 3}`, 2.2));
    // moustache, quite common among Cranebonian men
    if (sex === "m" && r() < 0.4) {
      const mc = grey ? pick(r, GREYS) : hairCol;
      parts.push(s(`M${cx - 13} ${mouthY - 1} C${cx - 10} ${mouthY - 9} ${cx - 3} ${mouthY - 8} ${cx} ${mouthY - 6} C${cx + 3} ${mouthY - 8} ${cx + 10} ${mouthY - 9} ${cx + 13} ${mouthY - 1} C${cx + 6} ${mouthY - 4} ${cx - 6} ${mouthY - 4} ${cx - 13} ${mouthY - 1} Z`, mc));
    }
    // earrings
    if (sex === "f" && r() < 0.7) {
      parts.push(`<circle cx="${cx - w - 3}" cy="107" r="3" fill="${pick(r, ["#d8b45a", "#f6f3ea"])}" stroke="${INK}" stroke-width="1.2"/>`);
      parts.push(`<circle cx="${cx + w + 3}" cy="107" r="3" fill="${pick(r, ["#d8b45a", "#f6f3ea"])}" stroke="${INK}" stroke-width="1.2"/>`);
    }
    // glasses
    if (glasses) {
      const gf = `fill="#ffffff" fill-opacity="0.18" stroke="${INK}" stroke-width="2.2"`;
      if (glasses === "rect") parts.push(`<rect x="${cx - 22}" y="${eyeY - 7}" width="17" height="13" rx="3" ${gf}/><rect x="${cx + 5}" y="${eyeY - 7}" width="17" height="13" rx="3" ${gf}/>`);
      if (glasses === "round") parts.push(`<circle cx="${cx - 13}" cy="${eyeY}" r="8.5" ${gf}/><circle cx="${cx + 13}" cy="${eyeY}" r="8.5" ${gf}/>`);
      if (glasses === "half") parts.push(line(`M${cx - 22} ${eyeY + 1} L${cx - 5} ${eyeY + 1} L${cx - 7} ${eyeY + 7} L${cx - 20} ${eyeY + 7} Z M${cx + 22} ${eyeY + 1} L${cx + 5} ${eyeY + 1} L${cx + 7} ${eyeY + 7} L${cx + 20} ${eyeY + 7} Z`, 2));
      parts.push(line(`M${cx - 5} ${eyeY - 1} C${cx - 2} ${eyeY - 3} ${cx + 2} ${eyeY - 3} ${cx + 5} ${eyeY - 1} M${cx - 22} ${eyeY - 2} L${cx - w} ${eyeY - 4} M${cx + 22} ${eyeY - 2} L${cx + w} ${eyeY - 4}`, 1.8));
    }
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="24 22 152 152">${parts.join("")}</svg>`;
  }
  return { drawPortrait };
})();
if (typeof module !== "undefined") module.exports = Portraits;
