import UIKit

/// Тактильная отдача только на включение и отключение VPN. Звуков в приложении нет.
enum Haptics {
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()

    /// Нажатие на большую кнопку.
    static func press() {
        heavy.impactOccurred()
    }

    /// VPN включился: тугой щелчок, затем «успех» и мягкое послевкусие.
    static func connected() {
        rigid.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { notify.notificationOccurred(.success) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { soft.impactOccurred(intensity: 0.6) }
    }

    /// VPN выключился: удар и два затухающих отголоска.
    static func disconnected() {
        heavy.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { soft.impactOccurred(intensity: 0.55) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { soft.impactOccurred(intensity: 0.3) }
    }
}
