# Pictures

*This file is written by `tools/image_list.py`. Edit the script, not this file; run it again after adding pictures or events.*

The game shows photographs in five places. None is required: a missing picture is simply not shown, so pictures can go in one at a time.

| Where it shows | File (in `godot/assets/`) | Shape |
|---|---|---|
| An event: on the desk, in the morning paper, and behind the evening news | `events/<event id>.jpg`; if there is none, `events/_<kind>.jpg` is used for every event of that kind | wide, about 16:9 |
| The leader on the road | `tours/<region id>_<great, good or flat>.jpg`; if there is none, `tours/<great, good or flat>.jpg` | wide, about 3:1 (the middle band of a 16:9 picture is fine) |
| A leader's face (top bar, the Parties and Country files) | `portraits/<leader's name in small letters with dashes>.jpg`, or `portraits/<party id>.jpg`; Carlos is `portraits/carlos.jpg` | square, face in the upper middle |
| The lead story of the monthly news | `news/<kind>.jpg` (kinds: vacuum, bad, good, neutral, threat, issue) | wide |
| A neighbouring country's profile | `places/<country id>.jpg` | wide |

`.jpg`, `.png` and `.webp` all work. About 1600 pixels wide is plenty (500 for a portrait).

## The treatment

Every picture goes through one filter (`godot/shaders/photo.gdshader`), so pictures from many sources look like they were printed by one newspaper. Nothing needs to be edited by hand first:

- Colour is removed and the tones are pushed apart: deep shadows, clean highlights.
- The picture is printed in two inks: blue-black shadows, and the paper itself as the light (on the television, a cold white with scan lines instead).
- **Anything strongly red in the original stays red:** a flag, a tie, a fire, a stop sign. Everything else loses its colour. A picture with one red thing in it is worth looking for.
- A fine halftone screen on paper, and darker corners.

What works best: pictures taken at night or in hard light, with strong shapes and few small details; empty places rather than crowds of faces; nothing that pins the picture to a real country (readable signs, real flags, recognisable politicians or buildings). Daylight pictures work too, they come out as a pale print.

Public-domain and CC0 pictures only, never generative AI. For each picture added, note the source and licence in [CREDITS.md](CREDITS.md).

## The shortest useful list

One picture per kind of event covers every event in the game. Start here:

| Have | File | Used for | Something like |
|---|---|---|---|
|   | `events/_crisis.jpg` | Crisis (43 events) | an empty hospital corridor, a queue, a closed factory gate |
|   | `events/_regional.jpg` | Regional issue (11 events) | a small-town high street, a harbour, a field with pylons |
|   | `events/_foreign.jpg` | Foreign affairs (11 events) | a border post, flags outside a ministry, a warship on the horizon |
|   | `events/_opportunity.jpg` | Opportunity (14 events) | a crowd at a rally, a ribbon being cut, a factory floor |
|   | `events/_trap.jpg` | Tricky moment (3 events) | a television studio, a row of microphones, cameras pointed at one chair |
|   | `events/_scandal.jpg` | Scandal (11 events) | a brown envelope, a car park at night, a shredder, a hotel lobby |
|   | `events/_followup.jpg` | Consequences (16 events) | the morning after: an empty hall, newspapers on a doormat |
|   | `events/_flagship.jpg` | Flagship promise | a campaign poster going up on a wall |
|   | `events/_secret.jpg` | In confidence | two people talking in a doorway, a phone face down on a table |
|   | `events/_violence.jpg` | Political violence | police tape, a broken shop window, a square at night |
|   | `tours/great.jpg` | A trip that went very well | a packed hall, hands in the air |
|   | `tours/good.jpg` | A trip that went well | a market square, a handshake over a stall |
|   | `tours/flat.jpg` | A trip that went badly | rows of empty chairs, one man listening |

## Faces

| Have | File | Who |
|---|---|---|
|   | `portraits/carlos.jpg` | Carlos Martin, your advisor (until then: a silhouette against the lamp) |
|   | `portraits/nup.jpg` | The leader of National Unity Party, whoever it is this game |
|   | `portraits/clf.jpg` | The leader of {national} Labour Front, whoever it is this game |
|   | `portraits/oc.jpg` | The leader of Open {country}, whoever it is this game |
|   | `portraits/apv.jpg` | The leader of Alinni People's Voice, whoever it is this game |
|   | `portraits/petra-halvin.jpg` | Petra Halvin (woman, 66) |
|   | `portraits/oskar-trand.jpg` | Oskar Trand (man, 72) |
|   | `portraits/lena-morvic.jpg` | Lena Morvic (woman, 52) |
|   | `portraits/ivo-castrel.jpg` | Ivo Castrel (man, 63) |
|   | `portraits/hanne-dobrik.jpg` | Hanne Dobrik (woman, 70) |
|   | `portraits/matei-solun.jpg` | Matei Solun (man, 59) |
|   | `portraits/vera-kostan.jpg` | Vera Kostan (woman, 64) |
|   | `portraits/emil-radeck.jpg` | Emil Radeck (man, 75) |
|   | `portraits/ilsa-fenrow.jpg` | Ilsa Fenrow (woman, 57) |
|   | `portraits/bogdan-ure.jpg` | Bogdan Ure (man, 66) |
|   | `portraits/nadia-selvo.jpg` | Nadia Selvo (woman, 49) |
|   | `portraits/ruben-akkar.jpg` | Ruben Akkar (man, 61) |
|   | `portraits/dorin-vask.jpg` | Dorin Vask, your leader if you pick People's Awakening |
|   | `portraits/varro-stell.jpg` | Varro Stell, your leader if you pick Homeland First |
|   | `portraits/alma-teren.jpg` | Alma Teren, your leader if you pick New Horizon |
|   | `portraits/bogdan-sokol.jpg` | Bogdan Sokol, your leader if you pick Land and Hearth |
|   | `portraits/ines-varga.jpg` | Ines Varga, your leader if you pick Enough! |

A face for a name wins over a face for a party. Your own leader can also be `portraits/player.jpg`.

## Neighbours

| Have | File | Country |
|---|---|---|
|   | `places/trueants.jpg` | Southern Trueants |
|   | `places/dillihan.jpg` | Dillihan Republic |
|   | `places/bourdeaux.jpg` | Bordon Federation |
|   | `places/james.jpg` | James |
|   | `places/salmark.jpg` | Salmark |

## Every event

For when the short list is done: a picture of its own for one event.

### Crisis

| Have | File | Headline |
|---|---|---|
|   | `events/pezo_slide.jpg` | The Pezo slides against the Golban dollar |
|   | `events/minimum_wage.jpg` | The minimum wage debate |
|   | `events/rent_crisis.jpg` | Rents in Cranebo double in three years |
|   | `events/pension_reform.jpg` | Government plans to raise the retirement age |
|   | `events/youth_video.jpg` | Viral video: graduates driving taxis |
|   | `events/norbanian_boats.jpg` | Refugee ships dock in {city} |
|   | `events/civil_partnerships.jpg` | Civil partnership bill |
|   | `events/crime_wave.jpg` | Robberies surge in Cranebo |
|   | `events/hospital_queues.jpg` | Patients die waiting in hospital corridors |
|   | `events/cranbia_strike.jpg` | Metalworkers strike in Cranbia |
|   | `events/social_id.jpg` | Government wants ID checks on social media |
|   | `events/golban_weekend.jpg` | Golba's Founders Weekend outsells Harvest Day |
|   | `events/golban_words.jpg` | The Language Academy wants Golban words out of adverts |
|   | `events/fuel_price.jpg` | Petrol passes three pezos a litre |
|   | `events/nurse_letter.jpg` | A nurse's resignation letter goes viral |
|   | `events/jeffries_numbers.jpg` | Yvonne Jeffries says the inflation figures are fake |
|   | `events/inheritance_tax.jpg` | Government plans a tax on inherited homes |
|   | `events/rider_tax.jpg` | Tax bills for forty thousand delivery riders |
|   | `events/stadium_money.jpg` | 600 million for a stadium in Cranebo |
|   | `events/anthem_silent.jpg` | National team striker stays silent for the anthem |
|   | `events/ai_callcentres.jpg` | Banks replace six thousand call-centre jobs with AI |
|   | `events/lost_girl.jpg` | Missing girl found dead near {city} |
|   | `events/influencers_turn.jpg` | Influencers turn on you |
|   | `events/murals.jpg` | A mural of you appears in {city} |
|   | `events/dillihan_series.jpg` | A Dillihan drama is the most-watched show in {country} |
|   | `events/school_kitchen.jpg` | Rats in the kitchen that feeds two hundred schools |
|   | `events/violent_series.jpg` | Calls to ban "Black Harbour" after school knife fights |
|   | `events/women_killed.jpg` | Three women killed by former partners in one week |
|   | `events/crisis_insurgency_1.jpg` | Bombing in Alinni |
|   | `events/crisis_insurgency_2.jpg` | Curfew and mass arrests in Alinni |
|   | `events/crisis_insurgency_3.jpg` | The Free Alinni commander is caught |
|   | `events/crisis_james_1.jpg` | Bordon tanks cross into James |
|   | `events/crisis_james_2.jpg` | Refugees from James reach Erland |
|   | `events/crisis_james_3.jpg` | Ceasefire: James loses its mining valleys |
|   | `events/crisis_economy_1.jpg` | Golban banks collapse; the Pezo is in free fall |
|   | `events/crisis_economy_2.jpg` | Factories close across Cranbia |
|   | `events/crisis_economy_3.jpg` | Bread riots in Yamlin |
|   | `events/crisis_terror_1.jpg` | Arson attack on an Alinnian community centre |
|   | `events/crisis_terror_2.jpg` | The Black Wheat attacks a Norbanian shelter |
|   | `events/crisis_terror_3.jpg` | Black Wheat leaders arrested |
|   | `events/crisis_expansion_1.jpg` | Troops mass on the Trueant border |
|   | `events/crisis_expansion_2.jpg` | Four soldiers killed in a border clash |
|   | `events/crisis_expansion_3.jpg` | Golba brokers a deal; the government claims victory |

### Regional issue

| Have | File | Headline |
|---|---|---|
|   | `events/port_automation.jpg` | Robots replace dock workers in {city} |
|   | `events/alinnian_schools.jpg` | Alinnian-language schools bill |
|   | `events/smog_cranbia.jpg` | Smog chokes Cranbia |
|   | `events/nomad_schools.jpg` | Travelling teachers for Fauran's villages |
|   | `events/erland_drought.jpg` | Drought hits the Erland harvest |
|   | `events/noodle_market.jpg` | Norbanian food takes over {city}'s old market |
|   | `events/bakeries_close.jpg` | Village bakeries in {province} close as flour doubles |
|   | `events/campbell_mocks.jpg` | Freddy Campbell calls your party "Cranebo people" |
|   | `events/data_centre.jpg` | A Golban data centre wants {province}'s water |
|   | `events/fauran_cheese.jpg` | Cranebo inspectors ban Fauran's raw-milk cheese |
|   | `events/river_waste.jpg` | The river below {city} runs orange |

### Foreign affairs

| Have | File | Headline |
|---|---|---|
|   | `events/golba_trade.jpg` | Golba offers a free trade agreement |
|   | `events/trueant_claim.jpg` | Trueant president: "Alinni will come home" |
|   | `events/dillihan_border.jpg` | Dillihan patrol enters Fauran pastures |
|   | `events/james_mines.jpg` | Potania wants more of James's rare earths |
|   | `events/generalissimo.jpg` | Bordon's generalissimo collapses at a parade |
|   | `events/golba_sanctions.jpg` | Golba asks for sanctions on the Southern Trueants |
|   | `events/dillihan_pipeline.jpg` | Dillihan proposes a gas pipeline through Fauran |
|   | `events/james_base.jpg` | James asks for a {national} military base |
|   | `events/abroad_golba.jpg` | Three hundred {nationals} deported from Golba overnight |
|   | `events/abroad_trueants.jpg` | {national} lorries held at the Trueant border for eleven days |
|   | `events/abroad_norbanistan.jpg` | Four {national} aid workers taken hostage in Norbanistan |

### Opportunity

| Have | File | Headline |
|---|---|---|
|   | `events/festival_holiday.jpg` | Make Harvest Day a national holiday? |
|   | `events/yamlin_flood.jpg` | Floods devastate {city}'s old town |
|   | `events/cup_victory.jpg` | {country} wins the Continental Cup |
|   | `events/tv_debate.jpg` | Invitation to the big TV debate |
|   | `events/fauraifai_quake.jpg` | Earthquake in {province} |
|   | `events/celebrity_endorsement.jpg` | Pop star Lira Vey wants to endorse you |
|   | `events/fake_clip.jpg` | A doctored video of the Labour leader spreads |
|   | `events/clip_dance.jpg` | Teenagers are dancing to your speech |
|   | `events/golban_carmaker.jpg` | A Golban carmaker wants a factory near {city} |
|   | `events/grandma_degree.jpg` | A 78-year-old from {city} gets her degree |
|   | `events/waiter_envelope.jpg` | Waiter returns fifty thousand pezos he found |
|   | `events/hannigan_stream.jpg` | Jeremy Hannigan asks a politician onto his stream |
|   | `events/james_accounts.jpg` | Leaked list: two thousand {nationals} with secret accounts in James |
|   | `events/wrestling_gold.jpg` | A shepherd's son from {province} is world wrestling champion |

### Tricky moment

| Have | File | Headline |
|---|---|---|
|   | `events/hot_mic.jpg` | Hot mic: you called Erland farmers "simple" |
|   | `events/interview_trap.jpg` | A tough interview on Channel One |
|   | `events/tax_promise.jpg` | Rally crowd demands: "No more taxes!" |

### Scandal

| Have | File | Headline |
|---|---|---|
|   | `events/deputy_fight.jpg` | Your deputy in a nightclub brawl |
|   | `events/minister_corruption.jpg` | NUP minister caught with a suitcase of cash |
|   | `events/rival_plagiarism.jpg` | Labour leader's thesis was copied |
|   | `events/nephew_contract.jpg` | Health minister's nephew wins a hospital contract |
|   | `events/mps_beach.jpg` | MPs on a "fact-finding trip" to Potania's beaches |
|   | `events/journalists_tapped.jpg` | Interior ministry tapped nine journalists' phones |
|   | `events/leak_dillihan.jpg` | Leak: your party took money from Dillihan |
|   | `events/leak_trueants.jpg` | Leak: Trueant money in your party accounts |
|   | `events/leak_potania.jpg` | Leak: Potanian mining money behind your campaign |
|   | `events/leak_golba.jpg` | Leak: Golban lobbyists funded your party |
|   | `events/leak_tycoon.jpg` | Leak: a tycoon's suitcase in your party office |

### Consequences

| Have | File | Headline |
|---|---|---|
|   | `events/alinni_protests.jpg` | Mass protests in Alinni over your remarks |
|   | `events/stranded_ship.jpg` | Turned-away refugee ship stranded at sea |
|   | `events/deepfake_exposed.jpg` | Experts confirm your "deepfake" clip was real |
|   | `events/leak_proof.jpg` | The bank transfers are published |
|   | `events/referendum_clashes.jpg` | Referendum rallies turn violent in Alinni |
|   | `events/dock_raids.jpg` | Police raids empty Yamlin's docks |
|   | `events/capital_flight.jpg` | The rich move their money to Golba |
|   | `events/defence_maths.jpg` | Generals praise you; economists do the maths |
|   | `events/trueant_friend.jpg` | Trueant TV calls you "our friend in Cranebo" |
|   | `events/libel_suit.jpg` | A minister on your list sues you |
|   | `events/pension_maths.jpg` | Economists: your pension promise would bankrupt the state |
|   | `events/bourdeaux_warns.jpg` | Bordon calls your pact "a provocation" |
|   | `events/teachers_march.jpg` | Teachers march against your curriculum plans |
|   | `events/dillihan_land.jpg` | Dillihan: "Those pastures are Dillihani" |
|   | `events/trueant_troops.jpg` | Trueant troops move to the border |
|   | `events/golba_warns.jpg` | Golba warns of "consequences" |
