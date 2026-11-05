// =====================================================================
// data.js — the world of Cranebonistan, as plain data.
// Nothing in this file runs game logic. sim.js reads it.
// To add an axis, region, party or event, you only edit this file.
// Positions on every axis run from -100 (left label) to +100 (right label).
// =====================================================================

const CONFIG = {
  startYear: 2027,
  weeksPerMonth: 4,
  monthsPerYear: 12,
  electionYears: 5,        // election lands in the first week after year 5
  seats: 300,              // seats in the National Assembly

  quarterIncome: 8,        // ₱ millions the player gets every quarter

  startAwareness: 0.12,    // share of "people know who you are" for a new party
  awarenessFloor: 0.10,
  awarenessDecay: 0.985,   // monthly: awareness slowly fades without campaigning
  eventAwareness: 0.02,    // every public statement gets you a little coverage

  distanceScale: 22,       // how much ideological distance matters in a vote
  goodwillDecay: 0.88,     // monthly: voters forget individual statements
  goodwillScale: 0.7,      // multiplies every goodwill effect from events
  salienceDecay: 0.88,     // monthly: hot topics cool down
  perceivedPull: 0.03,     // monthly: your image slowly returns toward your manifesto

  // Stances: every axis is cut into 5 stances at these boundaries.
  stanceBounds: [-60, -20, 20, 60],
  stanceCenters: [-80, -40, 0, 40, 80],
  stepPenalty: [0, 1, 3, 6, 10], // inconsistency for being 0,1,2,3,4 stances off your manifesto
  flipMemoryWeeks: 96,     // stance changes are listed on the Platform tab for two years
  inconsistencyTolerance: 0.5,

  startLoyalty: 0.40,      // share of each pop that is "core" for some party at start
  loyaltyGain: 0.02,       // monthly: share of your floating voters who become core
  loyaltyChurn: 0.006,     // monthly: core voters drifting away naturally
  coreErosion: 0.015,      // monthly core loss per point of inconsistency

  // Leader & cult of personality (barebones)
  leaderWeight: 0.45,      // how much liking the leader adds to a vote
  leaderDecay: 0.95,       // monthly: personal impressions fade slowly
  startCharisma: 50,
  // Devotion (the cult): only voters who like the leader a LOT become devoted.
  devotionStart: 1.0,      // leader opinion (× leader appeal × charisma) where devotion begins
  devotionRange: 0.8,      // ...and how much more is needed for full devotion
  devotionBlind: 0.6,      // a fully devoted voter ignores this share of your positions and flip-flops
  cultPull: 0.015,         // monthly: devoted voters move their own views toward yours
  rivalLeaderWeight: 0.35, // how much a rival leader's charisma matters

  // Trust in the system (0-100). Low trust helps outsiders, hurts the establishment.
  trustStart: 42,
  trustRecovery: 0.10,     // monthly: trust drifts back toward 50
  trustWeight: 0.5,

  // Issue ownership: the party most identified with a side of an issue
  // gains when that issue becomes hot.
  ownWeight: 0.9,
  singleIssueFrom: 1.3,    // voters who care at least this much about an issue react to who owns it
                           // (hot news raises how much everyone cares, so more voters cross the line)
  maxSignatureIssues: 2,   // how many issues your party can campaign on at once
  ownDecay: 0.97,          // monthly
  ownShareFloor: 0.25,     // a lone owner still needs a decent claim to get the full bonus
  newsWaveChance: 0.2,     // monthly chance a random issue suddenly dominates the news
  newsWaveSize: 0.8,

  // Actions you take yourself each month
  actionsPerMonth: 2,
  mobilizeDecay: 0.88,     // monthly: grassroots turnout boost fades

  // Rival parties
  rivalEventChance: 0.2,   // monthly chance something happens to a rival
  collapseAt: 20,          // stability below which a party splits
  collapseCooldownMonths: 24, // a party that just split can't split again this soon
  poachCooldownMonths: 6,  // you can only raid the same party this often
  scrutinyFrom: 0.27,      // once your poll share passes this, the press starts digging
  scrutinyChance: 0.35,    // monthly chance of a damaging story while you are a frontrunner

  pollError: 0.012,        // standard error of national polls (1.2 points)
  scandalChanceScale: 1,   // multiplies every leak chance
};

