import SwiftUI

struct ModePicker: View {
    @EnvironmentObject var vpn: VPNManager
    let palette: Palette
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RouteMode.allCases, id: \.self) { mode in
                segment(mode)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Theme.goldDim.opacity(0.35), lineWidth: 1)
        )
    }

    private func segment(_ mode: RouteMode) -> some View {
        let selected = vpn.mode == mode
        return ZStack {
            if selected {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.clear)
                    .liquidGlass(RoundedRectangle(cornerRadius: 26, style: .continuous), tint: palette.main.opacity(0.5), interactive: true)
                    .matchedGeometryEffect(id: "thumb", in: ns)
            }
            HStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(selected ? Color.white : Theme.goldDim)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(Theme.body(15))
                        .foregroundColor(selected ? Color.white : Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(mode.caption)
                        .font(Theme.body(11))
                        .foregroundColor(selected ? Color.white.opacity(0.8) : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.white)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                vpn.setMode(mode)
            }
        }
    }
}
