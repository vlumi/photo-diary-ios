# App Store screenshots: the plan and the capture

The carousel's job: show someone who keeps a photo diary that this puts it
on a map in their pocket. Lead with the map, then the diary by date, then the
pins for places to go back to. **Nothing is staged by hand**: every shot is a
set of stage variables in `shots.json`, and `make shots` relaunches the app
staged for each shot and captures it.

## One command

```sh
make shots                     # LANGS=en by default; OUT=shots
make stage TAB=map SCOPE=demo  # one staged launch, to look before shooting
```

For each shot: launch the app with the shot's variables
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
as they were at the next ordinary launch.

## Whose photos

A staged launch signs in to photos.misaki.fi as the read-only guest account
by default (`SIGN_IN`, `SIGN_IN_USER`, `SIGN_IN_PASSWORD` in `stage.sh`), in
memory only: the front page holds the built-in demo and that instance, on any
simulator, with nothing paired by hand and nothing saved. Only Debug builds
can be staged, so the store build carries neither the sign-in nor any host.

`shots.json` stages that instance's Daily B/W gallery: Naka-Meguro on the
map, September 2026 in the calendar, and the 11th in the viewer. Map tags
are `photo:<id>` or `cluster:<id>`; a photo inside a pile at the shot's zoom
has no callout of its own, so the map shot selects one that stands alone at
its zoom (zoom in until it does). `SIGN_IN=` stages the simulator's own
pairings instead.

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

The store listing is English only, so the set is too (the app itself also
runs in Japanese). Dark mode is not in the set.

## When the pictures are retaken

Any change to a screen in the set means `make shots` and
`make asc-screenshots-apply`; the tooling replaces each set whole, so a
partial recapture (`ONLY=`) still uploads a complete set from `shots/`.
