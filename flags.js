// =====================================================================
// flags.js — national flags, drawn in code (original designs).
// Each flag is drawn on a 60 × 40 canvas. To redesign one, edit its
// function; the rest of the game only calls flagSVG(id).
// =====================================================================
"use strict";

const FLAG_INFO = {
  cranebonistan: { name: "Cranebonistan", note: "Navy for the northern sea, white for peace, gold for Erland's wheat. The red disc carries the crane that gives the country its name." },
  trueants:      { name: "Southern Trueants", note: "Orange and black, with the single star of the ruling party." },
  dillihan:      { name: "Dillihan Republic", note: "Green for its farmland, the gold star of its republican revolution." },
  bourdeaux:     { name: "Bourdeaux Federation", note: "One star for each of its five nations, held together by the generalissimo's sabre." },
  james:         { name: "James", note: "Wine and gold, under a crown. The people of James have opinions about who the real king is." },
  golba:         { name: "United Federation of Golba", note: "The biggest power in the world and Cranebonistan's main trading partner." },
  norbanistan:   { name: "Norbanistan", note: "The flag of the old state, still flown by every side in its civil war." },
  potania:       { name: "Potania", note: "The violet and silver of the world's biggest buyer of rare materials." },
};

const FLAGS = {
  cranebonistan: () => `
    <rect width="60" height="40" fill="#1f3a5f"/><rect y="13.3" width="60" height="13.4" fill="#f4f1ea"/><rect y="26.7" width="60" height="13.3" fill="#d9a43a"/>
    <circle cx="30" cy="20" r="10.5" fill="#b8332a"/>
    <path d="M24.5 24.5 C26 21.5 29 20.5 31 21 C32 18 32 15.5 33.5 14 C34.6 13 36 13.4 36.2 14.4 L38.5 14.6 L36.4 15.4 C35.2 15.6 34.6 16.6 34.6 18.4 C34.6 21.4 33 24.4 29.5 25 L28 25 L27 29 M29.5 25 L30.4 29" fill="#f4f1ea" stroke="#f4f1ea" stroke-width="0.9" stroke-linejoin="round" stroke-linecap="round"/>`,
  trueants: () => `
    <rect width="60" height="40" fill="#e07b1a"/><rect width="18" height="40" fill="#1d1d1d"/>
    <path d="M9 13 L10.8 18.4 L16.5 18.4 L11.9 21.7 L13.6 27.1 L9 23.8 L4.4 27.1 L6.1 21.7 L1.5 18.4 L7.2 18.4 Z" fill="#f4f1ea"/>`,
  dillihan: () => `
    <rect width="60" height="40" fill="#2f7a4a"/><rect y="16" width="60" height="8" fill="#f4f1ea"/>
    <path d="${star8(30, 20, 9, 4)}" fill="#e3b23c" stroke="#2f7a4a" stroke-width="0.8"/>`,
  bourdeaux: () => `
    <rect width="60" height="40" fill="#7a2338"/>
    ${[0, 1, 2, 3, 4].map((i) => { const a = Math.PI * (1.15 + i * 0.175); return `<path d="${star5(30 + Math.cos(a) * 14, 22 + Math.sin(a) * 14, 2.6)}" fill="#f4f1ea"/>`; }).join("")}
    <path d="M14 30 L44 24 L45 25.5 L15 31.5 Z" fill="#d9a43a"/><path d="M42 23 L46 26.5" stroke="#d9a43a" stroke-width="2" stroke-linecap="round"/>`,
  james: () => `
    <rect width="60" height="40" fill="#6f1d38"/><rect y="25" width="60" height="6" fill="#e2a93b"/>
    <path d="M20 19 L22 9 L26 14 L30 7 L34 14 L38 9 L40 19 Z" fill="#e2a93b"/><rect x="20" y="19" width="20" height="2.6" fill="#e2a93b"/>`,
  golba: () => `
    <rect width="60" height="40" fill="#2b4f9c"/>
    ${[6, 14, 22, 30].map((y) => `<rect y="${y}" width="60" height="3" fill="#f4f1ea"/>`).join("")}
    <rect width="22" height="22" fill="#c8302d"/><path d="${star5(11, 11.5, 7)}" fill="#f4f1ea"/>`,
  norbanistan: () => `
    <rect width="60" height="40" fill="#5b6b7a"/><rect width="60" height="20" fill="#9e2f2a"/>
    <circle cx="30" cy="20" r="8" fill="none" stroke="#f4f1ea" stroke-width="2.4"/>
    ${[0, 1, 2, 3, 4, 5, 6, 7].map((i) => `<rect x="28.6" y="9" width="2.8" height="4" fill="#f4f1ea" transform="rotate(${i * 45} 30 20)"/>`).join("")}
    <circle cx="30" cy="20" r="3" fill="#f4f1ea"/>`,
  potania: () => `
    <rect width="60" height="40" fill="#bfc4cc"/><path d="M0 0 L60 0 L0 40 Z" fill="#5b3a8c"/>
    <path d="M30 10 L38 20 L30 30 L22 20 Z" fill="#f4f1ea" stroke="#5b3a8c" stroke-width="1.2"/><path d="M22 20 L38 20 M30 10 L27 20 L30 30 M30 10 L33 20 L30 30" stroke="#5b3a8c" stroke-width="0.7" fill="none"/>`,
};

function star5(cx, cy, r) {
  let d = "";
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 ? r * 0.42 : r;
    const a = -Math.PI / 2 + i * Math.PI / 5;
    d += `${i ? "L" : "M"}${(cx + Math.cos(a) * rad).toFixed(2)} ${(cy + Math.sin(a) * rad).toFixed(2)} `;
  }
  return d + "Z";
}
function star8(cx, cy, r, r2) {
  let d = "";
  for (let i = 0; i < 16; i++) {
    const rad = i % 2 ? r2 : r;
    const a = -Math.PI / 2 + i * Math.PI / 8;
    d += `${i ? "L" : "M"}${(cx + Math.cos(a) * rad).toFixed(2)} ${(cy + Math.sin(a) * rad).toFixed(2)} `;
  }
  return d + "Z";
}
// A flag as an SVG element. Pass a CSS class to size it.
function flagSVG(id, cls = "flag") {
  const draw = FLAGS[id];
  if (!draw) return "";
  const info = FLAG_INFO[id] || {};
  return `<svg class="${cls}" viewBox="0 0 60 40" role="img" aria-label="Flag of ${info.name || id}"><title>${info.name || id}</title>${draw()}<rect width="60" height="40" fill="none" stroke="rgba(0,0,0,0.35)" stroke-width="1"/></svg>`;
}
