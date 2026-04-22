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

### Music state machine (Prompt 12 — not yet wired)

One track per `EnvironmentState`. Long, loop-tolerant, no hard starts
(fade-to-black endings will produce audible cuts during state transitions).
Register: vaporwave / chopped muzak / slowed-down mall Muzak.

| filename | state | notes |
|---|---|---|
| `music_thriving.wav` | thriving | Cheerful 1982 mall Muzak, full fidelity. |
| `music_fading.wav` | fading | Same-ish, slightly slower, first hint of reverb. |
| `music_struggling.wav` | struggling | Pitched down a half-step, heavier reverb. |
| `music_dying.wav` | dying | Vaporwave in earnest — chopped, slowed. |
| `music_dead.wav` | dead | Ambient, drone-heavy. Music as texture, not tune. |
| `music_ghostMall.wav` | ghostMall | Barely there. Per ENDGAME.md, quieter than the hum. |

Prompt 12 will add a `MusicPlayer` actor that cross-fades between tracks
on EnvironmentState transitions (2-second tween, matching the visual
transition). The loader convention follows `AmbientHumPlayer`'s pattern.

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