// ---------- Political axes ----------
const AXES = [
  { id: "nat", left: "Nationalism", right: "Multiculturalism", issue: "National identity",
    leftGroup: "nationalists", rightGroup: "multiculturalists",
    stances: ["Ultranationalist", "Nationalist", "Neutral", "Multicultural", "Radically multicultural"] },
  { id: "econ", left: "Laissez-faire economy", right: "Central planning", issue: "The economy",
    leftGroup: "free marketeers", rightGroup: "central planners",
    stances: ["Free-market purist", "Free-market", "Mixed economy", "Interventionist", "Command economy"] },
  { id: "prog", left: "Progressive", right: "Traditionalist", issue: "Social values",
    leftGroup: "progressives", rightGroup: "traditionalists",
    stances: ["Radical progressive", "Progressive", "Moderate", "Traditionalist", "Ultra-traditionalist"] },
  { id: "war", left: "Hawkish", right: "Doveish", issue: "Defence & foreign policy",
    leftGroup: "hawks", rightGroup: "doves",
    stances: ["Very hawkish", "Hawkish", "Neutral", "Doveish", "Pacifist"] },
  { id: "gov", left: "Small government", right: "Big government", issue: "Public services",
    leftGroup: "small-government voters", rightGroup: "big-government voters",
    stances: ["Minimal state", "Small government", "Moderate", "Big government", "All-encompassing state"] },
  { id: "labor", left: "Worker rights", right: "Corporate support", issue: "Jobs & wages",
    leftGroup: "union supporters", rightGroup: "business-minded voters",
    stances: ["Militantly pro-worker", "Pro-worker", "Balanced", "Pro-business", "Corporate champion"] },
  { id: "immig", left: "Pro-immigration", right: "Restricted immigration", issue: "Immigration",
    leftGroup: "pro-immigration voters", rightGroup: "immigration restrictionists",
    stances: ["Open borders", "Pro-immigration", "Moderate", "Restrictive", "Closed borders"] },
  { id: "rev", left: "Revolutionary", right: "Reactionary", issue: "The political system",
    leftGroup: "revolutionaries", rightGroup: "reactionaries",
    stances: ["Revolutionary", "Reformist", "Establishment", "Conservative", "Reactionary"] },
];

// ---------- Demographic building blocks ----------
// Every pop is one combination: region × age × class × nationality.
// lean = pushes the pop's position on an axis; sal = how much they care (1 = normal).
// leaderAppeal = how much a strong, charismatic leader sways them (1 = normal).
const AGES = [
  { id: "18-29", label: "18–29", share: 0.24, turnout: 0.55, engagement: 0.9, leaderAppeal: 1.35,
    lean: { prog: -25, rev: -18, econ: 10, immig: -10, nat: 8 }, sal: { econ: 1.3, labor: 1.3 } },
  { id: "30-45", label: "30–45", share: 0.29, turnout: 0.66, engagement: 1.0, leaderAppeal: 1.1,
    lean: { prog: -8 }, sal: { econ: 1.2, gov: 1.1 } },
  { id: "46-60", label: "46–60", share: 0.25, turnout: 0.74, engagement: 1.1, leaderAppeal: 0.95,
    lean: { prog: 12, rev: 6, nat: -6 }, sal: { gov: 1.2 } },
  { id: "61+",   label: "61+",   share: 0.22, turnout: 0.80, engagement: 1.2, leaderAppeal: 1.0,
    lean: { prog: 30, rev: 18, nat: -15, war: -8, gov: 10 }, sal: { prog: 1.4, gov: 1.3 } },
];

const CLASSES = [
  { id: "working", label: "Working class", adj: "working-class", turnout: -0.05, engagement: 0.9, leaderAppeal: 1.25, disaffect: 0.25,
    lean: { labor: -35, econ: 20, gov: 25, immig: 8 }, sal: { labor: 1.6, econ: 1.4 } },
  { id: "middle", label: "Middle class", adj: "middle-class", turnout: 0.02, engagement: 1.1, leaderAppeal: 0.9, disaffect: 0,
    lean: { econ: -8, prog: -6, gov: -5 }, sal: { econ: 1.2, gov: 1.2 } },
  { id: "upper", label: "Upper class", adj: "upper-class", turnout: 0.08, engagement: 1.25, leaderAppeal: 0.7, disaffect: -0.35,
    lean: { labor: 45, econ: -40, gov: -30, immig: -20, rev: 8 }, sal: { labor: 1.5, econ: 1.5, gov: 1.3 } },
];

