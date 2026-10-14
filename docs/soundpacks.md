# Reborn soundpacks

A `.rbrpack` is an open JSON file:

```json
{
  "format": "reborn-soundpack-1",
  "name": "My own kit",
  "files": {
    "voice-0.aiff": "BASE64_ENCODED_AIFF"
  }
}
```

The archive is limited to 32 MiB, 128 entries and a 100-character name. Entries are flat filenames; path traversal is rejected. Omitted voices use the built-in synthesized bank. Import a pack through **File → Song oder Soundpack öffnen**; a native JSON session can embed it.

Audio must be mono, signed 16-bit AIFF at 44.1 kHz. The 46 slots follow the remake's voice layout:

| Slots | Role |
| --- | --- |
| 0 | 808-inspired kick |
| 1–5 | Snare tone variants |
| 6–9 | Snare noise variants |
| 10, 11, 12, 13, 14 | Cowbell, closed hat, claves, clap, cymbal |
| 15–21 | Conga/tom variants and alternate percussion |
| 22, 23, 24 | Open hat, rim, auxiliary tone |
| 25–28 | 909-inspired kick variants |
| 29–33 | Snare tone variants |
| 34–36 | Snare noise variants |
| 37–39 | Low/mid/high tom |
| 40–45 | Rim, clap, closed/open hat, crash, ride |

For optional skins, numeric JPEG/PNG filenames select rack plates. `12500.png` is the bass faceplate (366 × 115 logical units); `12520.png` is the 808-style plate and `12564.png` the 909-style plate. `12057.png` is transport (592 × 50), `12058.png` the pattern panel (70 × 115), `12060.png` the device mixer (70 × 115). The other dimensions and sprite-sheet coordinates are in `RackDrawing.swift`, `RackSkin.swift` and `OriginalRack.swift`.

Create the artwork and sounds yourself or use material whose license permits your intended distribution. Original RBM archives and their decoding dataset are not part of this format.
