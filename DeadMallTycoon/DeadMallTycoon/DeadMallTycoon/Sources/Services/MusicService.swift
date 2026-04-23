import Foundation
import AVFoundation

// v9 Prompt 11 — dynamic music layer keyed to EnvironmentState.
//
// Per-state track pool: tracks live under
// `Sources/Resources/audio/music/<env>_state/*.{wav,mp3,m4a,aiff}` and
// are discovered at service init via Bundle.main enumeration. Drop new
// tracks into the appropriate folder and they auto-join the pool on
// the next build — no manifest, no code change.
//
// Behavior:
//   - On state change (setEnvironmentState, non-idempotent path): pick a
//     random track from the destination pool, crossfade 3s. Outgoing
//     track fades out on its own timer and stops.
//   - On same-state call (setEnvironmentState idempotent path): no-op.
//     Reconcile churn from MallScene.reconcileEnvironment doesn't
//     restart tracks or interrupt crossfades already in progress.
//   - On track finish (AVAudioPlayerDelegate): auto-advance to another
//     random track from the same pool, avoiding the just-played track
//     if at least one alternative exists. Session memory resets on
//     state change — "on re-entry, always pick fresh" per spec.
//
// Volume per state pulls from EnvironmentTuning.musicVolume. The
// AmbientHumPlayer (Prompt 8) continues independently; together the
// two layers realize the ENDGAME.md crossover — music descends as hum
// ascends toward ghostMall where hum is 3.75× music.
//
// Graceful silence: if the pool for a state is empty (user hasn't
// shipped tracks yet, or format mismatch), MusicService stays silent
// and logs nothing. Runs fine on a build without audio assets.
final class MusicService: NSObject {

    static let shared = MusicService()

    // Per-state track URLs, discovered at init.
    private var trackPool: [EnvironmentState: [URL]] = [:]

    // Currently audible track. Nil before any state is set, or when the
    // active pool is empty for the current state.
    private var activePlayer: AVAudioPlayer?

    // Fading-out player held during a crossfade. Stopped after fade
    // completes so memory doesn't leak across rapid state changes.
    private var previousPlayer: AVAudioPlayer?

    // Last state set. Used for idempotency — same-state calls are
    // no-ops so reconcile passes don't restart tracks.
    private var currentState: EnvironmentState?

    // Session memory of the track URL that's currently playing. Used
    // by auto-advance to avoid picking the same track twice in a row
    // within one stay in a state. Reset to nil on state change so
    // re-entry always picks fresh.
    private var lastTrackURL: URL?

    // Crossfade duration. Synced-start with env visual transition
    // (EnvironmentTuning.transitionDuration = 2.0s) but deliberately
    // longer so audio settles slightly after visuals.
    static let crossfadeDuration: TimeInterval = 3.0

    // Manifest of tracks per state.
    //
    // Xcode's PBXFileSystemSynchronizedRootGroup flattens all resources
    // to the bundle root — the on-disk folder structure
    // (audio/music/<state>_state/) is organizational only, not
    // preserved at runtime. So we can't enumerate by subdirectory;
    // we have to know the filenames and resolve each via
    // Bundle.main.url(forResource:withExtension:) against the flat
    // bundle.
    //
    // When a new track is added to a `<state>_state/` folder on disk,
    // its filename also needs a line here. Not as elegant as auto-
    // discovery, but reliable against the flat bundle layout.
    private static let tracksByState: [EnvironmentState: [String]] = [
        .thriving: [
            "Muzak.mp3",
            "elevator music.mp3",
            "bouncing-with-bessie_main-full.wav",
            "Elevator-music 150 MIX.wav",
        ],
        .fading: [
            "Soft Elevator Music.wav",
            "ElephantStock_The-Luxury-Music_main-01_full.wav",
            "Elite.wav",
            "Elite Property.wav",
        ],
        .struggling: [
            "Luxury Ambient.wav",
            "Smooth Jazz Full.mp3",
            "Calm Elevator Music.wav",
        ],
        .dying: [
            "Watermello_Shopping-Lofi_main-01_full.wav",
            "NewZhilla_Calm-Luxury-Chill_main-01_full.wav",
            "alexshulgin_Mallsoft-Vaporwave_main.wav",
            "Main.wav",
        ],
        .dead: [
            "Vaporwave.wav",
            "Vaporwave LoFi.mp3",
            "Main Version (3 min 36 sec).wav",
        ],
        .ghostMall: [
            "JL297_01 - Echoes From Arcade .wav",
            "Dark Tombs Of The Evil Dead.mp3",
            "Dead Bunker Ambience.wav",
            "Sinister (main version).mp3",
            "World Funeral.wav",
        ],
    ]

    private override init() {
        super.init()
        loadTrackPool()
        logPoolDiagnostic()
    }

    // MARK: Public API

    // Idempotent: same state as last call is a no-op. Non-idempotent
    // path resets session memory and crossfades to a fresh random pick
    // from the destination pool.
    func setEnvironmentState(_ env: EnvironmentState) {
        guard env != currentState else { return }
        let previous = currentState
        currentState = env
        lastTrackURL = nil    // new session, no prior track to avoid
        crossfadeToNewTrack()
        // Diagnostic — emits once per genuine transition.
        let fromStr = previous.map(\.rawValue) ?? "nil"
        let pickedStr = lastTrackURL?.lastPathComponent ?? "<none>"
        print("MusicService: \(fromStr) → \(env.rawValue), picked \(pickedStr)")
    }