const NATIONALITIES = [
  { id: "cranebonian", label: "Cranebonian", plural: "Cranebonians", turnout: 0, leaderAppeal: 1, lean: {}, sal: {} },
  { id: "alinnian", label: "Alinnian minority", plural: "Alinnians", turnout: -0.08, leaderAppeal: 0.8,
    lean: { nat: 60, war: 40, rev: -30, prog: 5 }, sal: { nat: 2.0, rev: 1.5, war: 1.5 } },
  { id: "norbanian", label: "Norbanian-born", plural: "Norbanian-born citizens", turnout: -0.12, leaderAppeal: 0.9,
    lean: { immig: -60, nat: 40, labor: -20, war: 20 }, sal: { immig: 2.0, labor: 1.3 } },
];

// ---------- Regions ----------
// adults = millions of voting-age citizens. classes / nationalities = shares (sum to 1).
// local = extra lean for one nationality inside this region only.
// shape = map polygon on the 2296 × 1623 map canvas.
const REGIONS = [
  { id: "cranbia", name: "Cranbia", adults: 9.4, turnout: 0.03, leaderAppeal: 0.9, disaffect: -0.1,
    blurb: "Industrial, urban and educated. Home to the capital, Craneapolis.",
    classes: { working: 0.45, middle: 0.42, upper: 0.13 },
    nationalities: { cranebonian: 0.86, alinnian: 0.07, norbanian: 0.07 },
    lean: { prog: -25, nat: 15, labor: -10 }, sal: { labor: 1.2 },
    label: [1170, 610],
    shape: "915,580 960,535 1000,505 1060,475 1130,445 1180,430 1230,400 1335,400 1360,400 1410,410 1440,470 1500,500 1520,540 1535,580 1580,598 1575,630 1570,700 1560,740 1500,765 1390,765 1300,775 1240,800 1150,822 1000,825 910,860 810,860 805,800 808,770 840,755 920,740 928,700 915,640" },
  { id: "yamlin", name: "Yamlin", adults: 6.1, turnout: 0, leaderAppeal: 1.05, disaffect: 0.15,
    blurb: "The trade gateway to the wider world. Progressives, immigrants and fed-up nationalists live side by side; the rich profit from trade and cheap labour while others feel left behind.",
    classes: { working: 0.50, middle: 0.35, upper: 0.15 },
    nationalities: { cranebonian: 0.72, alinnian: 0.05, norbanian: 0.23 },
    lean: { econ: -15, war: 10, prog: -8 }, sal: { immig: 1.5, econ: 1.2 },
    local: { cranebonian: { lean: { immig: 28, nat: -15 }, sal: { immig: 1.3 } } },
    label: [520, 925],
    shape: "915,580 820,568 750,568 715,575 680,630 640,660 590,655 540,650 510,700 480,760 445,775 440,795 400,795 385,812 325,800 270,815 210,840 150,840 145,920 130,1000 90,1035 65,1060 65,1090 100,1130 150,1150 210,1140 270,1140 330,1175 410,1178 460,1130 550,1080 620,1072 690,1110 760,1095 840,1093 900,1135 930,1150 960,1110 980,1075 980,1060 940,1035 915,1000 910,920 920,870 910,860 810,860 805,800 808,770 840,755 920,740 928,700 915,640" },
  { id: "erland", name: "Erland", adults: 6.5, turnout: 0.02, leaderAppeal: 1.15, disaffect: 0,
    blurb: "The nationalist heartland and breadbasket of Cranebonistan.",
    classes: { working: 0.55, middle: 0.38, upper: 0.07 },
    nationalities: { cranebonian: 0.95, alinnian: 0.03, norbanian: 0.02 },
    lean: { nat: -35, prog: 35, war: -20, immig: 30, rev: 15 }, sal: { nat: 1.5, prog: 1.4 },
    label: [1205, 975],
    shape: "910,860 1000,825 1150,822 1240,800 1300,775 1390,765 1500,765 1560,740 1570,700 1575,630 1630,630 1650,680 1670,780 1665,840 1650,910 1600,940 1530,960 1510,1000 1470,1045 1440,1045 1390,1075 1330,1100 1280,1110 1120,1110 1080,1130 1040,1195 980,1170 930,1150 960,1110 980,1075 980,1060 940,1035 915,1000 910,920 920,870" },
  { id: "alinni", name: "Alinni", adults: 4.0, turnout: -0.02, leaderAppeal: 0.95, disaffect: 0.25,
    blurb: "Conquered from the Southern Trueants fifty years ago. The Alinnian minority has never fully settled into Cranebonistan, and tensions run high.",
    classes: { working: 0.60, middle: 0.33, upper: 0.07 },
    nationalities: { cranebonian: 0.45, alinnian: 0.53, norbanian: 0.02 },
    lean: { war: 5 }, sal: { nat: 1.6, war: 1.5 },
    local: { cranebonian: { lean: { nat: -30, war: -25, rev: 10 } } },
    label: [1780, 495],
    shape: "1360,400 1400,330 1460,240 1530,235 1600,180 1690,150 1750,100 1810,130 1850,190 1960,230 1990,290 2060,410 2120,460 2130,490 2100,560 2090,610 2060,665 1980,690 1900,730 1870,725 1840,690 1770,660 1720,660 1690,640 1640,605 1580,598 1535,580 1520,540 1500,500 1440,470 1410,410" },
  { id: "fauraifai", name: "Fauraifai", adults: 2.1, turnout: -0.06, leaderAppeal: 1.3, disaffect: 0.35,
    blurb: "\"Faur\" for short. Sparse, nomadic and the poorest region, with a disputed border with Dillihan.",
    classes: { working: 0.72, middle: 0.24, upper: 0.04 },
    nationalities: { cranebonian: 0.90, alinnian: 0.05, norbanian: 0.05 },
    lean: { gov: 25, prog: 20, rev: -15, war: -25 }, sal: { gov: 1.6, war: 1.4 },
    label: [1745, 1205],
    shape: "1580,598 1640,605 1690,640 1720,660 1770,660 1840,690 1870,725 1900,730 1910,780 1940,830 1985,880 2010,960 2040,1100 2080,1170 2120,1220 2120,1270 2060,1310 2000,1360 1840,1360 1810,1395 1740,1405 1530,1395 1420,1380 1370,1360 1360,1335 1385,1305 1415,1305 1435,1290 1440,1180 1440,1125 1465,1080 1470,1045 1510,1000 1530,960 1600,940 1650,910 1665,840 1670,780 1650,680 1630,630 1580,630" },
];

