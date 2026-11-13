import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct SanhehueyWidgets: WidgetBundle {
    var body: some Widget {
        VPNLiveActivity()
    }
}

// MARK: - Оформление

private enum Look {
    static let jade = Color(red: 0.25, green: 0.85, blue: 0.63)
    static let amber = Color(red: 1.0, green: 0.69, blue: 0.13)
    static let crimson = Color(red: 1.0, green: 0.18, blue: 0.31)
    static let goldLight = Color(red: 0.91, green: 0.81, blue: 0.58)
    static let gold = Color(red: 0.79, green: 0.63, blue: 0.35)
    static let muted = Color(red: 0.58, green: 0.55, blue: 0.49)

    static let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.95, blue: 0.81), goldLight, gold],
        startPoint: .top, endPoint: .bottom
    )

    static func hero(_ size: CGFloat) -> Font { .custom("CinzelDecorative-Black", size: size) }
    static func title(_ size: CGFloat) -> Font { .custom("Prata-Regular", size: size) }
}

private extension VPNActivityAttributes.ContentState {
    var tint: Color {
        switch phase {
        case 2: return Look.jade
        case 1: return Look.amber
        default: return Look.crimson
        }
    }

    var title: String {
        switch phase {
        case 2: return "ПОД ЗАЩИТОЙ"
        case 1: return "ПОДКЛЮЧЕНИЕ"
        default: return "ОТКЛЮЧЕНО"
        }
    }

    var action: String {
        switch phase {
        case 2: return "Отключить"
        case 1: return "Отменить"
        default: return "Подключить"
        }
    }
}

/// Дракон: шаблонная картинка, красится в цвет состояния.
private struct Dragon: View {
    let name: String
    let tint: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: width, height: height)
            .foregroundStyle(
                LinearGradient(colors: [.white, tint], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: tint.opacity(0.8), radius: 5)
    }
}

/// Таймер: система сама обновляет его каждую секунду.
private struct Clock: View {
    let state: VPNActivityAttributes.ContentState

    var body: some View {
        if state.phase == 2, let since = state.since {
            Text(timerInterval: since...Date.distantFuture, countsDown: false)
                .monospacedDigit()
        } else if state.phase == 1 {
            Text("•••")
        } else {
            Text("ВЫКЛ")
        }
    }
}

/// Стеклянная кнопка-капсула включения и отключения.
private struct PowerCapsule: View {
    let state: VPNActivityAttributes.ContentState
    var compact = false

    var body: some View {
        Button(intent: ToggleVPNIntent()) {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: compact ? 13 : 16, weight: .semibold))
                Text(state.action)
                    .font(Look.title(compact ? 13 : 16))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.vertical, compact ? 8 : 12)
            .padding(.horizontal, compact ? 14 : 18)
            .background(
                ZStack {
                    Capsule().fill(state.tint.opacity(0.26))
                    Capsule().fill(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
            )
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), state.tint.opacity(0.35), .white.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: state.tint.opacity(0.45), radius: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Экран блокировки

private struct LockScreenView: View {
    let state: VPNActivityAttributes.ContentState
    let stale: Bool

    var body: some View {
        HStack(spacing: 14) {
            Dragon(name: "dragonfull", tint: state.tint, width: 30, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text("SanHeHuey")
                    .font(Look.hero(17))
                    .foregroundStyle(Look.goldGradient)
                    .lineLimit(1)
                Text(state.title)
                    .font(Look.title(12))
                    .tracking(2)
                    .foregroundStyle(state.tint)
                    .lineLimit(1)
                Text(state.mode)
                    .font(.system(size: 12))
                    .foregroundStyle(Look.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Clock(state: state)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 96, alignment: .trailing)
                PowerCapsule(state: state, compact: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .opacity(stale ? 0.6 : 1)
    }
}

// MARK: - Dynamic Island

struct VPNLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VPNActivityAttributes.self) { context in
            LockScreenView(state: context.state, stale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.78))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Dragon(name: "dragonhead", tint: context.state.tint, width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SanHeHuey")
                                .font(Look.hero(13))
                                .foregroundStyle(Look.goldGradient)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(context.state.mode)
                                .font(.system(size: 11))
                                .foregroundStyle(Look.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Clock(state: context.state)
                            .font(.system(size: 21, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 92, alignment: .trailing)
                        Text(context.state.title)
                            .font(Look.title(9))
                            .tracking(1.5)
                            .foregroundStyle(context.state.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PowerCapsule(state: context.state)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Dragon(name: "dragonhead", tint: context.state.tint, width: 24, height: 24)
            } compactTrailing: {
                Clock(state: context.state)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(context.state.tint)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 58, alignment: .trailing)
            } minimal: {
                Dragon(name: "dragonhead", tint: context.state.tint, width: 22, height: 22)
            }
            .keylineTint(context.state.tint)
        }
    }
}
