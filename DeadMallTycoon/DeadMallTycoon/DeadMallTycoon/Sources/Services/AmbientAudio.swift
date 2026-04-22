import Foundation
import AVFoundation

// v9 Prompt 8 — ambient hum audio scaffold.
//
// Trevor provides audio files later. This scaffold:
//   - Declares the expected filename (`fluorescentHum.wav`) in
//     Resources/audio/ via the README there.
//   - Wraps AVAudioPlayer in a simple singleton that loops the hum at a
//     per-EnvironmentState volume (see EnvironmentTuning.ambientHumVolume).
//   - No-ops gracefully if the file is absent so the game runs fine on a
//     build that hasn't shipped audio yet.
//
// Prompt 12 (music state machine) will add per-state music files
// (`music_thriving.wav` … `music_ghostMall.wav`) and a MusicPlayer actor.
// The hum is an independent layer and keeps playing regardless of which
// music track is active — per the ENDGAME.md scene: "the fluorescent
// hum is louder than the music."
final class AmbientHumPlayer {

    static let shared = AmbientHumPlayer()

    private var player: AVAudioPlayer?
    private var currentVolume: Float = 0.0
    private var loaded = false

    private init() {}

    // Lazy-load on first setVolume call. If the file isn't in the bundle,
    // the player stays nil and subsequent calls no-op — game runs silent
    // until the audio file ships.
    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true   // attempt only once; don't hammer the bundle on misses
        // Try a few plausible locations / extensions so the scaffold picks
        // up files dropped in either as a plain resource or an xcasset.
        let candidates: [(String, String)] = [
            ("fluorescentHum", "wav"),
            ("fluorescentHum", "mp3"),
            ("fluorescentHum", "m4a"),
        ]
        for (name, ext) in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let p = try AVAudioPlayer(contentsOf: url)
                    p.numberOfLoops = -1   // infinite loop
                    p.volume = currentVolume
                    p.prepareToPlay()
                    p.play()
                    player = p
                    return
                } catch {
                    // Ignore — we'll stay silent rather than crash.
                }
            }
        }
        // File not present. AmbientHumPlayer goes silent; setVolume calls
        // remain cheap no-ops.
    }

    // Called from MallScene.reconcileEnvironment whenever EnvironmentState
    // changes. Smoothly ramps the underlying player's volume toward target.
    func setVolume(_ target: Float) {
        ensureLoaded()
        currentVolume = max(0, min(1, target))
        guard let player else { return }
        // AVAudioPlayer has no built-in smooth volume tween; approximate
        // with setVolume(_:fadeDuration:). Falls back to instant set on
        // platforms where fade isn't honored.
        player.setVolume(currentVolume, fadeDuration: EnvironmentTuning.transitionDuration)
    }

    // Called from GameViewModel.restart() if the hum needs to stop/restart
    // (e.g., gameover → new run). No-op if audio didn't load.
    func stop() {
        player?.stop()
    }
}
