// =====================================================================
// crises.js — the five major crises. Exactly one happens per game, in
// the second year. Each starts at 20%; your campaign can push one to 40%
// at most (see CONFIG and crisisOdds in world.js). Choices push crises
// with `crisis: { id: amount }` in their effects.
//
// onStart  lasting changes when the crisis begins (state of the nation,
//          permSal = what the country argues about from now on, trust,
//          rival stability)
// phases   the crisis events, with the month they arrive after the start
// =====================================================================
"use strict";

const CRISES = [
  { id: "insurgency", name: "The Alinni insurgency",
    blurb: "Alinnian separatists turn to violence.",
    onStart: { world: { unrest: 20, border: 15 }, permSal: { war: 0.3, nat: 0.4 }, trust: -6, stability: { apv: -25 } },
    phases: [{ month: 0, event: "crisis_insurgency_1" }, { month: 2, event: "crisis_insurgency_2" }, { month: 5, event: "crisis_insurgency_3" }] },
  { id: "james", name: "Bordon invades James",
    blurb: "The Federation attacks James. Cranebonistan can only send supplies.",
    onStart: { world: { border: 25, prices: 8, jobs: -4 }, permSal: { war: 0.5 }, trust: -3, stability: { nup: -10 } },
    phases: [{ month: 0, event: "crisis_james_1" }, { month: 2, event: "crisis_james_2" }, { month: 5, event: "crisis_james_3" }] },
  { id: "economy", name: "The Great Contraction",
    blurb: "A global economic crisis reaches Cranebonistan.",
    onStart: { world: { jobs: -22, prices: 15, migration: -10 }, permSal: { econ: 0.5, labor: 0.3 }, trust: -10, stability: { nup: -15, oc: -10 } },
    phases: [{ month: 0, event: "crisis_economy_1" }, { month: 2, event: "crisis_economy_2" }, { month: 4, event: "crisis_economy_3" }] },
  { id: "terror", name: "The Black Wheat attacks",
    blurb: "Ultranationalists terrorise minority communities.",
    onStart: { world: { unrest: 18 }, permSal: { nat: 0.4, immig: 0.3 }, trust: -8, stability: { apv: -5 } },
    phases: [{ month: 0, event: "crisis_terror_1" }, { month: 2, event: "crisis_terror_2" }, { month: 4, event: "crisis_terror_3" }] },
  { id: "expansion", name: "Drums of war",
    blurb: "Cranebonistan postures for war with the Southern Trueants.",
    onStart: { world: { border: 30, prices: 5 }, permSal: { war: 0.5, nat: 0.3 }, trust: 4, stability: { nup: 15 } },
    phases: [{ month: 0, event: "crisis_expansion_1" }, { month: 2, event: "crisis_expansion_2" }, { month: 5, event: "crisis_expansion_3" }] },
];

