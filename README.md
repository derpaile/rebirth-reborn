<p align="center"><img src="docs/assets/hero.svg" alt="Rebirth Reborn — two basslines, twenty-two drums, one more night" width="100%"></p>

<p align="center"><b>A small acid box for long nights.</b><br>Native Apple Silicon · macOS 13+ · Swift + C++ · MIT</p>
<p align="center"><a href="https://derpaile.github.io/rebirth-reborn/">Project website</a> · <a href="#build-and-run">Build & run</a> · <a href="#the-rack">The rack</a> · <a href="README.de.md">Deutsch</a> · <a href="https://github.com/derpaile/rebirth-reborn/issues">Feedback</a></p>

---

## The loop never really ended

Rebirth Reborn is an independent, native remake of the classic two-bassline, two-drum-machine workflow. The appeal is still the same: a few notes, a stubborn kick, too much resonance, and the moment a pattern starts answering back.

The familiar compact rack is redrawn for modern displays. Underneath it, a fresh bass synthesizer, procedurally generated drum sounds and native audio code run directly on Apple Silicon. No Windows wrapper, browser shell, account or download-on-first-launch sound library.

**This repository contains the remake only.** Its sounds, lookup curves, filter patterns and interface artwork are generated or drawn by this project. Original installers, executables, recordings, songs, Mod archives, image files, ROM dumps, recovered code listings and extracted DSP tables are not included. You do not need the original application to build or play it.

The public sound engine is an independent interpretation, **not a claim of sample-exact original sound**. The visual workflow takes its cues from the classic rack; this is an unofficial community project, without affiliation or endorsement.

<p align="center"><img src="docs/assets/rack.png" alt="The native Rebirth Reborn rack: two bass voices, two drum machines, transport, mixer and effects" width="740"></p>
<p align="center"><sub>Actual native interface, redrawn in code. Original rack proportions; sharp controls; proportional zoom.</sub></p>

## The rack

| Section | What you get |
| --- | --- |
| **Two acid bass voices** | Saw/square oscillators, tune, cutoff, resonance, envelope modulation, decay, accent and slide. Optional 2× oversampling. |
| **808-inspired drums** | Eleven playable voices, tuning/decay controls, accents and alternate percussion. |
| **909-inspired drums** | Eleven voices, strong hits, flam, tuning and decay. |
| **Pattern sequencing** | 32 patterns per device, A–D banks, 1–16 steps, shuffle, copy/paste/clear and changes at bar boundaries. |
| **Effects** | Distortion, delay, linked compression and a pattern-controlled filter with 55 newly generated motion/rhythm patterns. |
| **Mixing** | Device levels, pan, delay sends, insert routing and master controls. |
| **Song editing** | Four pattern lanes, insert/duplicate/remove bars, seek, automation editing and recorded MIDI notes. |
| **Presets** | Bass sounds, drumkits, effects, bass/drum patterns and full-rack snapshots; search, rename, delete, JSON import/export. |
| **MIDI** | Live playing, CC control, persistent MIDI Learn, external 24-PPQN clock, Start/Continue/Stop and Song Position. |
| **Recording & export** | Record notes, knob movements and pattern changes; save native JSON; render stereo 44.1-kHz WAV including the tail. |

All 46 sample slots are filled with **fresh synthesized sounds** created from oscillators, envelopes and deterministic noise. They are assembled in memory at startup. There are no shipped audio recordings.

## Build and run

You need an Apple Silicon Mac running macOS 13 or newer, plus Apple's Command Line Tools. No third-party package manager or sample pack is required.

```sh
xcode-select --install  # only if the Command Line Tools are not installed

git clone https://github.com/derpaile/rebirth-reborn.git
cd rebirth-reborn
bash RebirthReborn/build-app.sh
open "RebirthReborn/dist/Rebirth Reborn.app"
```

The build script compiles the app, runs the audio/model/effect checks, packages it and applies a local ad hoc signature. The resulting app lives in `RebirthReborn/dist/`. It is a development build, not a notarized commercial distribution.

The finished app needs neither development tools nor internet access to play. The repository's macOS workflow checks the same asset-free build and uploads a build artifact.

## First session: make it move

1. Press **Space** to start the rack.
2. Choose a bass pattern in bank **A**, then set a few notes. A sparse pattern leaves room for the drums.
3. Turn up **Resonance**, open **Cutoff** slowly and bring in **Env Mod**. Add **Accent** on the notes you want to push forward; use **Slide** to connect phrases.
4. Put the kick on 1, 5, 9 and 13, then add hats around it. On the 909-inspired machine, the step context menu exposes strong hits and flam.
5. Give the bass a little delay send. Push distortion when the loop needs teeth.
6. Save the sound or whole rack in **Presets**, or open the **Song Editor** to arrange the patterns.

The website includes a tiny browser acid sketch for a quick taste. It is a separate, self-generated Web Audio demo; the full instrument is the native macOS app.

## Hands on the controls

