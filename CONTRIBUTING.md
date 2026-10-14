# Contributing

Build with `bash Reborn/build-app.sh` on an Apple Silicon Mac. Keep changes focused and describe their effect on sound, timing or controls.

Before opening a pull request:

- Explain the concrete behavior before and after your change.
- Run the build checks. For interface/input changes, run `--ui-check`; for editing or MIDI changes, run `--feature-check`.
- Run `python3 scripts/audit-public.py` after staging your files.
- Use only your own code/assets or appropriately licensed contributions. Do not add original application binaries, samples, songs, skins, encrypted Mod files, decompiler listings or extracted tables.
- Avoid new dependencies, extra startup work, audio-thread allocations and broad UI redraws unless the behavior requires them.

For bugs, include macOS version, Mac architecture, the smallest reproduction and the result you expected. A screenshot helps with layout; a self-created native session helps with sequencing. Keep personal paths and original application material out of attachments.

Native source is organized into `RebornApp` (interface/MIDI), `RebornModel` (sessions, generated sounds, files) and `RebornDSP` (audio). Pattern clocks use 192 ticks per quarter note: 48 ticks per sixteenth, 768 per 4/4 bar.

The soundpack format is documented in [docs/soundpacks.md](docs/soundpacks.md). User-created soundpacks are separate from the project's MIT source license.