// Neighbours: map only for now (later: diplomacy, border events).
const FOREIGN = [
  { id: "trueants", flag: "trueants", name: ["Southern", "Trueants"], label: [2110, 70],
    blurb: "Corrupt and in economic crisis. Its leader still claims Alinni.",
    shape: "1750,100 1780,0 2296,0 2296,465 2160,488 2130,490 2120,460 2060,410 1990,290 1960,230 1850,190 1810,130" },
  { id: "dillihan", flag: "dillihan", name: ["Dillihan", "Republic"], label: [2150, 790],
    blurb: "The regional powerhouse. Disputes the Fauraifai border.",
    shape: "1900,730 1980,690 2060,665 2090,610 2100,560 2130,490 2160,488 2296,465 2296,1623 2060,1623 2030,1460 2000,1360 2060,1310 2120,1270 2120,1220 2080,1170 2040,1100 2010,960 1985,880 1940,830 1910,780" },
  { id: "bourdeaux", flag: "bourdeaux", name: ["Bourdeaux", "Federation"], label: [1390, 1515],
    blurb: "A fragile federation held together by a charismatic generalissimo.",
    shape: "1040,1195 1080,1130 1120,1110 1280,1110 1275,1150 1270,1250 1280,1290 1310,1330 1360,1335 1370,1360 1420,1380 1530,1395 1740,1405 1810,1395 1840,1360 2000,1360 2030,1460 2060,1623 965,1623 975,1480 1000,1400 1050,1260" },
  { id: "james", flag: "james", name: ["James"], label: [1358, 1205], small: true,
    blurb: "Refuses to join Bourdeaux and trusts Cranebonistan to protect it. Rich in rare materials.",
    shape: "1280,1110 1330,1100 1390,1075 1440,1045 1470,1045 1465,1080 1440,1125 1440,1180 1435,1290 1415,1305 1385,1305 1360,1335 1310,1330 1280,1290 1270,1250 1275,1150" },
];
const CAPITAL = { name: "Craneapolis", x: 1175, y: 445 };

// Groups for the "Political views" tab. Pops can belong to several.
const VIEW_GROUPS = [
  { id: "nationalists", label: "Nationalists", who: { lean: { nat: "<-30" } } },
  { id: "multicultural", label: "Multiculturalists", who: { lean: { nat: ">30" } } },
  { id: "freemarket", label: "Free marketeers", who: { lean: { econ: "<-25" } } },
  { id: "planners", label: "Central planners", who: { lean: { econ: ">25" } } },
  { id: "progressives", label: "Progressives", who: { lean: { prog: "<-25" } } },
  { id: "traditionalists", label: "Traditionalists", who: { lean: { prog: ">25" } } },
  { id: "restrict", label: "Immigration restrictionists", who: { lean: { immig: ">30" } } },
  { id: "unionists", label: "Union supporters", who: { lean: { labor: "<-30" } } },
];

