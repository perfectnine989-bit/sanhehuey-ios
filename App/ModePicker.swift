import SwiftUI

struct ModePicker: View {
    @EnvironmentObject var vpn: VPNManager
    let palette: Palette

    var body: some View {
        GlassSegmented(
            items: RouteMode.allCases,
            selection: Binding(get: { vpn.mode }, set: { vpn.setMode($0) }),
            tint: palette.main.opacity(0.14),
            height: 62,
            corner: 22
        ) { mode, isSelected in
            HStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .font(.system(size: 19))
                    .foregroundColor(isSelected ? Color.white : Theme.goldDim)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title)
                        .font(Theme.title(15))
                        .foregroundColor(isSelected ? Color.white : Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(mode.caption)
                        .font(Theme.body(12))
                        .foregroundColor(isSelected ? Color.white.opacity(0.85) : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}
