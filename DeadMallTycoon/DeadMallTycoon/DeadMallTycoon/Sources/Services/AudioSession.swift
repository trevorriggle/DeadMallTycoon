import AVFoundation

// v9 — AVAudioSession bootstrap.
//
// iOS defaults the shared audio session to .soloAmbient, which is
// silenced by the hardware silent switch and pauses on screen lock.
// For a music + ambient-hum game that defeats both layers: the device
// is muted, the players think they're playing, and nothing reaches the
// speakers. Configure .playback once at app launch so MusicService and
// AmbientHumPlayer produce audible output regardless of the ringer
// switch.
enum AudioSession {

    // Idempotent. Safe to call multiple times; setCategory + setActive
    // are cheap when already in the requested state. Errors are logged
    // and swallowed — if the session can't be configured the game still
    // runs, just silent.
    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession: configure failed — \(error.localizedDescription)")
        }
    }
}
