# Privacy Policy

_Last updated: 2026-10-05._

**Photo Diary Companion does not collect any personal data. Nothing is sent to us.**

The app is a companion for a Photo Diary server that you, or someone you trust, runs. It talks to that server and to nothing else of ours:

- **No data is sent to us.** We run no server for the app, and it has no analytics, no advertising and no third-party SDKs. We receive nothing.
- **Your own Photo Diary server.** When you pair the app with a server, it signs in with the session the server hands it and loads your galleries and photos from there. What that server keeps is up to whoever runs it; the app only reads.
- **Location.** If you allow it, your location is used on the device to show where you are on the map. It is never sent to any server, including your own, and never stored.
- **The camera.** The camera scans a pairing QR code, and takes a snapshot when you attach one to a todo pin. The QR code's frames are read on the device and not kept. A snapshot is stored on the device, scaled down, with its pin.
- **What's stored locally.** Your paired servers and their sessions (the session in the Keychain), the last answers from each server so the app can open offline, your todo pins with their notes and snapshots, and the app's own settings. Todo pins never leave the device. Deleting the app removes it all; removing a server in the app removes its session and cached answers.
- **No tracking.** The app does not track you across apps or websites and does not use any device identifiers for advertising.
- **Children.** Because the app collects no data, it collects none from children either.

## Verifying any of this

Photo Diary Companion is open source. Every claim on this page can be checked in the code at <https://github.com/vlumi/photo-diary-ios>: `project.yml` lists the permissions the app asks for and why, and the server it talks to is the one at <https://github.com/vlumi/photo-diary>.

## Contact

Questions about this policy: open an issue at <https://github.com/vlumi/photo-diary-ios/issues>.
