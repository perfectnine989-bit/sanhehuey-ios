import AVFoundation
import UIKit

enum Sound: String, CaseIterable {
    case tick
    case tickHeavy = "tick_heavy"
    case whoosh
    case open
    case winCommon = "win_common"
    case winUncommon = "win_uncommon"
    case winRare = "win_rare"
    case winEpic = "win_epic"
    case winLegendary = "win_legendary"
    case coin
    case error
    case connect
    case disconnect
    case tap
}

/// Звуки лежат в приложении как wav (их синтезирует скрипт при сборке). Для тиков заводим по нескольку плееров, чтобы они накладывались.
final class SoundEngine {
    static let shared = SoundEngine()
    private var pools: [Sound: [AVAudioPlayer]] = [:]
    private var cursor: [Sound: Int] = [:]

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            let count = (sound == .tick || sound == .tickHeavy) ? 6 : 2
            var list: [AVAudioPlayer] = []
            for _ in 0..<count {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.enableRate = true
                    player.prepareToPlay()
                    list.append(player)
                }
            }
            pools[sound] = list
        }
    }

    func play(_ sound: Sound, volume: Float = 1.0, rate: Float = 1.0) {
        guard let list = pools[sound], !list.isEmpty else { return }
        let index = (cursor[sound] ?? 0) % list.count
        cursor[sound] = index + 1
        let player = list[index]
        player.currentTime = 0
        player.volume = volume
        player.rate = rate
        player.play()
    }
}

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    static func prepare() {
        light.prepare()
        rigid.prepare()
        heavy.prepare()
        notify.prepare()
    }

    static func tick(fast: Bool) {
        if fast {
            light.impactOccurred(intensity: 0.5)
        } else {
            rigid.impactOccurred(intensity: 1.0)
        }
    }

    static func heavyTap() { heavy.impactOccurred() }
    static func success() { notify.notificationOccurred(.success) }
    static func warn() { notify.notificationOccurred(.warning) }
    static func error() { notify.notificationOccurred(.error) }

    private static func after(_ seconds: Double, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
    }

    /// Чем реже приз, тем богаче вибрация.
    static func win(_ rarity: Rarity) {
        switch rarity {
        case .common, .uncommon:
            notify.notificationOccurred(.success)
        case .rare:
            heavy.impactOccurred()
            after(0.12) { heavy.impactOccurred(intensity: 0.7) }
        case .epic:
            heavy.impactOccurred()
            after(0.10) { rigid.impactOccurred() }
            after(0.22) { heavy.impactOccurred() }
            after(0.40) { notify.notificationOccurred(.success) }
        case .legendary:
            for i in 0..<6 {
                after(Double(i) * 0.09) { heavy.impactOccurred(intensity: 1.0) }
            }
            after(0.7) { notify.notificationOccurred(.success) }
            after(1.0) { heavy.impactOccurred() }
        }
    }
}
