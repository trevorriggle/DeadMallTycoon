# Dead Mall Tycoon — Audio Assets

Drop authored audio files here. The game auto-loads them by filename at
runtime; no pbxproj edits required if the file sits inside this directory
(which ships as an app-bundle resource via the
PBXFileSystemSynchronizedRootGroup rule — same mechanism as Sources/).

## Expected filenames

### Ambient hum (Prompt 8 — loaded via `AmbientHumPlayer`)

| filename | description | scene |
|---|---|---|
| `fluorescentHum.wav` | Looping fluorescent-fixture hum. Per-state volume curve lives in `EnvironmentTuning.ambientHumVolume`. In ghostMall the hum is meant to sit *louder* than the music. | Continuous background, any state. |

Accepted extensions in lookup order: `.wav`, `.mp3`, `.m4a`. Whichever
ships first wins — drop one, leave the others.

### Music state machine (Prompt 11 — wired via `MusicService`)

Per-state track POOLS, not single files. Each env state has its own
subfolder under `audio/music/`; any `.wav`, `.mp3`, `.m4a`, or `.aiff`
in that folder joins the pool. `MusicService` at startup enumerates
the pools via `Bundle.main.urls(forResourcesWithExtension:subdirectory:)`.
Adding a new track is drop-the-file; no code, no manifest, no
pbxproj edit (PBXFileSystemSynchronizedRootGroup handles the bundle
inclusion automatically on next build).

```
audio/music/
    thriving_state/      — bright muzak, 1982 elevator music, major-key
    fading_state/        — softer muzak, slower, faint reverb
    struggling_state/    — ambient lounge, muted, minor-key undertones
    dying_state/         — vaporwave-adjacent, chopped + reverbed
    dead_state/          — full vaporwave, pitched down, heavy reverb
    ghost_state/         — ambient drone with distant echoes of music
```

Per-state volume lives in `EnvironmentTuning.musicVolume` — inverse
curve of `ambientHumVolume` so music descends as hum ascends, crossing
over at `dying` (both 0.35) and reaching 0.20 music vs 0.75 hum at
`ghostMall` (per ENDGAME.md: "the fluorescent hum is louder than the
music").

Behavior contract (see `Services/MusicService.swift`):
- On state change: pick a fresh random track from the destination pool,
  crossfade 3s (new fades in, old fades out). Session memory resets
  so re-entry always picks fresh.
- On track finish: auto-advance to another track from the same pool,
  strictly avoiding the just-played track if any alternative exists.
- On same-state call (reconcile churn): idempotent no-op. Doesn't
  restart tracks or interrupt in-progress crossfades.
- On empty pool: silent, no crash. Drop files in later — they auto-
  join on next build.

Placeholder / royalty-free tracks go in these folders freely. System
is structured so replacing any track is a drop-in swap.

## Format guidance

- **Looping**: files must loop cleanly (no leading/trailing silence that
  causes audible seams). `AVAudioPlayer.numberOfLoops = -1`.
- **Channels**: mono is fine for hum; stereo preferred for music.
- **Sample rate**: 44.1kHz or 48kHz.
- **Bitrate**: compressed formats (.mp3/.m4a) keep app size down; .wav is
  fine for the short hum loop.

## Absent files

`AmbientHumPlayer` no-ops if the file is missing. The game runs silent
without crashing, so feel free to ship builds before audio is final.