// ---------- Parties ----------
// The player and AI parties share one shape. AI parties stay put for now.
// reach (optional) = how well-known the party is, per region (1 = everyone).
const PARTIES = [
  { id: "player", isPlayer: true, color: "#d0452c", manifesto: {}, establishment: 0.05, stability: 70 },
  { id: "nup", name: "National Unity Party", short: "NUP", color: "#3a64b8", ruling: true, emblem: "landmark",
    leader: "Aurel Mendrik", leaderSex: "m", leaderAge: 68, charisma: 52, stability: 55, establishment: 1.0,
    blurb: "The ruling party. Nationalist, traditional, strongest in Erland.",
    owns: { "nat:L": 0.6, "prog:R": 0.4, "immig:R": 0.3 },
    manifesto: { nat: -45, econ: -15, prog: 35, war: -30, gov: -5, labor: 20, immig: 40, rev: 25 } },
  { id: "clf", name: "Cranebonian Labour Front", short: "CLF", color: "#3e9a5c", emblem: "hammer",
    leader: "Sanna Brokk", leaderSex: "f", leaderAge: 58, charisma: 46, stability: 60, establishment: 0.75,
    blurb: "The old left. Unions, factories, public services.",
    owns: { "labor:L": 0.7, "gov:R": 0.45, "econ:R": 0.3 },
    manifesto: { nat: 15, econ: 45, prog: -15, war: 20, gov: 50, labor: -55, immig: -5, rev: -10 } },
  { id: "oc", name: "Open Cranebonistan", short: "OC", color: "#c99a16", emblem: "anchor",
    leader: "Teodor Lisz", leaderSex: "m", leaderAge: 54, charisma: 55, stability: 62, establishment: 0.6,
    blurb: "Liberal and pro-business. Popular with Yamlin's traders and the urban rich.",
    owns: { "econ:L": 0.6, "prog:L": 0.4, "immig:L": 0.35 },
    manifesto: { nat: 45, econ: -60, prog: -40, war: 30, gov: -45, labor: 40, immig: -45, rev: -15 } },
  { id: "apv", name: "Alinni People's Voice", short: "APV", color: "#2795a3", emblem: "bird",
    leader: "Mira Alenshi", leaderSex: "f", leaderAge: 61, charisma: 58, stability: 68, establishment: 0.35,
    blurb: "Speaks for the Alinnian minority. Wants autonomy and peace.",
    reach: { default: 0.25, alinni: 1 }, // little known outside Alinni
    owns: { "nat:R": 0.6, "war:R": 0.35 },
    manifesto: { nat: 80, econ: 20, prog: 5, war: 60, gov: 30, labor: -20, immig: -5, rev: -40 } },
];
// establishment: 1 = the system itself, 0 = total outsider. Matters when trust is low.
// owns: issue ownership at the start ("axis:L" = left side of that axis).
// emblem: an icon name from icons.js. Portraits are drawn by portraits.js from the leader's name, sex and age.
// New leaders for rival parties are drawn from this list.
const LEADER_POOL = [
  { name: "Petra Halvin", sex: "f", age: 66 }, { name: "Oskar Trand", sex: "m", age: 72 }, { name: "Lena Morvic", sex: "f", age: 52 },
  { name: "Ivo Castrel", sex: "m", age: 63 }, { name: "Hanne Dobrik", sex: "f", age: 70 }, { name: "Matei Solun", sex: "m", age: 59 },
  { name: "Vera Kostan", sex: "f", age: 64 }, { name: "Emil Radeck", sex: "m", age: 75 }, { name: "Ilsa Fenrow", sex: "f", age: 57 },
  { name: "Bogdan Ure", sex: "m", age: 66 }, { name: "Nadia Selvo", sex: "f", age: 49 }, { name: "Ruben Akkar", sex: "m", age: 61 },
];

