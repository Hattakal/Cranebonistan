// =====================================================================
// initiatives.js — debates you open yourself (the monthly agenda).
// Each month three are offered. Each can be used once per game.
// What you put on the agenda comes back: `seeds` schedules a follow-up
// event some months later. Effects use the same format as events.js.
//   when      makes it more likely to be offered (state of the nation)
//   minMonth  not offered before this month of the campaign
// =====================================================================
"use strict";

const INITIATIVES = [
  { id: "referendum_alinni", title: "Propose a referendum on autonomy for Alinni",
    text: "Let Alinni vote on running its own schools, police and budget.",
    quote: "Let the people of Alinni decide how they want to be governed.",
    effects: { shift: { nat: 12, rev: -4 }, salience: { nat: 0.4 }, world: { border: 2 }, crisis: { insurgency: 1, terror: 1 },
      goodwill: [{ who: { nationality: "alinnian" }, amt: 0.6 }, { who: { lean: { nat: ">25" } }, amt: 0.3 }, { who: { lean: { nat: "<-30" } }, amt: -0.5 }, { who: { region: "alinni", nationality: "cranebonian" }, amt: -0.4 }] },
    seeds: [{ event: "referendum_clashes", months: [2, 4] }] },

  { id: "deport_campaign", title: "Launch a campaign to deport undocumented Norbanians", when: { migration: ">60" },
    text: "Posters, rallies and a petition calling for mass deportations.",
    quote: "If you came here illegally, you will leave legally.",
    effects: { shift: { immig: 14, nat: -6 }, salience: { immig: 0.4 }, world: { migration: -3 }, crisis: { terror: 1.5 }, blame: "Norbanian immigrants",
      goodwill: [{ who: { lean: { immig: ">30" } }, amt: 0.5 }, { who: { nationality: "norbanian" }, amt: -1.0 }, { who: { region: "yamlin", class: "upper" }, amt: -0.3 }, { who: { lean: { prog: "<-30" } }, amt: -0.3 }] },
    seeds: [{ event: "dock_raids", months: [2, 3] }] },

  { id: "wealth_tax", title: "Propose a one-off tax on the 500 richest families",
    text: "A single levy on the country's biggest fortunes, to pay for schools and hospitals.",
    quote: "Five hundred families own half of Cranebonistan. They can spare a little of it.",
    effects: { shift: { econ: 12, labor: -8 }, salience: { econ: 0.3 },
      goodwill: [{ who: { class: "working" }, amt: 0.45 }, { who: { class: "upper" }, amt: -0.8 }, { who: { lean: { econ: ">25" } }, amt: 0.3 }] },
    seeds: [{ event: "capital_flight", months: [1, 3] }] },

  { id: "bigger_army", title: "Call for doubling the defence budget", when: { border: ">45" },
    text: "A campaign for a stronger army, navy and border guard.",
    quote: "A country that cannot defend itself is a country waiting to be divided.",
    effects: { shift: { war: -14, gov: 5 }, salience: { war: 0.3 }, world: { border: 3 }, crisis: { expansion: 1.5, james: 0.5 },
      goodwill: [{ who: { lean: { war: "<-25" } }, amt: 0.5 }, { who: { lean: { war: ">25" } }, amt: -0.4 }, { who: { region: "alinni", nationality: "cranebonian" }, amt: 0.3 }] },
    seeds: [{ event: "defence_maths", months: [2, 3] }] },

  { id: "trueant_talks", title: "Meet Trueant opposition leaders in secret",
    text: "Quiet talks with the people who may run the Southern Trueants one day.",
    quote: "Peace is made with the next government, not the current one.",
    effects: { shift: { war: 12, nat: 6 }, world: { border: -3 }, crisis: { insurgency: -1, expansion: -1.5 },
      goodwill: [{ who: { lean: { war: ">25" } }, amt: 0.4 }, { who: { nationality: "alinnian" }, amt: 0.4 }, { who: { lean: { nat: "<-30" } }, amt: -0.5 }] },
    seeds: [{ event: "trueant_friend", months: [1, 3] }] },

  { id: "corruption_list", title: "Publish a list of corrupt officials",
    text: "Name names. Your researchers have a list of thirty officials.",
    quote: "Here are the names. Let them sue me.",
    effects: { shift: { rev: -12 }, trust: -5, stability: { nup: -8 }, awareness: 0.08,
      goodwill: [{ who: { lean: { rev: "<-15" } }, amt: 0.5 }, { who: { loyalTo: "nup" }, amt: -0.3 }, { who: { class: "middle" }, amt: -0.1 }] },
    seeds: [{ event: "libel_suit", months: [2, 3] }] },

  { id: "pension_double", title: "Promise to double the state pension", when: { prices: ">50" },
    text: "A simple, enormous promise to every retiree.",
    quote: "They built this country. They should not have to choose between heating and eating.",
    effects: { shift: { gov: 12, econ: 6 },
      goodwill: [{ who: { age: "61+" }, amt: 0.7 }, { who: { age: "46-60" }, amt: 0.3 }, { who: { class: "upper" }, amt: -0.3 }, { who: { lean: { gov: "<-25" } }, amt: -0.4 }] },
    seeds: [{ event: "pension_maths", months: [1, 2] }] },

  { id: "james_pact", title: "Call for a defence pact with James",
    text: "A formal promise to defend James if it is attacked.",
    quote: "James trusted us. A promise to a friend should be written down.",
    effects: { shift: { war: -8 }, world: { border: 3 }, crisis: { james: 2 },
      goodwill: [{ who: { lean: { war: "<-25" } }, amt: 0.35 }, { who: { lean: { war: ">25" } }, amt: -0.25 }] },
    seeds: [{ event: "bourdeaux_warns", months: [1, 2] }] },

  { id: "family_faith", title: "Launch a \"Family and Faith\" campaign",
    text: "Religion back in schools, tax breaks for married couples, and posters of grandparents.",
    quote: "A country that forgets its grandparents' values will not have grandchildren.",
    effects: { shift: { prog: 14 }, salience: { prog: 0.3 },
      goodwill: [{ who: { lean: { prog: ">30" } }, amt: 0.5 }, { who: { age: "61+" }, amt: 0.2 }, { who: { region: "erland" }, amt: 0.2 }, { who: { lean: { prog: "<-25" } }, amt: -0.55 }, { who: { age: "18-29" }, amt: -0.2 }] },
    seeds: [{ event: "teachers_march", months: [2, 3] }] },

  { id: "herder_titles", title: "Promise land titles to Fauraifai's herders", when: { border: ">45" },
    text: "Legal ownership of the grazing lands the nomads have used for centuries.",
    quote: "The land the herds walk on belongs to the people who walk with them.",
    effects: { shift: { gov: 6, nat: -4 }, world: { border: 4 },
      goodwill: [{ who: { region: "fauraifai" }, amt: 0.7 }, { who: { class: "upper" }, amt: -0.1 }] },
    seeds: [{ event: "dillihan_land", months: [2, 3] }] },

  { id: "greater_cranebonistan", title: "Speak of a \"Greater Cranebonistan\" at a rally", minMonth: 6,
    text: "Hint, in front of a big crowd, that the country's borders are not final.",
    quote: "Our grandfathers' maps were bigger than ours. Maybe our grandchildren's will be too.",
    effects: { shift: { nat: -14, war: -10, rev: 6 }, salience: { nat: 0.3, war: 0.3 }, world: { border: 6 }, crisis: { expansion: 2.5, terror: 1 }, awareness: 0.06,
      goodwill: [{ who: { lean: { nat: "<-40" } }, amt: 0.6 }, { who: { lean: { war: ">15" } }, amt: -0.5 }, { who: { nationality: "alinnian" }, amt: -0.6 }, { who: { class: "middle" }, amt: -0.25 }] },
    seeds: [{ event: "trueant_troops", months: [1, 2] }] },

  { id: "buy_cranebonian", title: "Call for a boycott of Golban goods", when: { jobs: "<50" },
    text: "\"Buy Cranebonian\": a national campaign against imports.",
    quote: "Every Golban phone you buy pays a Golban salary. Buy Cranebonian.",
    effects: { shift: { nat: -8, econ: 8 }, world: { prices: 2 }, crisis: { economy: 1.5 },
      goodwill: [{ who: { lean: { nat: "<-25" } }, amt: 0.35 }, { who: { region: "erland" }, amt: 0.25 }, { who: { region: "yamlin", class: "upper" }, amt: -0.45 }] },
    seeds: [{ event: "golba_warns", months: [1, 3] }] },
];

