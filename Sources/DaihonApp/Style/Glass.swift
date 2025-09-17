import SwiftUI

// Shared glass-style background for views.
// Uses materials as a compatible stand-in and can be
// swapped to Liquid Glass APIs when the toolchain supports them.
struct GlassPanelBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .platformGlassBackground(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
    }
}

extension View {
    /// Wraps content with a rounded, glass-like background.
    func glassPanel(radius: CGFloat = 16) -> some View {
        modifier(GlassPanelBackground(cornerRadius: radius))
    }

    /// Use Liquid Glass if available at compile- and runtime, else fall back to materials.
    @ViewBuilder
    func platformGlassBackground<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
                // Native Liquid Glass on newer macOS SDKs
                self.glassEffect(in: shape)
            } else if #available(macOS 15.0, *) {
                self.background(shape.fill(.ultraThinMaterial).opacity(0.82))
            } else {
                self.background(shape.fill(.ultraThinMaterial).opacity(0.82))
            }
    }
}
