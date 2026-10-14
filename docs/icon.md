# Reborn² app icon

[Master artwork](../Reborn/Assets/AppIcon.png): 1254 × 1254 PNG with transparency, created for this project using OpenAI’s built-in image generator. Three brushed silver segments form a regeneration loop on a graphite macOS tile with restrained teal details. The historical emblem supplied by the project owner was a visual reference; that reference image is not distributed here.

`bash Reborn/build-app.sh` calls `scripts/build-icon.sh`, which uses macOS `sips` and `iconutil` to package ten icon representations from 16 to 1024 pixels. The bundle and runtime Dock icon both use the resulting `AppIcon.icns`.

## Generation prompt

```text
Use case: logo-brand. Create one production-quality macOS application icon for a native music sequencer named Reborn². Use the attached grayscale historical symbol ONLY as a loose visual reference: the idea of three rounded silver modules arranged radially with dark negative spaces. Design a distinct new emblem, not a tracing or recolored copy. Three broad rounded brushed-aluminum loop segments arranged around a small triangular central negative space; subtly suggest a continuous regeneration loop, keeping the forms bold and readable at 16–32 pixels. Modern restrained macOS icon: a graphite rounded-square/superellipse tile, clean satin silver forms, very subtle bevels and soft studio highlights, delicate dark outlines, a tiny muted teal accent consistent with a silver and gray music rack. Front-facing straight-on, centered symmetrical composition, icon tile occupies about 84% of the square canvas with genuine transparent outside corners/margins and a modest integrated soft shadow. High-resolution crisp edges and restrained depth. No text, letters, numbers, badge, screenshots, macOS dock mockup, scenery, watermarks, neon glow or excessive glossy chrome. Deliver a single standalone square app icon, transparent canvas outside the tile.
```

Artwork is distributed with the project under the [MIT license](../LICENSE).
