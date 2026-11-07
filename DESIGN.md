# Cranebonistan: design document

This document records what the game is, how it works, and why each decision was made. It is written as a history as well as a reference: when something changed, the old idea and the reason for the change are kept. Status marks what is in the game now (**Built**), what is agreed but waiting (**Planned**), and what was decided against (**Dropped**).

Designer: Ugur Ozan Denizgünü. Built with Claude.

---

## 1. The idea

A political simulator where the only goal is to get elected. The player founds a new party in the fictional Republic of Cranebonistan and has one electoral term to become the largest party in the National Assembly.

**The point of the game** is to show how parties chase votes rather than represent anyone. The player is expected to become a populist: saying what each group wants to hear, blaming whoever is convenient, and taking money they shouldn't. Playing on principle is possible, but it should not be enough to win. The game should make the player spineless or dirty to succeed, then show them what they did.

**Repeatability** comes from a semi-random country and from one major crisis per game, drawn from a pool and shaped by the player's campaign.

---

## 2. The world

### Cranebonistan

Five regions. The capital is Craneapolis, on the northern coast in Cranbia. The north and west are coastline.

| Region | Character |
|---|---|
| **Cranbia** | Industrial, urban and educated. The capital region. |
| **Yamlin** | Where international trade with distant countries happens. Mixed and tense: progressives, immigrants, nationalists fed up with immigrants, economic turmoil from the new population, but also the rich who profit from trade and cheap immigrant labour. |
| **Erland** | The nationalist heartland and breadbasket. |
| **Alinni** | Conquered from the Southern Trueants fifty years ago. Home to the Alinnian minority, which has never fully settled in. Big tensions. |
| **Fauraifai** ("Faur") | Nomadic, sparse, poorest and least educated. Disputed border with Dillihan. |

Alinni, not Fauraifai, is the minority region, to avoid more parallels with Turkey than the map shape already suggests.

### Neighbours

| Country | Character | Leader (placeholder) |
|---|---|---|
| **Southern Trueants** | Corrupt, in major economic crisis. Its leader still claims Alinni. | President Gavrel Ostrun |
| **Dillihan Republic** | The regional powerhouse, economically and militarily. Border disputes around Fauraifai. | Chancellor Selin Arvadi |
| **Bourdeaux Federation** | A fragile federation of several nations held together by a charismatic generalissimo. | Generalissimo Hector Valmont |
| **James** | Refuses to join Bourdeaux and trusts Cranebonistan to defend it. Cranebonistan holds favourable mining deals for its rare materials. The name is the only nod to the Jordan vs LeBron debate. | Prime Minister Tomas Verin |

### Further away

- **United Federation of Golba:** the biggest power, akin to the US. Cranebonistan's main trading partner.
- **Norbanistan:** was the second great power before a civil war. Its refugees are fleeing everywhere, including Cranebonistan.
- **Potania:** major buyer of Cranebonistan's rare materials.

### The map

The designer is reworking the map with cities, provinces and mountain ranges. Everything that depends on it waits: provinces as voting districts, the election-night broadcast, the leader's background (a city they were mayor of), and map-centred play. **Planned, waiting for the map.**

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

Eight axes, each with five stances:

Nationalism ↔ Multiculturalism · Laissez-faire ↔ Central planning · Progressive ↔ Traditionalist · Hawkish ↔ Doveish · Small ↔ Big government · Worker rights ↔ Corporate support · Pro-immigration ↔ Restricted immigration · Revolutionary ↔ Reactionary.

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

### 4.4 Monthly actions — Built

Two actions a month:
- **Champion an issue:** only on the manifesto's side of an issue, at most two issues at a time. Ownership wins **single-issue voters**, people who care about that issue above all, a group that grows when the issue is in the news. *History:* originally any side of any issue could be championed, which let the player claim everything.
- **Grassroots organising, opposition research, releasing dossiers, recruiting defectors, provoking outrage.**
- **Provoking outrage** exists to get the party's name known: recognition jumps (the result shows how much), anti-system voters cheer, the middle class and older voters are appalled, and business donors back away. It wears off with repetition.

### 4.5 Money — Built (revised)

**Income** (revised): money is no longer a flat amount. Members and small donors give more as the party grows, so a small party is poor. Business gives according to how the upper class feels about the party: anger the bourgeoisie and business donations dry up, and the Chamber of Commerce stops offering money. This makes the working class vs business balance a real choice, and made the game harder, which was the designer's request ("the current version is a bit too easy").