| Action | Gesture / shortcut |
| --- | --- |
| Play / stop | **Space** |
| Adjust a knob or fader | Drag, mouse wheel or arrow keys |
| Fine adjustment | Hold **Shift** |
| Reset a control | Double-click |
| Enter tempo, loop values or bass step directly | Double-click the number |
| Undo / redo | **⌘Z** / **⌘⇧Z** |
| Open Song Editor | **⌘E** |
| Open Presets | **⌘⇧P**, or right-click a device's pattern area |
| Zoom | **View / Ansicht**, 100–200%; constrained by the available display |

The rack keeps its **592 × 510** logical proportions. Width and height scale together; title-bar space is accounted for. Background plates are cached at 4× resolution, while controls and indicators remain live. A stopped rack avoids continuous redraws.

## Presets and sessions

Use **native JSON** for complete sessions, embedded user-created soundpacks, recorded MIDI notes and remake-specific settings. Your preset library persists locally in `~/Library/Application Support/Rebirth Reborn Community/Presets/library.json`.

There are six preset types. Bass sounds can target either bass voice; drumkits distinguish the 808- and 909-inspired devices. A soundpack supplies a rack-wide sample bank, so changing its bank affects both drum machines. Factory presets are read-only; save a personal copy to make it yours.

The RBS reader/writer is retained for file-format compatibility. An RBS file does not carry this remake's sound engine or generated samples, and cannot store the native recorded-note extension. The app rejects incompatible saves rather than silently dropping that data. No original RBS songs are bundled.

## MIDI without the ceremony

Enable MIDI in **MIDI → Clock und MIDI-Learn**.

- Bass voices listen on **channels 1 and 2**.
- Drum machines listen on **channels 10 and 11**, with their GM-style note mappings.
- Default bass CCs: **20–25** = tune/cutoff/resonance/env mod/decay/accent; **26** = waveform; **7** = level; **10** = pan.
- For MIDI Learn, choose a target or the last moved control, click **Lernen**, then send a CC. Assignments persist locally.
- External clock follows **24 pulses per quarter note**, with automatic or explicit source selection, transport messages and Song Position Pointer.
- The red record button captures bass/drum notes, control movements and pattern changes. Stop closes held notes and adds one undo step.

Native audio uses a command queue between the interface and audio rendering. Timing follows incoming clock pulses; it is not advertised as a sample-exact host synchronization implementation.

## Bring your own sounds

The open `.rbrpack` format is a JSON container with `format: "reborn-soundpack-1"`, a name and a dictionary of base64-encoded files. `voice-0.aiff` through `voice-45.aiff` replace individual sample slots; omitted slots keep the generated defaults. Optional JPEG/PNG rack plates and control sprites can provide a custom skin.

See [the soundpack format](docs/soundpacks.md) for the layout. Original encrypted RBM packages and their decoding dataset are not shipped or required by the public build. A native session can embed a user-created pack so its own sounds travel with it.

## Export, check, repeat

WAV export renders the current pattern loop or full song plus effect tail as stereo Float32 at 44.1 kHz. The audio comparison tool can compare two matching stereo exports, align them within ±2048 samples and report correlation, error and length. It requires files supplied by the user and is not an original-sound certification.

The build checks generated samples, all 22 drum voices, bass controls and oversampling, deterministic and bounded audio, MIDI decoding/clock, presets/history, self-created JSON/RBS/soundpack round-trips and WAV export. It also checks the 55 generated filter patterns in both modes at control extremes.

For native app checks, run each separately:

```sh
"RebirthReborn/dist/Rebirth Reborn.app/Contents/MacOS/Rebirth" --feature-check
"RebirthReborn/dist/Rebirth Reborn.app/Contents/MacOS/Rebirth" --ui-check
```

Each command opens a test instance, runs its checks and exits. `--ui-check` also produces `/tmp/rebirth-reborn-ui-check.png`.

## Where this goes next

This is an early, playable **0.1** release. The priorities are musical response, stable audio, compact controls and sessions that survive the next night.

Useful contributions: musical bass/filter improvements, generated drum synthesis, control usability, MIDI timing, accessibility and small reproducible bug reports. See [CONTRIBUTING.md](CONTRIBUTING.md). Screenshots and a short reproduction help; please keep original application material and third-party sound libraries out of contributions.

## Source layout

```text
RebirthReborn/
  Sources/RebirthApp/          Native rack, editing windows, CoreMIDI
  Sources/RebirthModel/        Sessions, presets, generated sounds, export
  Sources/RebirthDSP/          Bass, voices, effects and audio command queue
  Sources/RebirthCheck/        Audio and model checks
  Sources/RebirthEffectsCheck/ Effect stability and timing checks
docs/                         Project website and original project artwork
scripts/audit-public.py        Publication allowlist and data checks
```

## License

The project's code and original project artwork are released under the [MIT license](LICENSE). User-imported sounds and skins retain their own licenses. ReBirth, TB-303, TR-808 and TR-909 identify the inspiration; their names and marks belong to their respective owners.

**Keep the pattern. Change the night.**
