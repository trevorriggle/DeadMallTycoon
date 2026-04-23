import Foundation

// v9 Prompt 8 — tuning knobs for the environmental visual state machine.
// See TUNING.md "Environmental visual" section for documentation and the
// design intent behind each value.
//
// Organization: tables are Double-valued dictionaries keyed by
// EnvironmentState. Scalar constants live as static lets. EnvironmentTuning
// is intentionally NOT an enum-with-cases — it's a namespace for config,
// with no instances.
enum EnvironmentTuning {

    // Master brightness multiplier applied to the scene via CIColorControls
    // inputBrightness = (multiplier - 1.0), so 1.0 = no change, 0.4 = -0.6.
    static let brightnessMultipliers: [EnvironmentState: Double] = [
        .thriving:   1.0,
        .fading:     0.92,
        .struggling: 0.8,
        .dying:      0.65,
        .dead:       0.5,
        .ghostMall:  0.4,
    ]

    // Master saturation multiplier (CIColorControls inputSaturation, direct).
    // 1.0 = normal color, 0.25 = near-monochrome.
    static let saturationMultipliers: [EnvironmentState: Double] = [
        .thriving:   1.0,
        .fading:     0.85,
        .struggling: 0.7,
        .dying:      0.55,
        .dead:       0.4,
        .ghostMall:  0.25,
    ]

    // Per-tick probability of a corridor-wide fluorescent flicker flash.
    // Scene-wide brief brightness dip; independent of the 2s smooth
    // state-transition code path (flicker uses its own overlay).
    static let fluorescentFlickerRate: [EnvironmentState: Double] = [
        .thriving:   0.0,
        .fading:     0.02,
        .struggling: 0.08,
        .dying:      0.2,
        .dead:       0.35,
        .ghostMall:  0.5,
    ]

    // Ambient fluorescent-hum track volume. Trevor will drop a
    // fluorescentHum.wav into Resources/audio/; AmbientHumPlayer reads from
    // this table per state. Placeholder values — tune against actual audio.
    static let ambientHumVolume: [EnvironmentState: Float] = [
        .thriving:   0.05,
        .fading:     0.10,
        .struggling: 0.20,
        .dying:      0.35,
        .dead:       0.55,
        .ghostMall:  0.75,
    ]

    // v9 Prompt 11 — per-state music track volume. Inverse curve of
    // ambientHumVolume: music descends from thriving to ghostMall while
    // hum ascends. At `dying` the two cross over (both 0.35). At
    // `ghostMall` hum is 3.75× music — per ENDGAME.md, "the fluorescent
    // hum is louder than the music." MusicService applies this value
    // through AVAudioPlayer.setVolume during the 3s crossfade on state
    // change.
    static let musicVolume: [EnvironmentState: Float] = [
        .thriving:   0.80,
        .fading:     0.65,
        .struggling: 0.50,
        .dying:      0.35,
        .dead:       0.25,
        .ghostMall:  0.20,
    ]

    // Visitor isolation treatment kicks in when active-in-corridor visitor
    // count is strictly less than this value. Raise for more aggressive
    // isolation; lower for less.
    static let isolationThreshold: Int = 4

    // Months of consecutive .dead state required to transition into the
    // ghostMall environmental state. 60 = 5 years.
    static let monthsInDeadForGhostMall: Int = 60

    // Smooth-transition duration when EnvironmentState changes. Seconds.
    // Brightness + saturation animate to the new state's target values
    // over this window. Flicker and blackout flashes run on a separate
    // overlay and are NOT affected.
    static let transitionDuration: TimeInterval = 2.0

    // Single flicker-flash duration, seconds. The scene-wide overlay
    // spikes to ~0.55 alpha for this long then returns to 0.
    static let flickerFlashDuration: TimeInterval = 0.06

    // Ghost Mall-only: longer full-corridor dimming events, on top of the
    // per-tick flicker. Fired every blackoutCadence seconds for blackoutDuration.
    static let ghostMallBlackoutDuration: TimeInterval = 0.4
    static let ghostMallBlackoutCadence: TimeInterval = 5.0

    // Decay overlay age tier width, in months. The procedural decay texture
    // is regenerated when (EnvironmentState, ageMonths / ageTierMonths)
    // changes — so a year-3 struggling mall and a year-15 struggling mall
    // get materially different wear patterns without regenerating the
    // texture every frame.
    static let decayAgeTierMonths: Int = 24
}
