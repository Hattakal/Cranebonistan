# Cranebonistan

A political election simulator set in the fictional country of Cranebonistan. You found a new party and have five years to become the largest party in the National Assembly. The intended way to win is populism: chasing the votes of whichever groups you can win over, while managing the cost of contradicting yourself.

Runs in any browser with no installation: open `index.html`.

## How it plays

- **Weekly turns.** A monthly event, a quarterly campaign budget, a poll every December, and the election after five years.
- **Pops.** About 170 population groups (region × age × class × nationality). Each has views on 8 political axes, cares about some issues more than others, and decides how much it likes each party.
- **Manifesto and stances.** Each axis has 5 stances. Moving inside your stance is free. Crossing into other stances, or flip-flopping, costs you core supporters.
- **Leader and cult.** Voters judge your leader as a person. Devoted followers forgive flip-flops and slowly adopt your views.
- **Monthly actions.** Champion an issue, grassroots organising, opposition research, recruit defectors, provoke outrage.
- **Living rivals.** Rival parties have leaders and stability. They suffer scandals, change leaders, split apart (a power vacuum) and copy your popular positions.
- **Trust in politics.** When trust is low, voters turn to outsiders.
- **Issue ownership.** The party that owns an issue gains most when it suddenly dominates the news.

## Files

| File | What it holds |
|------|---------------|
| `data.js` | The world: balance settings (`CONFIG`), axes, demographics, regions and map shapes, neighbouring countries, parties, campaign channels |
| `events.js` | Monthly events and funding offers, as data. The header explains every effect type |
| `sim.js` | The rules. No screen code, so it also runs in Node for balance testing |
| `ui.js` | Map, tabs, pop-up sheets and saving. Reads the state and calls `sim.js` |
| `style.css` | The look |
| `index.html` | Page skeleton |

The whole game is one plain object (`state`), saved to the browser's local storage.

## Setting

Cranebonistan has five regions: Cranbia (capital Craneapolis, industrial and educated), Yamlin (trade gateway, mixed and tense), Erland (nationalist breadbasket), Alinni (conquered from the Southern Trueants fifty years ago, minority-heavy) and Fauraifai (nomadic, poorest). Its neighbours are the Southern Trueants, the Dillihan Republic, the Bourdeaux Federation and James. Further away are Golba, Norbanistan and Potania.
