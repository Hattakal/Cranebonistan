# Cranebonistan: design document

This document records what the game is, how it works, and why each decision was made. It is written as a history as well as a reference: when something changed, the old idea and the reason for the change are kept. Status marks what is in the game now (**Built**), what is agreed but waiting (**Planned**), and what was decided against (**Dropped**).

Designer: Ugur Ozan Denizgünü. Built with Claude.

---

## 1. The idea

A political simulator where the only goal is to get elected. The player founds a new party in the fictional Republic of Cranebonistan and has one electoral term to become the largest party in the National Assembly.

**The point of the game** is to show how parties chase votes rather than represent anyone. **An enjoyable game comes first; the satire is second and stays subtle.** It is better for players to miss the message and enjoy the game than the other way around: no caricature, no lecturing. The game never tells the player to be a hypocrite; it makes hypocrisy pay. Saying what each group wants to hear, blaming whoever is convenient, and taking business money while attacking the elites should be viable and tempting, and scandal risk must not make it pointless. **Playing calm and centrist is possible, just harder.** People vote for personalities first and policies second, so the leader's persona and *how they say things* matter most.

*History:* the first version said playing on principle "should not be enough to win" and that the game should make the player spineless or dirty to succeed, then show them what they did. *Revised (November 2026):* the game must be fun first and the message quieter; the populist path pays best, but an honest centrist campaign can still win with good play.

**Repeatability** comes from a semi-random country and from one major crisis per game, drawn from a pool and shaped by the player's campaign.

---

## 2. The world

### Cranebonistan