// ---------- Your party: templates, colours, emblems, portraits ----------
// manifesto = stance index per axis: 0 = far left label ... 2 = neutral ... 4 = far right label.
const PARTY_TEMPLATES = [
  { id: "awakening", name: "People's Awakening", leader: "Dorin Vask", portrait: 3, color: "#c8402a", emblem: "hand-fist",
    tagline: "Left-wing populism",
    pitch: "Bread, wages and dignity. Take on the factory owners and the comfortable politicians who protect them.",
    targets: "Working class, young voters, Cranbia and Fauraifai",
    manifesto: { nat: 2, econ: 3, prog: 2, war: 3, gov: 3, labor: 1, immig: 2, rev: 1 } },
  { id: "homeland", name: "Homeland First", leader: "Varro Stell", portrait: 9, color: "#6b3fa0", emblem: "flag",
    tagline: "Right-wing populism",
    pitch: "Close the borders, stand up to the Trueants and Dillihan, and give the country back to ordinary Cranebonians.",
    targets: "Erland, older voters, fed-up nationalists in Yamlin",
    manifesto: { nat: 1, econ: 2, prog: 3, war: 1, gov: 2, labor: 2, immig: 3, rev: 1 } },
  { id: "horizon", name: "New Horizon", leader: "Alma Teren", portrait: 4, color: "#e07b1a", emblem: "sun",
    tagline: "Fresh-faced centrism",
    pitch: "Competent, modern and above the old quarrels. Sell yourself as the adults the country never had.",
    targets: "Middle class, educated Cranbia, young professionals",
    manifesto: { nat: 3, econ: 1, prog: 1, war: 3, gov: 2, labor: 2, immig: 2, rev: 2 } },
  { id: "steppe", name: "Land and Hearth", leader: "Kerem Ashvar", portrait: 5, color: "#8b5a2b", emblem: "wheat",
    tagline: "Agrarian provincialism",
    pitch: "The capital has forgotten the villages. Farmers, herders and small towns deserve their fair share.",
    targets: "Erland and Fauraifai, rural working class",
    manifesto: { nat: 2, econ: 3, prog: 3, war: 2, gov: 3, labor: 1, immig: 3, rev: 2 } },
  { id: "rage", name: "Enough!", leader: "Ines Varga", portrait: 2, color: "#d6336c", emblem: "megaphone",
    tagline: "Anti-system protest",
    pitch: "They are all the same. Burn the old system down and let the people decide directly.",
    targets: "Anyone fed up with politics: the young, Fauraifai, Alinni",
    manifesto: { nat: 2, econ: 2, prog: 1, war: 2, gov: 1, labor: 1, immig: 2, rev: 0 } },
  { id: "custom", name: "", leader: "", portrait: 1, color: "#c8402a", emblem: "star",
    tagline: "Build your own",
    pitch: "Start from a blank manifesto and decide everything yourself.",
    targets: "Up to you",
    manifesto: { nat: 2, econ: 2, prog: 2, war: 2, gov: 2, labor: 2, immig: 2, rev: 2 } },
];
// Colours chosen so they don't clash with the rival parties.
const PLAYER_COLORS = ["#c8402a", "#d6336c", "#6b3fa0", "#e07b1a", "#8b5a2b", "#4a4a4a"];
const PLAYER_EMBLEMS = ["hand-fist", "flag", "sun", "wheat", "megaphone", "flame", "star", "sprout", "shield", "crown", "scale", "users", "leaf", "sparkles", "mountain"];
// Portraits you can choose for your leader (drawn by portraits.js; the seed fixes the face).
const PLAYER_PORTRAITS = [
  { seed: "p1", sex: "m", age: 47 }, { seed: "p2", sex: "f", age: 49 }, { seed: "p7", sex: "m", age: 58 }, { seed: "p6", sex: "f", age: 56 },
  { seed: "p9", sex: "m", age: 61 }, { seed: "p8", sex: "f", age: 59 }, { seed: "p11", sex: "m", age: 65 }, { seed: "p10", sex: "f", age: 63 },
  { seed: "p13", sex: "m", age: 68 }, { seed: "p12", sex: "f", age: 67 }, { seed: "p15", sex: "m", age: 72 }, { seed: "p14", sex: "f", age: 70 },
];

// ---------- Campaign spending ----------
// Effects are per ₱1M. Rallies are divided by the region's adults (in millions).
const CAMPAIGN = {
  rally:  { aware: 0.10, goodwill: 0.04, leader: 0.02 },
  social: { ages: ["18-29", "30-45"], aware: 0.022, swing: 0.05 },  // cheap, volatile
  tv:     { ages: ["46-60", "61+"], aware: 0.02 },
  tour:   { aware: 0.004, leader: 0.03 },  // the leader travels the country: builds the person, not the party
};