Quarterly budget: rallies per region, social media (cheap, volatile), TV (older voters), the leader's national tour (builds the leader as a person). Shows awareness before and after, remembers last quarter's allocation.

Money offers: corporate and union donations (public, shift the party's image) and dirty money (a tycoon, Dillihan, the Trueants, Potania, Golba) which pays well and may leak as a scandal.

---

## 5. The political world

### 5.1 Rival parties — Built

National Unity Party (ruling, nationalist), Cranebonian Labour Front, Open Cranebonistan (liberal, pro-business), Alinni People's Voice (minority party).

Rivals have leaders, charisma and stability. They suffer scandals and infighting, change leaders (who take them in new directions), recover, and **split** when stability collapses, freeing their core voters: a **power vacuum** the closest party can fill, and a chance to take in defectors. Rivals losing voters to the player copy the player's most popular position. Rivals sit in their niches otherwise.

*Origin:* real politicians rise out of nowhere when other parties falter. The designer asked for power vacuums that can be exploited, or that cost the player their own base.

### 5.1b Neighbours change with events — Built

The map doesn't change borders, but events and crises are recorded in each neighbouring country's profile ("Lost its mining valleys to Bourdeaux in the ceasefire"), its relationship with Cranebonistan can change ("Ally, weakened", "On the brink of war"), and countries in an active conflict are shown in red on the map. The latest development appears when hovering over a country.

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
2. **Bourdeaux attacks James:** Cranebonistan can only send supplies.
3. **Global economic crisis** reaches Cranebonistan.
4. **Ultranationalist terror** against minority groups.
5. **Expansion:** Cranebonistan postures militarily toward the Southern Trueants.

**Weighting:** each crisis starts at 20%. Choices carry a hidden pressure toward particular crises (blaming a minority pushes toward the insurgency and the ultranationalist terror; talking up borders pushes toward expansion; boycotts push toward the economic crisis; calls for talks push away). Every choice the player makes nudges the odds a little, scaled by the party's popularity. The player's campaign can at most **double** a crisis's chance, to 40%. If the crisis that happens had more than 30% odds, the crisis event says the party's campaigning played a part.

Each crisis plays out over several months and permanently changes what the country argues about.

---

## 6. Structure and ending

### 6.1 The final debate — Built

A month before the election, a televised debate is its own large event: an opening statement, an attack from the leader of the largest rival party (built from the player's own contradictions, the groups they blamed, or their dirty money), and a closing statement. Every answer is a sound bite, and every word counts twice.

### 6.2 Election — Built (regions), Planned (provinces)

Votes are counted in three separate stages: opinion, turnout, seats. Seats are split by region, then shared proportionally inside each. Elections should resemble real ones, with results coming in province by province on election night. **Waiting for the map.**

Win condition: the largest party in the Assembly. Governing and staying in power for the next election is the long-term goal and comes later.

### 6.3 The end screen — Built

Not a list of events, but **a profile of the leader written by a hostile newspaper**. *Fixed after the first playtest:* the "Said and unsaid" section repeated the same quote in several pairs and counted taking in defectors as a statement. Now each statement appears once, different issues come first, each pair says which issue it's about, plain choices are reported as actions rather than quotes, and only position-taking statements count as broken promises. an archetype title earned by how the game was played, contradictions side by side with dates, who was blamed, who was betrayed, who paid, and the headline the country remembers. If the satire works, the player should recognise themselves in it.

---

## 7. Presentation

| Element | Status | Notes |
|---|---|---|
| Title screen with the map | Built | |
| Party templates | Built | Left populist, right populist, centrist, agrarian, anti-system, custom |
| Sound effects | Built | Synthesised in code; the designer is happy with them |
| Leader portraits | Built | Drawn in code. *History:* the first set (CC0 "Notionists" avatars) didn't look like politicians; replaced with drawn older men and women in suits. The designer finds them endearing but different from what they imagined and will look for public-domain portraits. |
| Flags | Built | Original designs. *History:* first shown on the map, where some didn't line up. Moved into country profiles: clicking a neighbour shows its flag, leader and summary. |
| Event illustrations | Built (placeholder) | Drawn scenes. The designer wants public-domain images; `images.js` lets any picture replace a drawing, with a credit line. Photos are shown through one shared newsprint treatment so different sources look like one newspaper. |
| Monthly news as a newspaper front page | Built | |
| Map-centred play | Planned | Events pinned to places, rallies by clicking the map, election night. Waits for the map. |

### 7.1 The back room (the visual direction) — Built, first pass

The designer's aims: the game should be enjoyable first, and it should look like a finished game rather than a simple browser game. Paradox games are the main inspiration. Several directions were mocked up first. The one chosen is a **detective's evidence board in a smoky back room**. The alternative, "tech bros with laptops", was turned down because the back room is grittier and more fun.

- **Chrome and paper.** The interface around the game is dark tobacco and brass, and everything you read is paper: newspaper clippings, index cards, typed slips and a ledger.
- **Top bar, Paradox-style.** The party, the key numbers (funds, polling, recognition, business mood, trust), the planning files, the date and the speed controls.
- **The board holds only what is current or urgent.** That means the decision waiting for you (red pin), the latest poll, notes from staff, this week's headlines, trouble to watch and what's coming up. Red string links the decision to related cards. *Decided:* planning (manifesto, rival files, dossiers) belongs in the files along the top, especially at the start of a month, not on the board.
- **Planning files** slide out over the board like a folder. Clicking a region on the map opens its voters.
- **Decisions zoom up as paper.** Events are a newspaper front page. You choose what to say on index cards, then the exact words on typed slips. The outcome is shown as the evening news. Any decision can be **put down** to look at the map or the files first, then picked up again from the board.
- **The tutorial is a scene in the game.** *Decided:* the old "How to play" button felt fake, so the first night in the back room teaches the game instead. Pim Aster, the advisor, is a sycophant. *Revised after the mockup:* the first draft of Pim was too on the nose. He now flatters by keeping bad news away, crediting your instincts and agreeing with criticism in a way that still compliments you. Marta Teyl, the party secretary, is respected in the party and pushes back. For now she is a narrative device that remembers whether you listened. Later she could walk out and found her own party.
- **Sound.** New sounds were added for the pin, typing and the folder. Sound still has a long way to go.
- **Still to come:** more cartoonish politician portraits (the designer will look for public-domain material), event pictures, the redrawn map with provinces, and election night.

### Technology

Browser game in HTML, CSS and JavaScript, no installation. *Discussed:* a desktop program instead. Decided that the browser doesn't limit this kind of game and can be wrapped later (Electron or Tauri) for Steam. The rules live in `sim.js` with no screen code, so the game can be tested in bulk and moved to another engine if ever needed. Hosted on GitHub.

---

## 8. Balance targets

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

| File | Holds |
|---|---|
| `data.js` | Balance settings, axes, demographics, regions, neighbours, parties, templates |
| `events.js` | Events, funding offers, and each event's context (government response, state of the nation, crisis pressure) |
| `soundbites.js` | The sound bites for each event (pure writing; tones and reactions hidden) |
| `initiatives.js` | The monthly agenda and the follow-up events each initiative sets off |
| `crises.js` | The five major crises and their events |
| `sim.js` | Core rules: pops, opinion, effects, rivals, actions, budget, polls, elections, calendar |
| `world.js` | State of the nation, initiatives, the major crisis |
| `voice.js` | Delivery, leader style, the record of statements, the final debate, the end profile |
| `ui.js`, `style.css`, `index.html` | Screens: top bar, map, planning files, sheets, title |
| `board.js` | The evidence board (current and urgent items only) |
| `scene.js` | Back-room dialogue scenes; the opening scene is the tutorial |
| `portraits.js`, `flags.js`, `art.js`, `icons.js`, `sfx.js` | Drawn art, flags, illustrations, icons, sound |
| `images.js` | Public-domain pictures that replace drawings (see IMAGES.md) |

## 10. Out of scope for now / future work

- Party members and internal party splits.
- Personalities who can pull off otherwise bad sound bites.
- Sound bites for the remaining events (about 10 of 40 have them so far; written in small batches and playtested before scaling up).
- More initiatives, and second-stage follow-ups so debates can run for longer chains.
- The leader's background (former mayor, defector from another party, etc.), after the map.
- A full economy.
- Governing after winning, and the next election.
- Pops changing their views after events; demographic change.
- Provinces, election night, map-centred play (after the map).