Five regions. The capital is Cranebo, on the northern coast in Cranbia. The north and west are coastline. *Renamed in November 2026 with the new map:* Fauraifai became **Fauran**, the Bourdeaux Federation became the **Bordon Federation**, and the capital Craneapolis became **Cranebo** (the designer's map names it; other cities include Nikecisa, Bayernal, Kravk and Aikütest). The names below are the current ones.

| Region | Character |
|---|---|
| **Cranbia** | Industrial, urban and educated. The capital region. |
| **Yamlin** | Where international trade with distant countries happens. Mixed and tense: progressives, immigrants, nationalists fed up with immigrants, economic turmoil from the new population, but also the rich who profit from trade and cheap immigrant labour. |
| **Erland** | The nationalist heartland and breadbasket. |
| **Alinni** | Conquered from the Southern Trueants fifty years ago. Home to the Alinnian minority, which has never fully settled in. Big tensions. |
| **Fauran** | Sparse, poorest and least educated. Disputed border with Dillihan. *Its history is being rewritten:* it was first written as nomads and herders, and about 20 places in the content still say so. |

Alinni, not Fauran, is the minority region, to avoid more parallels with Turkey than the map shape already suggests.

### Neighbours

| Country | Character | Leader (placeholder) |
|---|---|---|
| **Southern Trueants** | Corrupt, in major economic crisis. Its leader still claims Alinni. | President Gavrel Ostrun |
| **Dillihan Republic** | The regional powerhouse, economically and militarily. Border disputes around Fauran. | Chancellor Selin Arvadi |
| **Bordon Federation** | A fragile federation of several nations held together by a charismatic generalissimo. | Generalissimo Hector Valmont |
| **James** | Refuses to join the Bordon Federation and trusts Cranebonistan to defend it. Cranebonistan holds favourable mining deals for its rare materials. The name is the only nod to the Jordan vs LeBron debate. | Prime Minister Tomas Verin |

### Further away

- **United Federation of Golba:** the biggest power, akin to the US. Cranebonistan's main trading partner.
- **Norbanistan:** was the second great power before a civil war. Its refugees are fleeing everywhere, including Cranebonistan.
- **Potania:** major buyer of Cranebonistan's rare materials.

### The map

*Redrawn (November 2026, map3):* new borders, all five regions in new places, a lake on the Cranbia–Alinni border, a sea to the south-east, and capitals for the neighbours (Cklue in Bordon, Dillihan, Crumland in the Southern Trueants; James has none). New spellings: Tarropolis, Büllünt, Aikütest (the map's "Cranbero" is a typo: the capital stays **Cranebo**). Rivers and mountains are not drawn yet. Still waiting for the map: provinces as voting districts, the election-night broadcast and map-centred play. **Planned, waiting for the map.** (The leader's home city is built: see *Founding night* in section 7.)

---

## 3. Core systems

### 3.1 Calendar — Built

The game ticks weekly, four weeks to a month. Hooks run on the calendar: monthly events, quarterly budgets, polls, the crisis, the final debate and the election.

- *Original:* monthly ticks. *Changed to* weekly ticks so things can happen inside a month later on.
- *Original:* five years to the election. *Changed to* **four years**, because five years without a changing world felt long. The term is split by one major crisis in year two.

### 3.2 Pops — Built

The electorate is made of about 170 population groups ("pops"), one per region × age group × class × nationality, inspired by Paradox games' pops but much cruder. Every screen is calculated from the pops; nothing is stored twice.

Each pop has: size, turnout, a position and a level of concern on each axis, how much it notices inconsistency, how much it responds to a charismatic leader, how fed up it is with the system, and per-party numbers (core loyalty, recent goodwill, awareness, opinion of the player's leader).

A pop's vote is a score for each party built from: ideological distance (weighted by what the pop cares about), goodwill, awareness, the leader, consistency, trust in the system and issue ownership. Core supporters are counted first; the rest split by score.

*Future pop upgrades, not yet scheduled:* pops changing their minds after events, regional economic conditions, demographic change over the term.

### 3.3 Political axes and the manifesto — Built (revised)

Seven axes, each with five stances (*revised November 2026*):

| Axis | Sides |
|---|---|
| Economy | State ↔ Market |
| Welfare | Welfare ↔ Austerity |
| Nation | Nationalist ↔ Multicultural |
| Society | Progressive ↔ Traditional |
| Order | Authority ↔ Liberty |
| Foreign | Hawk ↔ Dove |
| System | Radical ↔ Establishment |

*History:* the first version had eight axes: Nationalism ↔ Multiculturalism · Laissez-faire ↔ Central planning · Progressive ↔ Traditionalist · Hawkish ↔ Doveish · Small ↔ Big government · Worker rights ↔ Corporate support · Pro-immigration ↔ Restricted immigration · Revolutionary ↔ Reactionary. Three economic axes moved together, national identity and immigration overlapped, "Reactionary" was confusing (it was used for both the old guard and for crackdowns), and there was nothing for authoritarianism. *Decided:* economy and labour merge (the market side implies business, the state side helps workers); nationalism and immigration share one axis even though they can differ; welfare stays separate because "market economy, but your pension is sacred" is a classic populist combination; Order is new; System is about changing the system and its institutions. Names are short words rather than accurate phrases. Religion is left out on purpose.

**Combined labels:** the game names a set of positions the way a commentator would ("National populist", "Left populist", "Liberal", "National conservative"). Labels come from how voters *see* a party, and they only describe; no label is a goal.

The player writes a manifesto (one stance per axis) at the start. After that, every statement moves how voters **perceive** the party.

**History of the consistency rule:**
1. *First version:* freely draggable sliders were rejected; the sliders show perception, built by actions. Drift was the average distance between manifesto and perception.
2. *Second:* five stances per axis. Moving inside a stance was free; crossing stances cost support, and each crossing was counted as a "flip" remembered for two years.
3. *Third:* the flip count was removed. Only the **distance** between manifesto and current perception matters, not how you got there.
4. *Current:* **one stance away costs nothing.** The penalty starts two stances away. Very hawkish acting hawkish is fine. The manifesto was made too important early on, when other systems were thin; real voters have short memories, and politicians usually lose support for big reversals, not small drifts.

**Extreme vs moderate manifestos** (Built):
- An extreme manifesto makes the leader's personal appeal and a cult following grow faster, but statements anger the other side more. The strongman path.
- A moderate manifesto angers people less and appeals across the middle, but the cult barely forms. The Merkel/Macron path.

**Party members** (activists who would leave if the party drifts, possibly splitting it) were discussed and **put out of scope for now**.

### 3.4 Awareness, acceptance and the leader — Built

A pop needs to have heard of the party (**awareness**), like what it stands for (**acceptance**), and ideally like the leader as a person.

**The cult of personality:** devotion is rare and partial. Only voters strongly attached to the leader become devoted. Devoted voters care less about positions and forgive inconsistency, and the fully devoted slowly adopt the leader's views.

*History:* the first version showed "98% cult following" while flip-flops still cost votes. The threshold was too low, and devotion only softened one of several penalties. It was rebuilt so the numbers mean what they say.

Starting with low awareness and building it up is intended.

### 3.5 Influence grows with support — Built

The bigger the party, the more its words move the country: its statements change what people talk about, shift trust in politics and push the major crisis more. Small parties mostly reach their own audience.

Bigger parties also draw scrutiny: once the party polls above about 27%, the press digs into its finances and past statements, and rivals unite against it. The designer specifically liked the finances being looked into.

### 3.6 Feedback — Built

*Problem:* the first versions polled only once a year, so a dozen decisions went by before any result, and the player couldn't learn what worked.

*Decision:* a national **tracking poll every month**, with a detailed poll and summary each December. After every decision a short result shows **how it played** with the main groups. Seeing poll numbers is fine as long as there are several things to juggle.

### 3.7 Words, not numbers — Built

Meters show descriptive terms ("Shaky", "Very low", "Agenda-setter", "Compelling", "Owns it") with numbers only where they help: polls and money. Many raw numbers (claim 42, devotion 18%, inconsistency 3.5) were abstract and hard to feel.

---

## 4. What the player does

### 4.1 Events — Built (revised)

Monthly events present a situation and several responses.

**History:**
1. Each response first said only "appeals to X".
2. *Revised:* each response lists **who it appeals to and who it angers**, with group sizes and strength, generated from the effect data so it can never lie. Event types were added: crises, opportunities (a clearly good answer), traps (tempting but backfire), scandals, regional, foreign affairs and follow-ups.
3. Responses were reworded so the player speaks as the opposition, not the government ("Urge the government to send troops", not "Send the troops").
4. *Current:* **fewer reactive events.** Too many reactive events get boring. A reactive event now arrives in most months but not all, and much of the player's agency moves to initiatives (4.3).

**The government acts first** (Built for some events): when a crisis hits, the ruling party's response is shown, and the player reacts to it: back it, oppose it, or outflank it. Every rival answering every event was rejected as too much; the ruling party's perspective is enough.

### 4.2 Delivery: what you say and how you say it — Built (first set of events)

Choosing a position is the visible, number-based decision. **How the leader says it** is a separate, subjective one.

- Step 1: choose what to say (the position, with its appeals and angers).
- Step 2: choose how to say it, from several **actual sound bites** written for that event. They are not labelled with styles; the player judges the wording.
- Each sound bite carries **hidden** modifiers: a style (statesmanlike, fiery, folksy or provocative, never named on screen) and how specific groups react to that wording.
- After choosing, the game shows **how it played**: who loved it, who hated it, what the press called it. This is how the player learns that wording matters, not only the leader's type.
- Badly judged wording is meant to be possible: the player should be able to tell from the sentence that it's the wrong way to say it, even if it fits their style.
- **Style builds over time.** A consistent voice grows charisma; constantly switching tone makes the leader look fake. Risky lines can go viral or become gaffes.
- Every line is saved for the final debate and the end screen.

*Writing plan:* write full sound bites for a first set of events, play them, and only scale up once it feels right. Badly implemented, this system could go sour fast, mainly through writing volume and unreadable results.

*Future:* certain personalities can pull off lines that would sink others.

### 4.3 Initiatives: setting the agenda — Built

Each month the player can open a debate: propose a referendum, launch a campaign, demand an inquiry, make a promise. Initiatives are proactive and they **seed future events**: what the player puts on the agenda comes back as consequences, and the player owns them. This answers "more proactive events, and the discussions we open affect future events".

### 4.4 Monthly actions — Built (revised)

**Three actions a month**, shared between speaking in a debate, starting a debate, building communities, opposition research, releasing dossiers, recruiting defectors and steering the party (see *Speaking* and *Organise, dig, steer* in section 7).

- **Causes:** a side the leader has spoken for can become one of the party's **two causes**. Ownership wins **single-issue voters**, people who care about that issue above all, a group that grows when the issue is in the news.
- **Provocation** is now a tone of voice when speaking rather than an action of its own. It still gets the party's name known: anti-system voters cheer, the middle class and older voters are appalled, and business donors back away.

*History:* first there were **two actions a month**. **Champion an issue** was its own action, limited to the manifesto's side of an issue and at most two issues at a time (before that, any side of any issue could be championed, which let the player claim everything). **Provoking outrage** was its own action too: recognition jumped, and it wore off with repetition. One-off **grassroots organising** was another. *Revised (November 2026):* championing and outrage were folded into speaking, grassroots organising became communities, steering the party was added, and the number of actions went up to three.

### 4.5 Money — Built (revised)

**Income** (revised): money is no longer a flat amount. Members and small donors give more as the party grows, so a small party is poor. Business gives according to how the upper class feels about the party: anger the bourgeoisie and business donations dry up, and the Chamber of Commerce stops offering money. This makes the working class vs business balance a real choice, and made the game harder, which was the designer's request ("the current version is a bit too easy").

Quarterly budget: rallies per region, social media (cheap, volatile), TV (older voters), the leader's national tour (builds the leader as a person). Shows awareness before and after, remembers last quarter's allocation.

Money offers: corporate and union donations (public, shift the party's image) and dirty money (a tycoon, Dillihan, the Trueants, Potania, Golba) which pays well and may leak as a scandal.

---

## 5. The political world

### 5.1 Rival parties — Built

National Unity Party (ruling, nationalist), Cranebonian Labour Front, Open Cranebonistan (liberal, pro-business), Alinni People's Voice (minority party).

Rivals have leaders, charisma and stability. They suffer scandals and infighting, change leaders (who take them in new directions), recover, and **split** when stability collapses, freeing their core voters: a **power vacuum** the closest party can fill, and a chance to take in defectors. Rivals losing voters to the player copy the player's most popular position. **Rivals also fill empty niches** (*decided November 2026*): now and then the rival best placed to do it takes up a side of an issue that many voters care about and no party speaks for, and moves toward it. *History:* rivals used to sit in their niches unless copying the player.

**Recruiting defectors** wins a rival's organisers and some core voters; one of their politicians only rarely comes along (one time in five). *History:* a politician used to come every time, which made poaching feel routine.

*Origin:* real politicians rise out of nowhere when other parties falter. The designer asked for power vacuums that can be exploited, or that cost the player their own base.

### 5.1b Neighbours change with events — Built

The map doesn't change borders, but events and crises are recorded in each neighbouring country's profile ("Lost its mining valleys to Bordon in the ceasefire"), its relationship with Cranebonistan can change ("Ally, weakened", "On the brink of war"), and countries in an active conflict are shown in red on the map. The latest development appears when hovering over a country.

### 5.2 Trust in the system — Built

National trust in politics. Scandals, crises and anti-system rhetoric lower it. When it is low, fed-up voters turn to outsiders and punish the establishment.

### 5.3 Issue ownership — Built

The party most identified with a side of an issue wins its single-issue voters. Hot issues create more of them. Claiming an issue early, before it blows up, is a real strategy.

### 5.4 The state of the nation — Built

Background indicators: **jobs, prices, migration, border tension and unrest**, shown as words. They drift, react to events and to the government, and feed back into what voters care about and which events happen. Example loop from the designer: immigrants arrive, cheap labour helps the economy a little, unemployment rises among Yamlin's working class, and immigration becomes the issue there.

This is deliberately light for now. A fuller economy is future work.

### 5.5 The major crisis — Built

Every game has **exactly one** major crisis, in the second year, drawn from a pool of five:

1. **Alinni insurgency:** the separation movement turns to violence.
2. **Bordon attacks James:** Cranebonistan can only send supplies.
3. **Global economic crisis** reaches Cranebonistan.
4. **Ultranationalist terror** against minority groups.
5. **Expansion:** Cranebonistan postures militarily toward the Southern Trueants.

**Weighting:** each crisis starts at 20%. Choices carry a hidden pressure toward particular crises (blaming a minority pushes toward the insurgency and the ultranationalist terror; talking up borders pushes toward expansion; boycotts push toward the economic crisis; calls for talks push away). Every choice the player makes nudges the odds a little, scaled by the party's popularity. The player's campaign can at most **double** a crisis's chance, to 40%. If the crisis that happens had more than 30% odds, the crisis event says the party's campaigning played a part.

Each crisis plays out over several months and permanently changes what the country argues about.

---

## 6. Structure and ending

### 6.1 The final debate — Built

A month before the election, a televised debate is its own large event: an opening statement, an attack from the leader of the largest rival party (built from the player's own contradictions, the groups they blamed, or their dirty money), and a closing statement. Every answer is a sound bite, and every word counts twice.

### 6.2 Election — Districts, winner takes all (decided November 2026; being built)

*Decided:* **the map is the game's centre.** The campaign is about turning districts your colour, Paradox-style; the debates and events stay (choosing the exact words is still the core skill), but they become the weapons you use on the map rather than the whole game.

- **Provinces (the districts).** *Drawn by the designer (November 2026, map3):* 29 provinces on the "Provinces" layer, named on the "Province names" layer; an unnamed one takes the name of its city (like Tokyo city and prefecture), or a direction if it has none. The asymmetry is deliberate: Cranebo city is its own small province; Fauran's are few and large, named after the region or their own theme; Boii is the joke one-seat province. Natural-looking borders, no real gerrymandering. Provinces within a region share its kinds of voters; local differences come mostly from campaigning. *Maybe later:* provinces with their own character, like Erland's big cities leaning left. *History:* first an automatic split, 6–7 per region.
- **Seats.** 300 in all, about 10 per province: Cranebo city about 25, Fauran's 5–6, Boii 1. Seats follow population, except that **Alinni gets three-quarters of the seats its people would earn**, part of the minority's disenfranchisement. Weights and fixed seats are in `godot/data/districts.json`. *History:* 120 seats.
- **The winner takes two-thirds.** In each district, the party with the most votes wins two-thirds of its seats, rounded up; the rest are shared out by **national** vote. So a vote for the fourth party in a district still counts for something, while winning districts stays the main game. Districts with one or two seats are pure winner-takes-all (the joke districts). To be fair to small parties, the shared seats are counted across the whole country (largest remainder) and then placed in the districts where each party did best; shared out district by district, they would all go to the two biggest parties. The total is 300 seats. *History (November 2026):* at first the winner took all of a district's seats; the designer wanted a reason to vote for a small party without losing the district map.
- **Voters vote sincerely.** No tactical voting for now: people vote for the party they like best even where it can't win, unless the parties coordinate in that district (standing aside, later).
- **Clear over clever.** No thresholds, no separate national pool of seats, no complicated vote transfers. *Considered and dropped:* proportional seats with a threshold, a mixed system with national list seats, and the Turkish system (hard to explain, and a Turkey parallel).
- **Min-maxing is the fun.** Votes beyond what wins a district are wasted. Once Erland's nationalists are safely yours, you can drift toward Cranbia's moderates, as long as Erland doesn't slip.
- **The leader on the road.** One trip a month, to one province; people there (and a little in the rest of the region) hear of you and warm to you. Less realistic than a national campaign, but more fun. Party offices work mostly in their own province. *Decided (November 2026):* a trip goes better when you spoke up recently for something that province's voters lean toward, when your party and leader are popular, and when you have a base there (an office, voters who already back you); the trip's result says why. **The quarterly budget's "On the road" line** pays for bigger trips (each month's trip uses a third); it replaced rallies by region, which the trips made redundant. *Later:* a picture from each trip (the leader on a platform, kissing a baby).
- **Party relations (skeleton, built).** Each rival party has a relationship with yours, from Bitter to Friendly (−100 to +100), shown in the Country file with the last few reasons. It starts from how close your policies are and drifts back there a tenth of the way each month. Leaking a dossier on them costs 8 per level of severity, being caught spying on them 15, poaching their organisers 10 (another 8 if a politician comes), taking in their rebels 10; speaking against a side they campaign on costs a little, backing it gains a little. **Scars** (decided November 2026): two-fifths of every hostile act never fades by itself; only favours heal it. Anything you do that helps a party first closes its scars, then warms the everyday relationship. *Later:* real favours both ways (they can do you favours too). *History:* at first everything faded a tenth of the way back each month, which forgot a dossier leak within a year. Nothing uses relations yet. *Later:* parties standing aside in each other's districts so they don't split the vote, and forming a government after the election (the largest party is asked first and needs partners; a party everyone hates can be frozen out).
- *History:* seats were split by region and shared proportionally inside each (largest-remainder by region, then D'Hondt), 300 seats in all.

Win condition, for now: the largest party in the Assembly. Forming a government becomes the win condition in a later update.

### 6.3 The end screen — Built

Not a list of events, but **a profile of the leader written by a hostile newspaper**. *Fixed after the first playtest:* the "Said and unsaid" section repeated the same quote in several pairs and counted taking in defectors as a statement. Now each statement appears once, different issues come first, each pair says which issue it's about, plain choices are reported as actions rather than quotes, and only position-taking statements count as broken promises. an archetype title earned by how the game was played, contradictions side by side with dates, who was blamed, who was betrayed, who paid, and the headline the country remembers. If the satire works, the player should recognise themselves in it.

---

## 7. Presentation

| Element | Status | Notes |
|---|---|---|
| Map colours | Built | Each neighbour has its own muted colour; the sea and the lake are light blue. |
| Title screen with the map | Built in the browser version | Not in Godot yet; the game opens on the founding sheet |
| Party templates | Built | Left populist, right populist, centrist, agrarian, anti-system, custom; chosen on the founding sheet |
| Sound effects | Built | Synthesised in code; the designer is happy with them |
| Leader portraits | Built | Drawn in code. *History:* the first set (CC0 "Notionists" avatars) didn't look like politicians; replaced with drawn older men and women in suits. The designer finds them endearing but different from what they imagined and will look for public-domain portraits. |
| Flags | Built | Original designs. *History:* first shown on the map, where some didn't line up. Moved into country profiles: clicking a neighbour shows its flag, leader and summary. |
| Event illustrations | Built (placeholder) | Drawn scenes in the browser prototype; not yet in the Godot version. The designer wants public-domain images (folders ready in `godot/assets/`). Plan: show every picture through one shared newsprint treatment so different sources look like one newspaper. |
| Monthly news as a newspaper front page | Built | |
| The designer's map | Built | Drawn in Krita by the designer and converted by `tools/build_map.py`: regions and countries come from the border lines (rivers and mountains are decoration, never borders), cities from the dots and a text layer. *Decided:* Inkscape was tried for drawing and dropped as counter-intuitive; drawing stays in Krita and the converter does the rest. Provinces will be added the same way. |
| Map-centred play | Planned | Events pinned to places, rallies by clicking the map, election night. Waits for the map. |

### 7.1 The back room (the visual direction) — Built, first pass

The designer's aims: the game should be enjoyable first, and it should look like a finished game rather than a simple browser game. Paradox games are the main inspiration. Several directions were mocked up first. The one chosen is a **detective's evidence board in a smoky back room**. The alternative, "tech bros with laptops", was turned down because the back room is grittier and more fun.

- **Chrome and paper.** The interface around the game is dark tobacco and brass, and everything you read is paper: newspaper clippings, index cards, typed slips and a ledger.
- **Top bar, Paradox-style.** The party, the key numbers (funds, polling, recognition, business mood, trust), the planning files, the date and the speed controls.
- **The board holds only what is current or urgent.** That means the decision waiting for you (red pin), the latest poll, notes from staff, this week's headlines, trouble to watch and what's coming up. Red string links the decision to related cards. *Decided:* planning (manifesto, rival files, dossiers) belongs in the files along the top, especially at the start of a month, not on the board.
- **Planning files** slide out over the board like a folder. Clicking a region on the map opens its voters.
- **Decisions zoom up as paper.** Events are a newspaper front page. You choose what to say on index cards, then the exact words on typed slips. The outcome is shown as the evening news. Any decision can be **put down** to look at the map or the files first, then picked up again from the board. *Fixed after a playtest (November 2026):* the "Put it down" button disappeared from events, and the time buttons were greyed out while a decision waited, so the game seemed stuck. Now every step of a decision can be put down, and while one waits the top-right button reads **Open decision** and brings it back. The button itself is a proper button that says what it does: "Pin it to the board · look around first".
- **Cities in the region file.** Each region's voters page lists its cities: population, how its people lean, a line about the place (to be written with the country's history), and the party office, which can be opened or grown right there. City facts live in `godot/data/cities.json` (population in millions, an optional lean per axis on top of the region's, and the line); a missing population is estimated from the region and the dot size.
- **Polls are more precise for small parties** (the error shrinks with the share, as in real polling), so small gains such as the home-city head start show up. *History:* a flat ±1.2 points hid the head start in the opening poll.
- **Readable text.** The game starts maximised and scales with the window, and small text (labels, notes, buttons) is set a size or two larger than first drawn.
- **The tutorial is a scene in the game.** *Decided:* the old "How to play" button felt fake, so the first night in the back room teaches the game instead. **Carlos Aster**, the advisor, is a sycophant. *Revised after the mockup:* his first draft was too on the nose. He now flatters by keeping bad news away, crediting your instincts and agreeing with criticism in a way that still compliments you. **Margaret Teyl**, the party secretary, is respected in the party and pushes back. For now she is a narrative device that remembers whether you listened. Later she could walk out and found her own party. *Renamed (November 2026):* they were first called Pim Aster and Marta Teyl. *Decided:* Carlos is the voice of the interface, inspired by the advisor in Knights of Honor: he talks in the tutorial and at scheduled moments (polls, the budget, the election), and is meant to be voice-acted. He spins but never lies about numbers; now and then he praises a gaffe ("I think you made a great point, boss"), rarely enough not to repeat. Margaret speaks in text only, not voiced, and appears less: when you cross a line.
- **Sound.** New sounds were added for the pin, typing and the folder. Sound still has a long way to go.
- **Still to come:** more cartoonish politician portraits (the designer will look for public-domain material), event pictures, the redrawn map with provinces, and election night.

### Speaking (November 2026)

*Decided:* almost every action is about how you say things. Joining a debate means picking a line. In **major debates** (hot ones, or ones the economy or a crisis started) the exact words matter: they are quoted and can go viral or become a gaffe, and a gaffe pushes the argument the other way. In **smaller debates** a line mostly shapes your speaking style. Starting a debate also asks for your exact words, and it can **fizzle**. Not speaking in a debate is simply not doing it: the speaking sheet only has a "Back" button. *History:* it first had a "Stay out of it" button, which read as a separate decision made at the same moment as choosing to speak; dropped after the first Godot playtest. Championing and "provoke outrage" were folded into speaking: a side you have spoken for can become one of your two causes, and provocation is a tone. Some lines are simply the wrong way to say something (marked risky). *Decided after the third playtest:* every speech shows how it played (who moved, what the press said), including in smaller debates, where it is "on the record" rather than the evening news. *History:* smaller debates only showed a passing message. **"Change the subject" is gone** completely as a player action (it read as another way of not speaking); the ruling party can still play an argument down. Starting a debate counts as your statement in it.

*Decided after the second playtest (November 2026):*
- **One statement per debate.** Once you have spoken in a debate, that is your position on it; the debate shows what you said instead of the speak buttons. *History:* at first you could speak in the same debate every month, even for both sides.
- **An event's answer is your statement.** When an answered event goes on as a national debate, your answer already counts as speaking in it, so the same story can't be answered twice.
- **Debates turn over like headlines.** A debate runs at most four months (six for crises and other major ones), however hot it still is; the news starts new ones more often, and a rival can't restart one it just lost for six months. *History:* rivals kept favourite arguments alive for a year or more.
- The Country file's button is called **Raise issue**. Carlos's note on the board opens the Debates file when the party has under ₱1.5M (speaking is free), the Actions file otherwise.

### Founding night (November 2026)

*Decided:* a new game opens on a founding sheet. The player picks a party template (or builds their own), names the party and the leader, sets the manifesto (one stance per issue) and chooses **the city where the leader was mayor** before walking out of their old party. That city is the head start: its region's voters know and like the leader (Cranebonians there much more than the minority), and the party starts with a level-1 office in the city. A bigger region is a bigger head start: about 4.8% opening poll from Bayernal, 6.5% from Cranebo, against 2.5% with no home. **Alinni's cities can't be chosen**: Alinnians elect their own minority leaders, and the player's leader is from the majority. The end-of-election sheet offers "Found a new party". Carlos's welcome waits until the party exists.

### Organise, dig, steer (November 2026)

*Decided:* besides speaking, the player can **build communities** in cities (evergreen, slow, lasting; replaces one-off grassroots organising), **dig** into rivals' dirty laundry (opposition research and dossiers), and **steer the party**: moving the manifesto one stance takes three months and costs the loyalty of the party's politicians who care about the other side. "Members" means the party's **politicians**, a named roster, not registered members. When they quit, the party loses reach and goodwill in their region. **Issues:** the country tab lists major issues (from the economy and the crisis) and smaller local stories; any of them, a bad economic number, or the ruling party's own positions can be raised as a debate. A story still in the headlines catches on most easily.

### Fourth playtest (November 2026)

- **Polls are news, not decisions.** The yearly poll no longer stops the clock with a "Read it" card; it goes in the diary and ticker, and the Polls file has the detail. (Before: every non-tracking poll was a decision.)
- **No weeks in the interface.** The Next week button is hidden and dates show the month only; weeks still tick in the rules.
- **The month-end reminder.** Next decision first reminds you, once a month, if the leader hasn't toured yet or actions are left (opening Debates when it's actions); press again to move on.
- **Trip money is per quarter.** Unspent "On the road" money goes back into the account at the next budget instead of boosting next quarter's trips.
- **Map:** the country's outer border is drawn thick; the capital's star and name are a click target for its province; small neighbours' name plates are larger; North-East Cranbia is renamed Middle Cranbia (in districts.json).
- **Your colour creeps in.** A province someone else leads shows your colour as diagonal stripes over theirs, thicker as your vote nears the leader's; once you lead, it is wholly yours. (Before: only the leader's colour, deep or pale by margin.) Small provinces inside big ones (the capital) are now drawn on top; before, the province around Cranebo painted over it.
- **The trip as a local paper.** A tour opens a full page: a headline, a photo (drawn placeholder until art exists in `godot/assets/tours/great|good|flat.png`), a short story picked by how well it went (`godot/data/tours.json`, drafts to rewrite), the vote before and after, and why. (Before: a one-line toast.)
- **Politicians share the manifesto.** At the start every founder's cause is the manifesto's side of their issue, except one random doubter who starts against it and loses a little patience each month (speaking up for their side buys time). Keeping to the manifesto keeps them; steering it, or speaking, against their side costs loyalty. Below 25 they quit and a yes-man who agrees with the manifesto takes the chair: loyal, less able. Each politician has a skill; the bench's strength is the sum of skills. (Before: founders had fixed causes, often against your manifesto, and nobody replaced them.)
- **What kind of leader people want.** Seven types (`godot/data/leader_types.json`): a star, a steady statesman, a revolutionary, a strongman, one of us, clean hands, an expert. Each group wants a mix, from its age, class, region, leanings and how fed up it is; a crisis, a hot border, hard times and low trust raise some wishes, and events can too (effect `"wants"`, fades monthly). Every leader, rivals included, fits each type from their words, record and positions; the match moves votes, weighted by how much the group votes on personality. Shown in the Electorate file ("Wants a steady hand (you fit somewhat)…") and the Platform file ("Comes across as"). (Before: one line, "Looks for a strong, charismatic leader", from the old personality pull.)
- **The ending paper says plainly how you contradicted yourself:** for each issue, "On immigration: first nationalist, then multicultural.", then the two quotes side by side (Then / Later, with dates and which side each took). Broken promises use the same layout. (Before: dated quotes under "Said and unsaid", with nothing saying which side each was on.)
- **Voters live in provinces.** The voter groups (pops) are now one per province × age × class × nationality (where that nationality lives), about 710 instead of 136 per region. A province takes its region's people and views, then its own character: towns are more middle- and upper-class, more mixed and more progressive than the countryside; a city's lean (cities.json) counts for its share of the province; and each game adds a local lean. Trips, offices and the home town still act on one province (and a little on its neighbours, less than before), but now on its own voters, so they show in the polls too, not only in the seat projection. This is the fix for whole regions flipping together after one trip. (Before: pops by region only; a province was its region's voters with a small overlay, so the provinces of a region moved in lockstep.) SAVE_VERSION 26.
- **Carlos never blocks a button:** his remarks let clicks through and fade while the mouse is over them; only tutorial lines wait for a click.

### Media (decided November 2026; first slice built)

- **Every outlet has an audience and works on it every month.** Its reach is which voter groups read or watch it (by age, class, region, nationality). Each month it does three things to its audience: pulls their **views** toward its own slant (a few issues of its own), warms them to the party it **favours**, and builds a **shield** for that party: its audience forgives that party's unpopular statements and drifts away more slowly (the "voting resilience" idea).
- **Honest and partisan media.** An honest outlet reaches many people and moves each one a little; it reports what you actually do (good lines get credit, gaffes get covered). A partisan outlet (the Cranebonian Fox News, or its leftist equivalent) reaches fewer but moves them more and shields more, and spins whatever its party does. Its favour follows how close a party is to its own slant, so a working-class hero with the "wrong" economics is not its man.
- **No runaway radicalisation.** Voters' views are pulled back toward where they started (who they are) every month; media moves opinion slowly and it eases back when coverage stops. Outlets shield only on their own terms.
- **Tone by medium.** Measured and folksy lines play well in traditional media; fiery and provocative ones on social media.
- **Buying an outlet.** A bought outlet's slant moves slowly toward your party, and it bleeds viewers, who go to other outlets of the same kind.
- **Rivals play too.** Outlets favour rival parties by the same rules, so some groups are shielded for a rival.
- **The player sees it in words.** The Electorate file says what a group reads and who that outlet backs ("They'll forgive you a lot"); no exact numbers.
- **First slice, built.** Eleven outlets in `godot/data/media.json`: CBC (public), The Cranebo Herald (broadsheet), The Morning Post (tabloid), The Pezo Ledger (business), Eagle TV (the partisan right network), The Kettle (the online left), the regional Couriers, Clipr and Chatter (platforms), Trueants International and Dillihan World (foreign). Monthly: views pulled toward each outlet's slant and back toward where each group started; goodwill for the favoured party; a shield that softens unpopular statements and core erosion. Your lines move each outlet's view of you by tone, viral clips and gaffes (partisan friends ignore gaffes). The Herald, the Post and The Kettle can be bought (one action and the price). New Media file; the Electorate file says what a group follows and whose side its media is on. All numbers are first guesses, untested.
- *Second slice:* social media personalities (independent ones act like small partisan outlets; bought ones are weaker and a scandal if exposed); foreign money (money, friendly foreign coverage and free bot farms, at the price of exposure risk and demands); the media setting the agenda; friendly journalists who investigate rivals for you (opposition research becomes paying investigative journalists).
- **Rival parties' turn (direction, after the media).** Rivals get a budget and spend it as the player does, a little less freely (the game is asymmetric): rallies and trips, media, investigating other parties. The Polls file becomes a general page about the parties: their monthly moves and spending, streamlined so it reads fast.

### Technology

**Godot 4.7**, with the rules in `sim.gd` and no screen code there, so whole games can be played and tested headless. Hosted on GitHub.

*History:* the first versions were a browser game in HTML, CSS and JavaScript. It was meant as a prototype, never the release format; the rules were kept separate from the screens so they could move to an engine. In November 2026 the game moved to Godot, the rules were ported line for line (and checked to give identical results), and the Godot version then took its own direction (the national debate, seven axes). The browser version was retired and is kept in the repository history on the branch `browser-version`.

---

## 8. Balance targets

**Out of date:** these numbers were measured in the browser version, before the national debate, speaking, communities and the seven axes. They need measuring again in Godot. The "principled" target also predates the decision that calm, centrist play should be able to win, just with more effort (section 1).

Measured with simple bots over five seeded games each, after the funding change (these bots pick sound bites at random and take all dirty money, so a thoughtful player does better). The winning party usually takes 26–35%.

| Strategy | Target | Measured |
|---|---|---|
| Random play | under 12% | 6–11% |
| Principled | 15–20%, not enough to win | 11–20%, never won |
| Opportunist | 25–30%, wins sometimes | 18–21%, never won (but often second) |
| Active and dirty | 30%+ | 13–26%, came within 0.2 points of winning |

*History:* the first balance pass let the opportunist bot win about half its games; the designer found the game too easy, which led to the income change in 4.5.

Original targets:

| Strategy | Target vote share |
|---|---|
| Random play | under 12% |
| Principled (stay true to the manifesto) | about 15–20%, not enough to win |
| Opportunist (chase the popular answer) | about 25–30%, wins sometimes |
| Active and dirty (actions, dossiers, dirty money, outrage) | 30%+ |

---

## 9. Files

See the file table in [README.md](README.md). *History:* the browser prototype split the game into `data.js`, `events.js`, `soundbites.js`, `initiatives.js`, `crises.js`, `sim.js`, `world.js`, `voice.js` and screen files; in the Godot version all content lives in `godot/data/` (JSON) and all rules in `godot/scripts/sim.gd`.

## 10. Out of scope for now / future work

- Party members and internal party splits.
- Personalities who can pull off otherwise bad sound bites.
- Sound bites for the remaining events (about 10 of 40 have them so far; written in small batches and playtested before scaling up).
- More initiatives, and second-stage follow-ups so debates can run for longer chains.
- More of the leader's background (defector from another party, etc.). The home city is built.
- A full economy.
- Governing after winning, and the next election.
- Pops changing their views after events; demographic change.
- Election night district by district; standing aside in districts; forming a government.

## 11. Directions decided (November 2026), not built yet

Agreed after the realism review: the vote itself first, then the people around it.

- *Order:* the yearly moments and the flagship promise come before rivals playing the same game, local candidates and media.
- **Rivals play the same game as you.** They target districts, tour, open offices and pick their fights, using the same actions as the player. This is also what a far-future **multiplayer** version (a friend's suggestion, possibly with different parties) would need.
- **Tactical voting waits** until the basic vote works. *Settled:* voters vote sincerely unless parties coordinate in a district, and the two-thirds rule in 6.2 gives them a reason to vote for a small party.
- **A big moment every year.** Year 1: an internal party affair that can boost the party if handled well but doesn't ruin the game if handled badly. Year 2: the major crisis (built). Year 3: the flagship promise. Year 4: the election.
- **The flagship promise (year 3) — built, first draft.** At month 36 the game picks the biggest issue (how much voters care about it, plus how bad its numbers are): the economy, immigration, security, order or culture. The party picks one of three promises, then one of five wordings (shuffled each game). The promise then owns that side of the issue, keeps the issue in the news, and warms the voters who like it every month until the election; it shows in the Platform file. Content in `godot/data/flagship.json`; all 75 lines are drafts for the designer to rewrite. *Later:* rivals attacking the promise in the final debate, and the promise coming due if the party governs.
- **The flagship promise (year 3), as decided.** A year before the election, when the country's biggest issue is clear (the economy, a foreign threat, immigration, culture...), the party commits to one tangible answer. Voters reward a simple, concrete-sounding fix (tariffs are the real-world example) over "the economy is actually fine", whether or not it makes economic sense. **The wording is the decision**, with many ways to say it: some plain bad, some mostly good, some that only land with certain voters, some that alienate one group but fire up another.
- **Local candidates.** Every district has a candidate per party, a character with a reputation. Poaching a good local candidate is **extremely rare but can change a district**; the chance depends on how close their views are to yours and how unstable their party is.
- **Media and characters.** A basic character system, much simpler than Crusader Kings. Politicians get a fuller character screen; media personalities just a few traits (like players and coaches in Football Manager): newspapers and TV channels with owners, big media personalities, social media figures, streamers moving into politics, celebrities who sell their endorsement to the highest bidder. Media are central to the satire.
- **The economy and the ruling party.** How the economy feels should drive how the government is judged, and both should feed **trust in the system**.