const cg = (who, amt) => ({ who, amt });
EVENTS.push(
  // ---------- The Alinni insurgency ----------
  { id: "crisis_insurgency_1", kind: "crisis", deck: false, crisisStart: true, title: "Bombing in Alinni",
    text: "A group calling itself Free Alinni has bombed a police station in the regional capital. Nine people are dead. The country is in shock.",
    government: { text: "The government declares a state of emergency in Alinni." },
    choices: [
      { label: "Demand a crackdown and a ban on the APV", effects: { shift: { war: -12, nat: -10, rev: 6 }, stability: { apv: -15 }, awareness: 0.06, blame: "the Alinnian minority",
        goodwill: [cg({ lean: { nat: "<-30" } }, 0.6), cg({ nationality: "alinnian" }, -1.2), cg({ class: "middle" }, -0.1)] } },
      { label: "Condemn the violence and call for calm", effects: { goodwill: [cg({ class: "middle" }, 0.3), cg({ nationality: "alinnian" }, 0.3), cg({ lean: { nat: "<-30" } }, -0.3)] } },
      { label: "Call for talks with moderate Alinnian leaders", effects: { shift: { war: 10, nat: 8 },
        goodwill: [cg({ nationality: "alinnian" }, 0.5), cg({ lean: { nat: "<-30" } }, -0.6), cg({ lean: { war: "<-25" } }, -0.3)] } },
    ] },
  { id: "crisis_insurgency_2", kind: "crisis", deck: false, title: "Curfew and mass arrests in Alinni",
    text: "Two thousand Alinnians have been arrested under the emergency laws. Most have not been charged with anything.",
    government: { text: "The Interior Minister says the arrests are \"saving lives\"." },
    world: { unrest: 5 },
    choices: [
      { label: "Back the curfew", effects: { shift: { war: -6, rev: 6 }, goodwill: [cg({ lean: { nat: "<-30" } }, 0.3), cg({ nationality: "alinnian" }, -0.7), cg({ lean: { rev: "<-15" } }, -0.2)] } },
      { label: "Demand that courts review every arrest", effects: { shift: { rev: -4, prog: -6 }, goodwill: [cg({ nationality: "alinnian" }, 0.4), cg({ lean: { prog: "<-25" } }, 0.25), cg({ lean: { nat: "<-30" } }, -0.35)] } },
      { label: "Blame the government for letting it happen", effects: { shift: { rev: -8 }, goodwill: [cg({ loyalTo: "nup" }, -0.3), cg({ region: "alinni" }, 0.15)] } },
    ] },
  { id: "crisis_insurgency_3", kind: "crisis", deck: false, title: "The Free Alinni commander is caught",
    text: "Police have arrested the man behind the bombing campaign. The trial will be the biggest in Cranebonian history.",
    world: { unrest: -6, border: -5 },
    choices: [
      { label: "Demand the harshest possible sentence", effects: { shift: { prog: 10 }, goodwill: [cg({ lean: { nat: "<-30" } }, 0.4), cg({ lean: { prog: "<-25" } }, -0.4), cg({ nationality: "alinnian" }, -0.5)] } },
      { label: "Call for a fair trial and a reconciliation commission", effects: { shift: { nat: 6 }, goodwill: [cg({ nationality: "alinnian" }, 0.35), cg({ class: "middle" }, 0.15), cg({ lean: { nat: "<-30" } }, -0.3)] } },
      { label: "Take credit for pushing the government to act", effects: { shift: { rev: -2 }, awareness: 0.06, goodwill: [cg({ loyalTo: "nup" }, -0.15), cg({ lean: { nat: "<-25" } }, 0.1)] } },
    ] },

  // ---------- Bordon invades James ----------
  { id: "crisis_james_1", kind: "crisis", deck: false, crisisStart: true, title: "Bordon tanks cross into James",
    text: "The Bordon Federation has invaded James. The generalissimo says he is \"reuniting the family\". James begs Cranebonistan for help.",
    government: { text: "The government says the army is not ready for war and will send only supplies and ammunition." },
    choices: [
      { label: "Demand that troops be sent anyway", effects: { shift: { war: -15 }, awareness: 0.05, goodwill: [cg({ lean: { war: "<-25" } }, 0.6), cg({ lean: { war: ">15" } }, -0.6), cg({ class: "middle" }, -0.15)] } },
      { label: "Back supplies-only as the wise choice", effects: { shift: { war: 6 }, goodwill: [cg({ lean: { war: ">15" } }, 0.3), cg({ lean: { war: "<-25" } }, -0.4)] } },
      { label: "Blame the government for a hollow army", effects: { shift: { war: -6, rev: -6 }, goodwill: [cg({ loyalTo: "nup" }, -0.35), cg({ lean: { war: "<-25" } }, 0.3)] } },
    ] },
  { id: "crisis_james_2", kind: "crisis", deck: false, title: "Refugees from James reach Erland",
    text: "James's capital is under siege. Thirty thousand refugees are walking north into Erland's border towns.",
    world: { migration: 8 },
    choices: [
      { label: "Open Erland's towns to them", effects: { shift: { immig: -8 }, goodwill: [cg({ region: "erland" }, -0.2), cg({ lean: { prog: "<-25" } }, 0.3), cg({ lean: { immig: ">35" } }, -0.3)] } },
      { label: "Demand camps at the border", effects: { shift: { immig: 8 }, goodwill: [cg({ lean: { immig: ">30" } }, 0.35), cg({ region: "erland" }, 0.2), cg({ lean: { prog: "<-25" } }, -0.3)] } },
      { label: "Demand a ban on Bordon grain", effects: { shift: { econ: 6, war: -4 }, world: { prices: 3 }, goodwill: [cg({ region: "erland" }, 0.25), cg({ lean: { war: "<-25" } }, 0.15)] } },
    ] },
  { id: "crisis_james_3", kind: "crisis", deck: false, title: "Ceasefire: James loses its mining valleys",
    text: "A ceasefire has been signed. Bordon keeps the valleys where most of James's rare materials are mined.",
    world: { border: -12, prices: 4 },
    choices: [
      { label: "Call it a national humiliation", effects: { shift: { nat: -10 }, trust: -4, goodwill: [cg({ lean: { nat: "<-30" } }, 0.5), cg({ loyalTo: "nup" }, -0.3)] } },
      { label: "Call it the least bad outcome", effects: { shift: { war: 8 }, goodwill: [cg({ class: "middle" }, 0.2), cg({ lean: { nat: "<-30" } }, -0.35)] } },
      { label: "Demand Cranebonian guards for the remaining mines", effects: { shift: { war: -8, labor: 6 }, goodwill: [cg({ class: "upper" }, 0.3), cg({ lean: { war: ">25" } }, -0.3)] } },
    ] },

  // ---------- The Great Contraction ----------
  { id: "crisis_economy_1", kind: "crisis", deck: false, crisisStart: true, title: "Golban banks collapse; the Pezo is in free fall",
    text: "Three of Golba's biggest banks have failed in a week. Cranebonian savings are evaporating and queues are forming outside banks in Cranebo.",
    government: { text: "The government closes the banks for three days \"to restore calm\"." },
    choices: [
      { label: "Demand capital controls and nationalised banks", effects: { shift: { econ: 15, rev: -6 }, goodwill: [cg({ lean: { econ: ">25" } }, 0.5), cg({ class: "upper" }, -0.7), cg({ class: "working" }, 0.2)] } },
      { label: "Demand spending cuts to calm the markets", effects: { shift: { gov: -12, econ: -8 }, goodwill: [cg({ class: "upper" }, 0.4), cg({ class: "working" }, -0.6), cg({ age: "61+" }, -0.3)] } },
      { label: "Blame foreign speculators", effects: { shift: { nat: -8 }, trust: -3, blame: "foreign speculators", goodwill: [cg({ lean: { nat: "<-30" } }, 0.4), cg({ class: "middle" }, -0.1)] } },
    ] },
  { id: "crisis_economy_2", kind: "crisis", deck: false, title: "Factories close across Cranbia",
    text: "A hundred and twenty thousand jobs have gone in two months. Whole towns in Cranbia's industrial belt have nothing left.",
    world: { jobs: -5, unrest: 8 },
    choices: [
      { label: "Demand the state take over the factories", effects: { shift: { econ: 12, gov: 8 }, goodwill: [cg({ region: "cranbia", class: "working" }, 0.5), cg({ class: "upper" }, -0.5)] } },
      { label: "Demand tax cuts to save businesses", effects: { shift: { gov: -10 }, goodwill: [cg({ class: "upper" }, 0.4), cg({ class: "working" }, -0.3)] } },
      { label: "Demand jobs for Cranebonians first", effects: { shift: { immig: 10, nat: -6 }, blame: "immigrants", crisis: {}, goodwill: [cg({ class: "working", nationality: "cranebonian" }, 0.4), cg({ nationality: "norbanian" }, -0.8), cg({ lean: { prog: "<-25" } }, -0.3)] } },
    ] },
  { id: "crisis_economy_3", kind: "crisis", deck: false, title: "Bread riots in Yamlin",
    text: "Food prices have doubled. Crowds looted warehouses in Yamlin overnight, and the army is on the streets.",
    world: { unrest: 6, prices: -4 },
    choices: [
      { label: "Demand price controls on food", effects: { shift: { econ: 10 }, goodwill: [cg({ class: "working" }, 0.35), cg({ class: "upper" }, -0.3)] } },
      { label: "Demand the army restore order", effects: { shift: { rev: 10, war: -4 }, goodwill: [cg({ age: "61+" }, 0.3), cg({ lean: { rev: "<-15" } }, -0.4), cg({ age: "18-29" }, -0.3)] } },
      { label: "March with the hungry", effects: { shift: { rev: -10 }, awareness: 0.07, goodwill: [cg({ lean: { rev: "<-15" } }, 0.45), cg({ class: "middle" }, -0.35)] } },
    ] },

  // ---------- The Black Wheat ----------
  { id: "crisis_terror_1", kind: "crisis", deck: false, crisisStart: true, echo: true, title: "Arson attack on an Alinnian community centre",
    text: "Six people died when a group calling itself the Black Wheat set fire to an Alinnian community centre in Cranbia. Nationalist slogans were painted on the walls.",
    government: { text: "The prime minister calls it \"a tragedy\" but avoids the word terrorism." },
    choices: [
      { label: "Condemn it clearly and visit the families", effects: { shift: { nat: 6 }, goodwill: [cg({ nationality: "alinnian" }, 0.5), cg({ class: "middle" }, 0.3), cg({ lean: { nat: "<-40" } }, -0.3)] } },
      { label: "Condemn it, but say the anger is understandable", effects: { shift: { nat: -4 }, goodwill: [cg({ lean: { nat: "<-35" } }, 0.3), cg({ class: "middle" }, -0.4), cg({ nationality: "alinnian" }, -0.6)] } },
      { label: "Suggest foreign provocateurs did it", effects: { shift: { rev: -4 }, trust: -3, goodwill: [cg({ lean: { nat: "<-30" } }, 0.15), cg({ class: "middle" }, -0.25), cg({ nationality: "alinnian" }, -0.3)] } },
    ] },
  { id: "crisis_terror_2", kind: "crisis", deck: false, title: "The Black Wheat attacks a Norbanian shelter",
    text: "A shelter for Norbanian refugees in Yamlin was firebombed overnight. Nobody died, but the message is clear.",
    world: { unrest: 5 },
    choices: [
      { label: "Demand the Black Wheat be declared terrorists", effects: { shift: { rev: 4, nat: 4 }, goodwill: [cg({ class: "middle" }, 0.3), cg({ nationality: "norbanian" }, 0.4), cg({ lean: { nat: "<-40" } }, -0.35)] } },
      { label: "Say there are extremists on both sides", effects: { goodwill: [cg({ lean: { nat: "<-30" } }, 0.2), cg({ class: "middle" }, -0.2), cg({ nationality: "norbanian" }, -0.5), cg({ nationality: "alinnian" }, -0.3)] } },
      { label: "Say nothing", effects: { awareness: 0, goodwill: [cg({ nationality: "norbanian" }, -0.3), cg({ class: "middle" }, -0.15)] } },
    ] },
  { id: "crisis_terror_3", kind: "crisis", deck: false, echo: true, title: "Black Wheat leaders arrested",
    text: "Police have arrested the Black Wheat's leaders. Newspapers have found photographs of one of them at your rallies.",
    world: { unrest: -6 },
    choices: [
      { label: "Apologise and tighten who can join your rallies", effects: { leader: -0.1, goodwill: [cg({ class: "middle" }, 0.2), cg({ lean: { rev: "<-15" } }, -0.15)] } },
      { label: "Say you never met him", effects: { leader: -0.15, awareness: 0.05, goodwill: [cg({ class: "middle" }, -0.1)] } },
      { label: "Accuse the police of targeting patriots", effects: { shift: { nat: -8, rev: -6 }, trust: -4, goodwill: [cg({ lean: { nat: "<-40" } }, 0.4), cg({ class: "middle" }, -0.6)] } },
    ] },

  // ---------- Drums of war ----------
  { id: "crisis_expansion_1", kind: "crisis", deck: false, crisisStart: true, title: "Troops mass on the Trueant border",
    text: "The government has moved three divisions to the border. The prime minister speaks of \"historic lands\" south of Alinni. Crowds wave flags in Cranebo.",
    government: { text: "The prime minister says Cranebonistan \"will not apologise for its history\"." },
    choices: [
      { label: "Join the chorus", effects: { shift: { war: -12, nat: -10 }, goodwill: [cg({ lean: { nat: "<-30" } }, 0.5), cg({ lean: { war: "<-20" } }, 0.4), cg({ lean: { war: ">20" } }, -0.5), cg({ nationality: "alinnian" }, -0.6)] } },
      { label: "Warn against a war nobody can win", effects: { shift: { war: 12 }, goodwill: [cg({ lean: { war: ">20" } }, 0.5), cg({ lean: { nat: "<-30" } }, -0.5), cg({ loyalTo: "nup" }, -0.2)] } },
      { label: "Say the government is using war to hide its failures", effects: { shift: { rev: -6 }, goodwill: [cg({ loyalTo: "nup" }, -0.3), cg({ age: "18-29" }, 0.2), cg({ lean: { rev: "<-15" } }, 0.25)] } },
    ] },
  { id: "crisis_expansion_2", kind: "crisis", deck: false, title: "Four soldiers killed in a border clash",
    text: "Four Cranebonian soldiers died in an exchange of fire with Trueant troops. Their funerals are on every channel.",
    world: { border: 8 },
    choices: [
      { label: "Demand retaliation", effects: { shift: { war: -10 }, world: { border: 6 }, goodwill: [cg({ lean: { war: "<-20" } }, 0.5), cg({ age: "61+" }, 0.2), cg({ lean: { war: ">20" } }, -0.5)] } },
      { label: "Demand a ceasefire and talks", effects: { shift: { war: 10 }, goodwill: [cg({ lean: { war: ">20" } }, 0.4), cg({ lean: { nat: "<-30" } }, -0.6)] } },
      { label: "Attend the funerals in silence", effects: { leader: 0.2, goodwill: [cg({ class: "middle" }, 0.15)] } },
    ] },
  { id: "crisis_expansion_3", kind: "crisis", deck: false, title: "Golba brokers a deal; the government claims victory",
    text: "Under Golban pressure, both sides have pulled back. The government says Cranebonistan \"stood tall\". Not a metre of land has changed hands.",
    world: { border: -15 },
    choices: [
      { label: "Say the government won nothing", effects: { shift: { nat: -6 }, goodwill: [cg({ lean: { nat: "<-30" } }, 0.3), cg({ loyalTo: "nup" }, -0.25)] } },
      { label: "Welcome the peace", effects: { shift: { war: 6 }, goodwill: [cg({ lean: { war: ">20" } }, 0.3), cg({ class: "middle" }, 0.2)] } },
      { label: "Say next time it should be finished properly", effects: { shift: { war: -10, nat: -8 }, goodwill: [cg({ lean: { nat: "<-40" } }, 0.4), cg({ class: "middle" }, -0.4), cg({ lean: { war: ">15" } }, -0.4)] } },
    ] },
);
