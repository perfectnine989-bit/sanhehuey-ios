import SwiftUI
import UIKit

/// Переключатель как в Telegram: прозрачная стеклянная «таблетка» едет за пальцем,
/// слегка растягивается от скорости и быстро встаёт на место. Переключение экрана
/// не зависит от её анимации, поэтому рывков нет.
struct GlassSegmented<Item: Hashable, Content: View>: View {
    let items: [Item]
    @Binding var selection: Item
    let tint: Color
    let height: CGFloat
    let corner: CGFloat
    let content: (Item, Bool) -> Content

    @State private var dragX: CGFloat? = nil
    @State private var settled: Int = 0
    @State private var stretch: CGFloat = 0
    @State private var lastIndex: Int = -1

    private let pad: CGFloat = 5

    init(
        items: [Item],
        selection: Binding<Item>,
        tint: Color,
        height: CGFloat = 62,
        corner: CGFloat = 22,
        @ViewBuilder content: @escaping (Item, Bool) -> Content
    ) {
        self.items = items
        self._selection = selection
        self.tint = tint
        self.height = height
        self.corner = corner
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let count = items.count
            let segW = (geo.size.width - pad * 2) / CGFloat(max(count, 1))
            let maxX = segW * CGFloat(max(count - 1, 0))
            let thumbX = dragX ?? CGFloat(settled) * segW
            let liveIndex = max(0, min(count - 1, Int(((thumbX + segW / 2) / segW).rounded(.down))))
            let pressed = dragX != nil
            let sx = (pressed ? 1.08 : 1.0) + stretch
            let sy = (pressed ? 1.08 : 1.0) - stretch * 0.5

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: corner + pad, style: .continuous)
                    .fill(Color.black.opacity(0.30))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner + pad, style: .continuous)
                            .stroke(Theme.goldDim.opacity(0.28), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.clear)
                    .liquidGlass(RoundedRectangle(cornerRadius: corner, style: .continuous), tint: tint, interactive: true)
                    .frame(width: segW, height: height)
                    .scaleEffect(x: sx, y: sy)
                    .animation(.spring(response: 0.24, dampingFraction: 0.74), value: sx)
                    .offset(x: pad + thumbX, y: pad)

                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { i in
                        content(items[i], i == liveIndex)
                            .frame(width: segW, height: height)
                            .animation(.easeOut(duration: 0.16), value: liveIndex)
                    }
                }
                .offset(x: pad, y: pad)
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(value.location.x - pad - segW / 2, 0), maxX)
                        if dragX == nil {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) { dragX = x }
                        } else {
                            dragX = x
                        }
                        stretch = min(abs(value.velocity.width) / 3800, 0.14)
                        let idx = Int((x / segW).rounded())
                        if idx != lastIndex {
                            if lastIndex != -1 {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                            lastIndex = idx
                        }
                    }
                    .onEnded { value in
                        let x = min(max(value.location.x - pad - segW / 2, 0), maxX)
                        let idx = max(0, min(count - 1, Int((x / segW).rounded())))
                        lastIndex = -1
                        // Таблетка встаёт на место своей анимацией…
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            dragX = nil
                            stretch = 0
                            settled = idx
                        }
                        // …а смена экрана идёт отдельно и сразу.
                        if items[idx] != selection {
                            selection = items[idx]
                        }
                    }
            )
        }
        .frame(height: height + pad * 2)
        .onAppear { settled = items.firstIndex(of: selection) ?? 0 }
        .onChange(of: selection) { _, newValue in
            if dragX == nil, let i = items.firstIndex(of: newValue), i != settled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) { settled = i }
            }
        }
    }
}
