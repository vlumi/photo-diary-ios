# App Store screenshots: the plan and the capture

The carousel's job: show someone who keeps a photo diary that this puts it
on a map in their pocket. Lead with the map, then the diary by date, then the
pins for places to go back to. **Nothing is staged by hand**: every shot is a
set of stage variables in `shots.json`, and `make shots` relaunches the app
staged for each shot and captures it.

## One command

```sh
make shots                     # LANGS=en,ja by default; OUT=shots
make stage TAB=map SCOPE=demo  # one staged launch, to look before shooting
```

For each language and each shot: launch the app with the shot's variables
(`Scripts/stage.sh`), wait `SETTLE` seconds (8), capture to
`shots/iphone/<lang>/<shot>-iphone.png`. `PAUSE=1` stops before every
capture (⏎ capture · r retake · s skip) for a look; `ONLY=map,todo` redoes
some. A shot with a `by_hand` note in `shots.json` pauses on its own.

## How a launch is staged

`stage.sh` passes `-photodiary-stage` and the variables as launch arguments;
`LaunchStage` (PhotoDiaryCore) reads them. A staged launch opens the scope
asked for, reads its tab, map camera and calendar path from an in-memory
store seeded from the variables, puts the given todo pins in an in-memory
store, and opens the photo, selection or sheet asked for once its screen is
up. Nothing it does is saved: the simulator's own scope, tabs and pins are
as they were at the next ordinary launch. The paired instances are read, not
written, so a staged launch can open any instance paired on that simulator.

## Whose photos

The values in `shots.json` stage the built-in demo, which draws gradient
tiles, to prove the flow. For the real set, pair the account the shots come
from on the simulator `stage.sh` picks (an iPhone 17 Pro Max, the booted one
first; `make stage SCOPE=front` shows which), then set `instance` to its host
(or `INSTANCE=<host> make shots`) and swap each shot's gallery, month, photo
id, camera and selection to that account's photos. Map tags are
`photo:<id>` or `cluster:<id>`; a photo inside a pile at the shot's zoom has
no tag of its own, so pick a camera where it stands alone, or select the pile.

## Size

iPhone 6.9" (iPhone 17 Pro Max, 1320×2868). The app is iPhone-only, so the
set is just that. `make asc-screenshots` refuses a capture at any other size
before touching ASC, since a wrong size uploads fine and then blocks
submission.

## The shots

What each shows and why is in `shots.json` (`python3 Scripts/asc/shots.py en`
prints it). In **store order**:

1. **map**: the city's photo pins and piles, one opened to its thumbnails.
2. **calendar**: a month's grid by day.
3. **photo**: one photo in the viewer.
4. **todo**: todo pins among the photos, one open with its note.
5. **todo-list**: the pins as a list, with how far each one is.
6. **front**: the paired instances and their galleries.

Every language gets the same set in that language; the todo pins carry
Japanese notes in the Japanese set (`stage_ja`). Dark mode is not in the set.

## When the pictures are retaken

Any change to a screen in the set means `make shots` and
`make asc-screenshots-apply`; the tooling replaces each set whole, so a
partial recapture (`ONLY=`) still uploads a complete set from `shots/`.
