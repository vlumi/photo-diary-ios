# App Store Connect tooling

The listing and the screenshots from the repo, never from the ASC UI:
`listing.json` is the single source of the listing text, `shots.json` of the
screenshots (what each shows and the stage variables that set it up). Edit
here, sync with one command. The same tooling as the sibling apps'.

## Setup (once)

Credentials are the release lane's: `Scripts/.asc-config` (Key ID + Issuer ID)
with the `.p8` in `~/.appstoreconnect/private_keys/` — nothing new. The Python
side runs in a venv that `run.sh` makes on first use (Homebrew's Python is
externally-managed), so the Make targets are one step.

## Use

```sh
make asc-listing              # dry run: what differs from ASC
make asc-listing-apply        # write the listing text (every locale)

make shots                    # capture the screenshots (see SCREENSHOTS.md)
make asc-screenshots          # dry run: the upload plan from shots/
make asc-screenshots-apply    # replace each set and upload, in store order
```

The sync writes to every *editable* version (Prepare for Submission,
rejected); a version in review or live is skipped and said so.

## By hand, in App Store Connect

What the API tooling does not cover, set once on the record:

- **Categories**: Photo & Video (primary), Travel (secondary).
- **Age rating**: none of the questionnaire's content. The photos come from
  the user's own server, not from us, so there is no user-generated content
  shared between users.
- **App Privacy**: *Data Not Collected*. The app talks only to servers the
  user pairs it with; location and the camera are used on the device, and
  todo pins never leave it. The privacy policy URL is in `listing.json`
  (`PRIVACY.md` in this repo).
- **Pricing and availability**: free, all territories.
- **Review notes**: the app needs a Photo Diary server to show real photos;
  the built-in Demo instance on the front page works without one. Give the
  reviewer the test account and how to pair it: open the site, sign in, use
  *Pair a device* and scan its QR code (or open the link on the device).
  Credentials go in the review notes field only, never in this repo.
