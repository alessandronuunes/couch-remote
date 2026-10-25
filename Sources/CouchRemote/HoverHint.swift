import SwiftUI

/// The control under the mouse and what it does, reported up to the popover so it can draw the bubble
/// above every other view (a bubble drawn by the control itself would be covered by its neighbours).
private struct HoverHint {
    let text: String
    let bounds: Anchor<CGRect>
}

private struct HoverHintKey: PreferenceKey {
    static let defaultValue: HoverHint? = nil

    static func reduce(value: inout HoverHint?, nextValue: () -> HoverHint?) {
        value = value ?? nextValue()
    }
}

private struct HintOnHover: ViewModifier {
    let text: String
    @State private var inside = false
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .accessibilityHint(text)
            .onHover { hovering in
                inside = hovering
                if !hovering { shown = false }
            }
            // A short delay, so sweeping the mouse across the remote doesn't flash a bubble per button.
            .task(id: inside) {
                guard inside else { return }
                try? await Task.sleep(for: .milliseconds(350))
                if !Task.isCancelled { shown = true }
            }
            .anchorPreference(key: HoverHintKey.self, value: .bounds) { bounds in
                shown ? HoverHint(text: text, bounds: bounds) : nil
            }
    }
}

extension View {
    /// Explains a control in a bubble while the mouse rests on it. `.help` tooltips rarely appear in a menu
    /// bar window, so this draws its own (and no `.help`, which would show a second tooltip when it does appear).
    func hint(_ text: String) -> some View {
        modifier(HintOnHover(text: text))
    }

    /// Draws the bubble for whichever `hint` control is hovered. Apply once, on the outermost view.
    func hintBubbles() -> some View {
        overlayPreferenceValue(HoverHintKey.self) { hint in
            GeometryReader { proxy in
                if let hint {
                    let rect = proxy[hint.bounds]
                    let width: CGFloat = 230
                    // Below the control when there is no room above it (the header row).
                    let above = rect.minY > 56
                    HintBubble(text: hint.text)
                        .frame(width: width, height: 0, alignment: above ? .bottom : .top)
                        .position(
                            x: min(max(rect.midX, width / 2 + 6), proxy.size.width - width / 2 - 6),
                            y: above ? rect.minY - 6 : rect.maxY + 6
                        )
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.12), value: hint?.text)
        }
    }
}

private struct HintBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.primary.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}