    // Hard stop. Called by GameViewModel.restart() if the audio layer
    // needs a clean slate. Idempotent itself (safe to call with no
    // active player).
    func stop() {
        activePlayer?.stop()
        previousPlayer?.stop()
        activePlayer = nil
        previousPlayer = nil
        currentState = nil
        lastTrackURL = nil
    }

    // MARK: Track picker (pure, testable)

    // Picks a random URL from `pool`. If `avoiding` is non-nil and the
    // pool has at least one URL that isn't `avoiding`, returns one of
    // those (strict non-repeat). Falls back to any URL if the pool is
    // a single element that matches `avoiding`. Returns nil iff pool
    // is empty.
    //
    // Exposed for testing — MusicServiceTests verifies the non-repeat
    // contract without loading the AVAudioPlayer.
    static func pickTrack(from pool: [URL], avoiding last: URL?) -> URL? {
        guard !pool.isEmpty else { return nil }
        let candidates = pool.filter { $0 != last }
        let selected = candidates.isEmpty ? pool : candidates
        return selected.randomElement()
    }

    // MARK: Internals

    private func loadTrackPool() {
        for (env, filenames) in Self.tracksByState {
            var urls: [URL] = []
            for filename in filenames {
                if let url = Self.resolveBundleURL(for: filename) {
                    urls.append(url)
                } else {
                    print("MusicService: missing track '\(filename)' for \(env.rawValue)")
                }
            }
            trackPool[env] = urls
        }
    }

    // Splits a "Foo Bar.mp3"-style filename into base + extension and
    // looks up against the flat bundle root via
    // Bundle.main.url(forResource:withExtension:). Returns nil if the
    // file isn't bundled at all (user added a line to tracksByState
    // but hasn't committed the file).
    private static func resolveBundleURL(for filename: String) -> URL? {
        let ns = filename as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        guard !ext.isEmpty else { return nil }
        return Bundle.main.url(forResource: base, withExtension: ext)
    }

    // One-time startup log. Per-state pool counts should match the
    // tracksByState manifest lengths once bundling works.
    private func logPoolDiagnostic() {
        let order: [EnvironmentState] = [
            .thriving, .fading, .struggling, .dying, .dead, .ghostMall
        ]
        let counts = order.map { env in
            "\(env.rawValue):\(trackPool[env]?.count ?? 0)"
        }.joined(separator: " ")
        print("MusicService: loaded pools — \(counts)")
    }

    private func targetVolume(for env: EnvironmentState) -> Float {
        EnvironmentTuning.musicVolume[env] ?? 0.5
    }

    private func crossfadeToNewTrack() {
        guard let env = currentState else { return }
        let pool = trackPool[env] ?? []
        guard let url = Self.pickTrack(from: pool, avoiding: lastTrackURL) else {
            // No tracks in this state's pool — fade out the current
            // player and go silent until a state with tracks is entered.
            fadeOutAndStopActive()
            return
        }

        let newPlayer: AVAudioPlayer
        do {
            newPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            // File present but unreadable — stay on current track.
            return
        }
        newPlayer.prepareToPlay()
        newPlayer.volume = 0
        newPlayer.numberOfLoops = 0   // auto-advance on finish handled via delegate
        newPlayer.delegate = self

        // Fade out the outgoing player if any. Safe for a player that
        // just finished naturally (setVolume on a stopped player is a
        // no-op); the scheduled stop() is idempotent.
        if let outgoing = activePlayer {
            fadeOutAndStop(outgoing)
        }

        activePlayer = newPlayer
        lastTrackURL = url
        newPlayer.play()
        newPlayer.setVolume(targetVolume(for: env),
                             fadeDuration: Self.crossfadeDuration)
    }

    private func fadeOutAndStopActive() {
        if let outgoing = activePlayer {
            fadeOutAndStop(outgoing)
        }
        activePlayer = nil
    }

    private func fadeOutAndStop(_ player: AVAudioPlayer) {
        // Cancel any in-flight previous-player fade. Rapid consecutive
        // state changes shouldn't accumulate zombie players.
        previousPlayer?.stop()
        previousPlayer = player
        player.setVolume(0, fadeDuration: Self.crossfadeDuration)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.crossfadeDuration
        ) { [weak self, weak player] in
            // Only stop if we're still the designated previous player —
            // a subsequent crossfade may have already cycled us out.
            if self?.previousPlayer === player {
                player?.stop()
                self?.previousPlayer = nil
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension MusicService: AVAudioPlayerDelegate {
    // Track finished naturally → auto-advance. Gate on `flag` (true
    // means clean finish) and on the player being the active one
    // (ignore completion callbacks from an outgoing previousPlayer).
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                      successfully flag: Bool) {
        guard flag else { return }
        guard player === activePlayer else { return }
        crossfadeToNewTrack()
    }
}
