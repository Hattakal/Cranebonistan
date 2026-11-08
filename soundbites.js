// =====================================================================
// soundbites.js — how your leader can say each answer.
//
// For each event, one list per choice (in the same order as events.js).
// Each sound bite:
//   text  what your leader actually says (shown to the player)
//   tone  statesman | fiery | folksy | provocative  (hidden from the player)
//   react extra group reactions to this exact wording (hidden), same format
//         as goodwill in events.js
//   risk  optional, 0-1: how likely it is to go viral or become a gaffe
//         (defaults by tone: statesman 0.1, folksy 0.3, fiery 0.35, provocative 0.6)
// Choices without sound bites are answered in one step.
// =====================================================================
"use strict";

const SOUNDBITES = {
  pezo_slide: [
    [ // tariffs
      { tone: "statesman", text: "Cranebonistan should not be paying Golba's bills. Targeted tariffs will protect our producers while the Pezo recovers." },
      { tone: "fiery", text: "Every Golban gadget in our shops is a Cranebonian job shipped abroad. Tax them until it hurts!" },
      { tone: "folksy", text: "My grandmother never bought a Golban tomato in her life, and she lived to ninety-four.", react: [{ who: { region: "erland" }, amt: 0.1 }, { who: { age: "61+" }, amt: 0.05 }] },
    ],
    [ // high interest rates
      { tone: "statesman", text: "Painful medicine is still medicine. Raise the rates now, or pay twice as much next year." },
      { tone: "fiery", text: "The Central Bank is asleep at the wheel. Raise the rates, or resign!" },
      { tone: "provocative", text: "If your mortgage goes up, thank the clowns who let the Pezo rot.", react: [{ who: { class: "working" }, amt: -0.1 }] },
    ],
    [ // blame the Alinnians
      { tone: "fiery", text: "While honest Cranebonians work, some people in Alinni live on our taxes and hate us for it." },
      { tone: "folksy", text: "We all know which region takes more than it gives. I don't need to say the name.", react: [{ who: { lean: { nat: "<-30" } }, amt: 0.1 }, { who: { class: "middle" }, amt: -0.1 }] },
      { tone: "provocative", text: "The Alinnians want a Trueant passport and a Cranebonian pension. Pick one!", react: [{ who: { nationality: "alinnian" }, amt: -0.3 }, { who: { lean: { rev: "<-15" } }, amt: 0.1 }] },
    ],
    [ // a temporary slide
      { tone: "statesman", text: "Currencies rise and fall. Our economy is stronger than one bad month." },
      { tone: "folksy", text: "Relax. The Pezo has seen worse, and so have we." },
      { tone: "provocative", text: "Only cowards and Golban bankers panic over one bad month.", react: [{ who: { class: "upper" }, amt: -0.1 }] },
    ],
  ],

  norbanian_boats: [
    [ // welcome them
      { tone: "statesman", text: "These are families fleeing a war. We will hear every claim fairly and quickly." },
      { tone: "fiery", text: "Shame on anyone who would leave children on a quay. Open the gates!", react: [{ who: { region: "yamlin", nationality: "cranebonian", class: "working" }, amt: -0.15 }] },
      { tone: "folksy", text: "My great-grandfather came off a boat with one suitcase. Look how that turned out.", react: [{ who: { age: "18-29" }, amt: 0.08 }] },
    ],
    [ // close the ports
      { tone: "statesman", text: "Compassion has limits, and so does Yamlin. The ports must close until there is a plan." },
      { tone: "fiery", text: "Not one more ship! Cranebonistan is not the world's waiting room!" },
      { tone: "provocative", text: "Send them to Golba. Golba loves lecturing us about human rights.", react: [{ who: { lean: { rev: "<-15" } }, amt: 0.1 }, { who: { class: "middle" }, amt: -0.12 }] },
    ],
    [ // businesses need the workers
      { tone: "statesman", text: "Yamlin's port runs on labour we no longer have. Managed arrivals are good economics." },
      { tone: "folksy", text: "Somebody has to pick the fruit, and it isn't going to be the minister." },
      { tone: "provocative", text: "If your job can be done by a man off a boat, maybe ask yourself why.", react: [{ who: { class: "working" }, amt: -0.35 }] },
    ],
    [ // Golba and Potania should share the burden
      { tone: "statesman", text: "This is an international crisis and it needs an international answer. Golba and Potania must share the load." },
      { tone: "folksy", text: "We'll do our bit. But Golba has a lot more spare rooms than we do." },
      { tone: "fiery", text: "Golba armed every side in Norbanistan's war. Let Golba take the ships!", react: [{ who: { lean: { nat: "<-25" } }, amt: 0.1 }, { who: { region: "yamlin", class: "upper" }, amt: -0.1 }] },
    ],
  ],

  trueant_claim: [
    [ // troops on the border
      { tone: "statesman", text: "Alinni is Cranebonian, and that border must be defended with more than words." },
      { tone: "fiery", text: "Let him come and try. Our soldiers will be waiting." },
      { tone: "provocative", text: "The Trueants can't keep their own lights on. Let them come; we'll leave ours on for them.", react: [{ who: { nationality: "alinnian" }, amt: -0.1 }] },
    ],
    [ // calm talks
      { tone: "statesman", text: "Rhetoric is cheap and war is not. We should talk, and keep talking." },
      { tone: "folksy", text: "Two old neighbours shouting over a fence. Somebody has to put the kettle on." },
      { tone: "fiery", text: "I will not let warmongers in either capital turn our children into soldiers!", react: [{ who: { lean: { war: "<-25" } }, amt: -0.1 }] },
    ],
    [ // development fund for Alinni
      { tone: "statesman", text: "The best answer to the Trueants is an Alinni where people want to stay." },
      { tone: "folksy", text: "Build the roads, open the schools, and nobody in Alinni will want to go anywhere." },
      { tone: "fiery", text: "Cranebo has ignored Alinni for fifty years. No wonder the vultures are circling!", react: [{ who: { loyalTo: "nup" }, amt: -0.1 }] },
    ],
    [ // mock the Trueant economy
      { tone: "folksy", text: "A man who can't pay his own teachers wants another region? Good luck to him." },
      { tone: "provocative", text: "The Southern Trueants: the only country where the power goes off more often than the president.", react: [{ who: { nationality: "alinnian" }, amt: -0.1 }, { who: { age: "18-29" }, amt: 0.1 }] },
      { tone: "fiery", text: "Their president is a thief with a microphone, and everyone in his country knows it." },
    ],
  ],

  cranbia_strike: [
    [ // join the picket line
      { tone: "fiery", text: "Forty thousand people cannot live on promises. Pay them!" },
      { tone: "folksy", text: "I brought tea for the night shift. The owners brought lawyers." },
      { tone: "statesman", text: "These workers are asking for wages that keep up with prices. That is not radical. It is fair." },
    ],
    [ // side with the owners
      { tone: "statesman", text: "If the factories close, nobody gets a raise. Cranbia needs a settlement that keeps it working." },
      { tone: "provocative", text: "Strikes are a luxury for people who've never had to make a payroll.", react: [{ who: { class: "working" }, amt: -0.3 }] },
      { tone: "folksy", text: "My father ran a workshop with six men. A month like this would have closed him." },
    ],
    [ // state arbitration
      { tone: "statesman", text: "Put both sides in a room with an independent arbitrator, and don't let them out until it's done." },
      { tone: "folksy", text: "Nobody wins a strike. Get them round a table, and bring biscuits." },
      { tone: "fiery", text: "The government is hiding under its desk. Arbitration, now!" },
    ],
    [ // foreign agitators
      { tone: "fiery", text: "Somebody is paying for these banners, and it isn't the metalworkers." },
      { tone: "provocative", text: "Ask who funds the strike committee. I hear they speak Dillihani.", react: [{ who: { class: "working" }, amt: -0.15 }, { who: { class: "middle" }, amt: -0.08 }] },
      { tone: "statesman", text: "The public deserves to know whether foreign money is behind this dispute." },
    ],
  ],

  erland_drought: [
    [ // emergency subsidies
      { tone: "statesman", text: "Erland feeds this country. In a bad year, the country must feed Erland." },
      { tone: "folksy", text: "No farmer should have to sell the cow that feeds his children." },
      { tone: "fiery", text: "Cranebo spends millions on statues and nothing on the people who grow its bread!", react: [{ who: { region: "cranbia" }, amt: -0.08 }] },
    ],
    [ // let the market adjust
      { tone: "statesman", text: "Subsidies keep weak farms alive and strong ones waiting. Let prices do their work." },
      { tone: "provocative", text: "Farming is a business. Some businesses fail.", react: [{ who: { region: "erland" }, amt: -0.35 }] },
      { tone: "folksy", text: "My uncle farmed for forty years without a penny from the state. Never stopped complaining, mind you." },
    ],
    [ // cheap grain imports
      { tone: "statesman", text: "Bread prices matter to every family. Bordon grain will keep them down this winter." },
      { tone: "folksy", text: "A loaf is a loaf. My kids can't tell where the wheat came from.", react: [{ who: { region: "erland" }, amt: -0.12 }] },
      { tone: "provocative", text: "Erland's farmers have had their hand out for decades. Time for some competition.", react: [{ who: { region: "erland" }, amt: -0.35 }] },
    ],
    [ // pray with the farmers
      { tone: "folksy", text: "I'll stand with these farmers in the sun, and in the rain when it comes." },
      { tone: "statesman", text: "Faith and hard work have carried Erland through droughts before. They will again." },
      { tone: "provocative", text: "Some people in the capital laugh at prayer. Let them. Erland knows better.", react: [{ who: { lean: { prog: "<-30" } }, amt: -0.12 }] },
    ],
  ],

  youth_video: [
    [ // state job guarantee
      { tone: "statesman", text: "A degree should lead to a job. Under us, every graduate under thirty will be offered one." },
      { tone: "fiery", text: "We are wasting a whole generation, and the government is filming it!" },
      { tone: "folksy", text: "Nobody should need an engineering degree to know the way to the airport." },
    ],
    [ // tax cuts for start-ups
      { tone: "statesman", text: "Tomorrow's jobs come from new companies. Let them keep more of what they earn." },
      { tone: "folksy", text: "Let these engineers build something. Worst case, they're back in the taxi." },
      { tone: "provocative", text: "Stop crying on the internet and start a company.", react: [{ who: { age: "18-29" }, amt: -0.3 }] },
    ],
    [ // meme campaign
      { tone: "folksy", text: "We made a video too. It's shorter, and the taxi has a better driver." },
      { tone: "provocative", text: "Rate my rivals' cabinet: three taxi drivers and a minister who's never had a job." },
      { tone: "statesman", text: "We will put the facts where young people actually look. Short, clear and true.", react: [{ who: { age: "18-29" }, amt: -0.05 }] },
    ],
    [ // blame the older generation
      { tone: "fiery", text: "They bought houses for a song, then pulled the ladder up behind them." },
      { tone: "provocative", text: "OK, grandpa. Your pension is my rent.", react: [{ who: { age: "61+" }, amt: -0.2 }] },
      { tone: "folksy", text: "I love my parents. I just wish they'd left us a little of the country." },
    ],
  ],

  crime_wave: [
    [ // more police
      { tone: "statesman", text: "Safety is the first freedom. We will put ten thousand more officers on the streets." },
      { tone: "fiery", text: "Criminals should fear the night, not the families of Cranebo!" },
      { tone: "folksy", text: "My mother won't take the bus after dark any more. That's not a capital, that's a hostage situation." },
    ],
    [ // poverty and youth centres
      { tone: "statesman", text: "Prison is the most expensive way to fail a young man. Give them somewhere to go." },
      { tone: "folksy", text: "Every kid with a football pitch is a kid without a knife." },
      { tone: "provocative", text: "If you want fewer robbers, stop running the country like one.", react: [{ who: { loyalTo: "nup" }, amt: -0.1 }] },
    ],
    [ // Norbanian gangs
      { tone: "fiery", text: "These gangs came on the boats, and they can leave on them." },
      { tone: "provocative", text: "Funny how the robberies started when the ships arrived.", react: [{ who: { nationality: "norbanian" }, amt: -0.3 }, { who: { class: "middle" }, amt: -0.1 }] },
      { tone: "statesman", text: "Organised gangs with foreign links must be broken up and their members deported." },
    ],
    [ // walk the streets
      { tone: "folksy", text: "I'll walk these streets myself tonight. Who's coming?" },
      { tone: "statesman", text: "I've come to listen, not to make promises." },
      { tone: "fiery", text: "If the government won't patrol these streets, the people will.", react: [{ who: { class: "middle" }, amt: -0.12 }] },
    ],
  ],

  yamlin_flood: [
    [ // fill sandbags
      { tone: "folksy", text: "Hand me a shovel." },
      { tone: "statesman", text: "Today is not for politics. Today is for Yamlin." },
      { tone: "fiery", text: "I'm here. Where is the prime minister?", react: [{ who: { loyalTo: "nup" }, amt: -0.1 }] },
    ],
    [ // attack the prime minister
      { tone: "fiery", text: "Yamlin is drowning and the prime minister is sunbathing!" },
      { tone: "provocative", text: "Somebody send the prime minister a postcard. He seems to like them." },
      { tone: "statesman", text: "The prime minister should be here. Leadership means showing up." },
    ],
    [ // the yacht
      { tone: "provocative", text: "Thoughts and prayers to Yamlin from the beautiful Potanian coast!", react: [{ who: {}, amt: -0.15 }] },
      { tone: "statesman", text: "My thoughts are with Yamlin. I am following events closely." },
      { tone: "folksy", text: "Stay dry, Yamlin! I'm with you in spirit, and in a very small boat.", react: [{ who: { class: "working" }, amt: -0.15 }] },
    ],
  ],

  rent_crisis: [
    [ // rent cap
      { tone: "fiery", text: "The landlords have had their party. Now it's the tenants' turn." },
      { tone: "statesman", text: "A temporary cap will give families breathing room while we build." },
      { tone: "folksy", text: "Sixty percent of your salary for one room and a view of the bins? No." },
    ],
    [ // public housing
      { tone: "statesman", text: "The state built Cranebo once. It can build it again." },
      { tone: "folksy", text: "Cranes on the skyline, keys in young people's hands." },
      { tone: "fiery", text: "A hundred thousand homes, and not one of them for a speculator!" },
    ],
    [ // cut red tape
      { tone: "statesman", text: "We have a shortage because we forbid building. Let people build." },
      { tone: "folksy", text: "If it takes four years to get a permit for a shed, imagine a tower block." },
      { tone: "provocative", text: "Tenants complain about rents, then fight every new building on their street.", react: [{ who: { class: "middle" }, amt: -0.1 }] },
    ],
    [ // blame immigrants
      { tone: "fiery", text: "Every new arrival is another name on the waiting list ahead of yours." },
      { tone: "provocative", text: "Ten Norbanians to a flat and the rent still goes up. Explain that.", react: [{ who: { nationality: "norbanian" }, amt: -0.2 }] },
      { tone: "statesman", text: "Rapid migration has put pressure on housing. We must plan for it honestly." },
    ],
  ],

  minister_corruption: [
    [ // the whole system is rotten
      { tone: "fiery", text: "One suitcase? This whole government is a suitcase!" },
      { tone: "provocative", text: "A gift between old friends? I have old friends too. They give me socks." },
      { tone: "statesman", text: "This is not one minister's failure. It is a system that rewards it." },
    ],
    [ // independent investigation
      { tone: "statesman", text: "Let independent investigators follow the money, wherever it leads." },
      { tone: "folksy", text: "Open the suitcase, count the money, and show us the receipts." },
      { tone: "fiery", text: "Investigate, prosecute, and let the cameras watch!" },
    ],
    [ // stay quiet
      { tone: "statesman", text: "I won't comment while the matter is under investigation." },
      { tone: "folksy", text: "No comment. I don't know anything about suitcases. I travel light." },
      { tone: "provocative", text: "Everyone does it. At least he did it in person.", react: [{ who: { class: "middle" }, amt: -0.2 }, { who: { lean: { rev: "<-15" } }, amt: -0.1 }] },
    ],
  ],
};

// Attach the sound bites to their events.
for (const [id, perChoice] of Object.entries(SOUNDBITES)) {
  const ev = EVENTS.find((e) => e.id === id);
  if (!ev) continue;
  perChoice.forEach((lines, i) => { if (ev.choices[i] && lines && lines.length) ev.choices[i].lines = lines; });
}
