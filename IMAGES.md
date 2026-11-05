# Adding your own images

Any picture registered in `images.js` replaces the drawn event illustration or leader portrait. Everything without a picture keeps its drawing, so you can add images a few at a time.

## Steps

1. Put the file in the right folder:
   - Event pictures: `assets/events/`
   - Leader pictures: `assets/portraits/`
2. Add one line to `images.js`, for example:
   ```js
   events: {
     erland_drought: { src: "assets/events/erland_drought.jpg", credit: "Dorothea Lange, 1936. Public domain, Library of Congress" },
   },
   scenes: {
     newspaper: { src: "assets/events/newspaper.jpg", credit: "..." },   // used by every scandal and leak
   },
   leaders: {
     "Aurel Mendrik": { src: "assets/portraits/aurel-mendrik.jpg", credit: "..." },
   },
   ```
3. Commit. On GitHub you can do both steps in the browser: **Add file → Upload files** into the folder, then edit `images.js` with the pencil icon. Or send the pictures in chat and Claude adds them.

`events` sets a picture for one event. `scenes` sets one picture for every event that uses that drawn scene, which is the quickest way to cover many events at once. Event ids are in `events.js`; scene names and which events use them are at the bottom of `art.js`.

## Sizes

- **Events:** wide pictures, ideally about 1200 × 400 px (3:1). Other shapes are cropped to the centre.
- **Portraits:** square, about 400 × 400 px, face in the middle. They are shown in a circle.
- Save as JPG, under about 300 KB each, so the game stays quick on phones.

## Where to find public-domain images

These collections mark which items are free to use. Always check the licence on the item's own page.

| Collection | Good for | Notes |
|---|---|---|
| Library of Congress (loc.gov) | Events: farms, drought, strikes, factories, ports, crowds, floods | Many 1930s–40s photographs (for example the FSA/OWI collection) are marked "No known restrictions" |
| Wikimedia Commons | Everything | Filter by licence; prefer "Public domain" or "CC0" |
| The Met Open Access (metmuseum.org) | Painted and engraved portraits | Open Access images are CC0 |
| Rijksmuseum (rijksmuseum.nl) | Portraits, prints, street scenes | Public-domain works are free to download |
| National Gallery of Art (nga.gov) | Portraits | Open Access images are CC0 |
| Smithsonian Open Access | Mixed | CC0 items are marked |
| NYPL Digital Collections | Prints, posters, photographs | Filter by "public domain" |
| Old Book Illustrations | Engravings | Old book art, ready to use |

## Two cautions

- **Portraits of real people.** Using a photo of a real, recognisable politician as a fictional one can cause trouble. Painted or engraved portraits of long-dead or unnamed sitters are safest.
- **"Free" is not always public domain.** Sites like Unsplash and Pexels have their own licences. They are usable but not public domain, so record them as such in the credit.

Add each new source to `CREDITS.md`.