// Follow-up events set off by initiatives.
EVENTS.push(
  { id: "referendum_clashes", kind: "followup", deck: false, title: "Referendum rallies turn violent in Alinni",
    text: "Nationalist counter-protesters attacked a march for your referendum. Forty people are in hospital, and both sides blame you.",
    world: { unrest: 5, border: 2 },
    choices: [
      { label: "Blame the nationalist thugs", effects: { shift: { nat: 4 }, goodwill: [{ who: { nationality: "alinnian" }, amt: 0.3 }, { who: { lean: { nat: "<-30" } }, amt: -0.3 }] } },
      { label: "Condemn violence on both sides", effects: { goodwill: [{ who: { class: "middle" }, amt: 0.15 }] } },
      { label: "Quietly drop the referendum", effects: { shift: { nat: -8 }, goodwill: [{ who: { nationality: "alinnian" }, amt: -0.6 }, { who: { lean: { nat: "<-30" } }, amt: 0.2 }] } },
    ] },
  { id: "dock_raids", kind: "followup", deck: false, title: "Police raids empty Yamlin's docks",
    text: "The government copied your idea. After a week of raids, half the dock workers have vanished and ships are waiting to unload.",
    world: { jobs: -2, migration: -3 },
    choices: [
      { label: "Take the credit: \"We said it first\"", effects: { shift: { immig: 5 }, goodwill: [{ who: { lean: { immig: ">30" } }, amt: 0.3 }, { who: { region: "yamlin", class: "upper" }, amt: -0.4 }] } },
      { label: "Ask for mercy for families with children", effects: { shift: { immig: -6 }, goodwill: [{ who: { nationality: "norbanian" }, amt: 0.3 }, { who: { lean: { immig: ">35" } }, amt: -0.3 }] } },
      { label: "Attack the government for doing it badly", effects: { shift: { rev: -4 }, goodwill: [{ who: { loyalTo: "nup" }, amt: -0.2 }, { who: { region: "yamlin" }, amt: 0.15 }] } },
    ] },
  { id: "capital_flight", kind: "followup", deck: false, title: "The rich move their money to Golba",
    text: "Bankers report record transfers to Golban accounts since your wealth tax proposal. The Pezo dips again.",
    world: { prices: 3 },
    choices: [
      { label: "Call them traitors", effects: { shift: { nat: -4 }, goodwill: [{ who: { class: "working" }, amt: 0.3 }, { who: { class: "upper" }, amt: -0.4 }] } },
      { label: "Soften it to a smaller tax", effects: { shift: { econ: -6 }, goodwill: [{ who: { class: "upper" }, amt: 0.2 }, { who: { class: "working" }, amt: -0.2 }] } },
      { label: "Propose a tax on leaving with your money", effects: { shift: { econ: 6 }, goodwill: [{ who: { lean: { econ: ">25" } }, amt: 0.25 }, { who: { class: "upper" }, amt: -0.3 }] } },
    ] },
  { id: "defence_maths", kind: "followup", deck: false, title: "Generals praise you; economists do the maths",
    text: "Retired generals call your defence plan \"the first serious idea in years\". Economists say it would cost more than every hospital in the country.",
    choices: [
      { label: "Say security has no price", effects: { shift: { war: -4 }, goodwill: [{ who: { lean: { war: "<-25" } }, amt: 0.2 }, { who: { lean: { gov: "<-25" } }, amt: -0.25 }] } },
      { label: "Pay for it with a tax on the rich", effects: { shift: { econ: 6 }, goodwill: [{ who: { class: "working" }, amt: 0.2 }, { who: { class: "upper" }, amt: -0.3 }] } },
      { label: "Quietly halve the figure", effects: { shift: { war: 6 }, goodwill: [{ who: { lean: { war: "<-25" } }, amt: -0.3 }, { who: { class: "middle" }, amt: 0.1 }] } },
    ] },
  { id: "trueant_friend", kind: "followup", deck: false, title: "Trueant TV calls you \"our friend in Craneapolis\"",
    text: "Your secret talks leaked. Trueant state television is praising you, which is the worst thing that could happen to you in Erland.",
    choices: [
      { label: "Laugh it off", effects: { leader: [{ who: { age: "18-29" }, amt: 0.1 }], goodwill: [{ who: { lean: { nat: "<-30" } }, amt: -0.2 }] } },
      { label: "Loudly condemn the Trueant regime", effects: { shift: { war: -6, nat: -4 }, goodwill: [{ who: { lean: { nat: "<-30" } }, amt: 0.2 }, { who: { nationality: "alinnian" }, amt: -0.2 }] } },
      { label: "Defend the talks", effects: { shift: { war: 4 }, goodwill: [{ who: { lean: { war: ">25" } }, amt: 0.25 }, { who: { lean: { nat: "<-30" } }, amt: -0.35 }] } },
    ] },
  { id: "libel_suit", kind: "followup", deck: false, title: "A minister on your list sues you",
    text: "One of the officials you named is suing you for libel, and his lawyers say your evidence is a newspaper clipping and a rumour.",
    choices: [
      { label: "Fight it in court", effects: { shift: { rev: -4 }, money: -3, awareness: 0.06, goodwill: [{ who: { lean: { rev: "<-15" } }, amt: 0.3 }] } },
      { label: "Apologise and settle", effects: { shift: { rev: 6 }, leader: -0.2, goodwill: [{ who: { lean: { rev: "<-15" } }, amt: -0.4 }] } },
      { label: "Say the courts are corrupt too", effects: { shift: { rev: -8 }, trust: -4, goodwill: [{ who: { lean: { rev: "<-20" } }, amt: 0.3 }, { who: { class: "middle" }, amt: -0.35 }] } },
    ] },
  { id: "pension_maths", kind: "followup", deck: false, title: "Economists: your pension promise would bankrupt the state",
    text: "Every major economist in the country has signed a letter saying your pension promise costs a third of the national budget.",
    choices: [
      { label: "Stand by every word", effects: { shift: { gov: 4 }, goodwill: [{ who: { age: "61+" }, amt: 0.2 }, { who: { class: "middle" }, amt: -0.25 }] } },
      { label: "Make it \"double by 2040\"", effects: { shift: { gov: -6 }, goodwill: [{ who: { age: "61+" }, amt: -0.4 }, { who: { class: "middle" }, amt: 0.1 }] } },
      { label: "Say the economists work for Golban banks", effects: { shift: { nat: -5 }, trust: -2, goodwill: [{ who: { lean: { nat: "<-30" } }, amt: 0.2 }, { who: { class: "middle" }, amt: -0.15 }] } },
    ] },
  { id: "bourdeaux_warns", kind: "followup", deck: false, title: "Bourdeaux calls your pact \"a provocation\"",
    text: "The generalissimo's spokesman says any pact with James would be \"a hostile act against the Federation\".",
    world: { border: 4 },
    choices: [
      { label: "Stand firm", effects: { shift: { war: -6 }, crisis: { james: 1 }, goodwill: [{ who: { lean: { war: "<-25" } }, amt: 0.3 }, { who: { class: "middle" }, amt: -0.1 }] } },
      { label: "Reassure Bourdeaux", effects: { shift: { war: 6 }, crisis: { james: -1 }, goodwill: [{ who: { lean: { war: ">20" } }, amt: 0.2 }, { who: { lean: { war: "<-25" } }, amt: -0.2 }] } },
      { label: "Call the generalissimo a dying tyrant", effects: { shift: { war: -8 }, crisis: { james: 1.5 }, awareness: 0.06, goodwill: [{ who: { lean: { nat: "<-30" } }, amt: 0.2 }, { who: { class: "middle" }, amt: -0.2 }] } },
    ] },
  { id: "teachers_march", kind: "followup", deck: false, title: "Teachers march against your curriculum plans",
    text: "Thirty thousand teachers marched through Craneapolis against religion in schools. Several carried your face on a placard.",
    choices: [
      { label: "Back down on the schools part", effects: { shift: { prog: -6 }, goodwill: [{ who: { class: "middle" }, amt: 0.15 }, { who: { lean: { prog: ">30" } }, amt: -0.25 }] } },
      { label: "Call the teachers ideologues", effects: { shift: { prog: 4 }, goodwill: [{ who: { lean: { prog: ">30" } }, amt: 0.25 }, { who: { class: "middle" }, amt: -0.25 }, { who: { age: "18-29" }, amt: -0.2 }] } },
      { label: "Invite them to talks", effects: { goodwill: [{ who: { class: "middle" }, amt: 0.15 }] } },
    ] },
  { id: "dillihan_land", kind: "followup", deck: false, title: "Dillihan: \"Those pastures are Dillihani\"",
    text: "Dillihan's foreign minister says the herders' land you promised to title is Dillihani territory, and has sent surveyors.",
    world: { border: 5 },
    choices: [
      { label: "Insist: not one metre", effects: { shift: { war: -8 }, world: { border: 4 }, goodwill: [{ who: { region: "fauraifai" }, amt: 0.3 }, { who: { lean: { nat: "<-30" } }, amt: 0.2 }] } },
      { label: "Propose a joint border commission", effects: { shift: { war: 6 }, goodwill: [{ who: { lean: { war: ">20" } }, amt: 0.2 }, { who: { region: "fauraifai" }, amt: -0.2 }] } },
      { label: "Blame the government's weakness", effects: { shift: { rev: -5 }, goodwill: [{ who: { loyalTo: "nup" }, amt: -0.2 }, { who: { region: "fauraifai" }, amt: 0.15 }] } },
    ] },
  { id: "trueant_troops", kind: "followup", deck: false, title: "Trueant troops move to the border",
    text: "After your \"Greater Cranebonistan\" speech, the Southern Trueants have moved two divisions to the Alinni border.",
    world: { border: 8 },
    choices: [
      { label: "Double down", effects: { shift: { war: -8, nat: -6 }, crisis: { expansion: 1.5 }, goodwill: [{ who: { lean: { nat: "<-40" } }, amt: 0.3 }, { who: { class: "middle" }, amt: -0.35 }] } },
      { label: "Say you meant the economy", effects: { shift: { nat: 6 }, goodwill: [{ who: { lean: { nat: "<-40" } }, amt: -0.3 }, { who: { class: "middle" }, amt: 0.1 }] } },
      { label: "Blame the media for twisting your words", effects: { shift: { rev: -6 }, trust: -2, goodwill: [{ who: { lean: { rev: "<-15" } }, amt: 0.15 }, { who: { class: "middle" }, amt: -0.1 }] } },
    ] },
  { id: "golba_warns", kind: "followup", deck: false, title: "Golba warns of \"consequences\"",
    text: "Golba's trade secretary says Cranebonistan's boycott campaign \"will not go unanswered\". Yamlin's exporters are panicking.",
    world: { prices: 2 },
    choices: [
      { label: "Defy Golba", effects: { shift: { nat: -6 }, crisis: { economy: 1 }, goodwill: [{ who: { lean: { nat: "<-25" } }, amt: 0.3 }, { who: { class: "upper" }, amt: -0.3 }] } },
      { label: "Say it's only about consumer choice", effects: { shift: { nat: 4 }, goodwill: [{ who: { lean: { nat: "<-25" } }, amt: -0.15 }, { who: { class: "middle" }, amt: 0.1 }] } },
      { label: "Propose friendly trade talks", effects: { shift: { econ: -6 }, goodwill: [{ who: { region: "yamlin" }, amt: 0.2 }, { who: { lean: { nat: "<-30" } }, amt: -0.2 }] } },
    ] },
);
