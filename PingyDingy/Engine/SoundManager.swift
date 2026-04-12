import AVFoundation
import Observation

enum PingSound: String, CaseIterable {
    case ping = "ping"
    case noPing = "noping"
    case tada = "tada"
    case wahwah = "Wahwahwah"
}

@Observable
final class SoundManager {
    var masterSoundEnabled: Bool = true

    private var players: [PingSound: AVAudioPlayer] = [:]
    private var lastTransitionTime: [UUID: Date] = [:]
    private let transitionCooldown: TimeInterval = 60

    init() {
        preloadSounds()
    }

    func preloadSounds() {
        for sound in PingSound.allCases {
            guard let url = Bundle.main.url(
                forResource: sound.rawValue,
                withExtension: "mp3",
                subdirectory: "Sounds"
            ) else {
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[sound] = player
            } catch {
                // Sound file failed to load — silent degradation
            }
        }
    }

    func playPingSound(success: Bool, hostSoundEnabled: Bool) {
        guard masterSoundEnabled, hostSoundEnabled else { return }
        let sound: PingSound = success ? .ping : .noPing
        play(sound)
    }

    func playTransitionSound(hostId: UUID, wentUp: Bool) {
        guard masterSoundEnabled else { return }

        let now = Date()
        if let lastTime = lastTransitionTime[hostId],
           now.timeIntervalSince(lastTime) < transitionCooldown {
            return
        }

        lastTransitionTime[hostId] = now
        let sound: PingSound = wentUp ? .tada : .wahwah
        play(sound)
    }

    private func play(_ sound: PingSound) {
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }
}
