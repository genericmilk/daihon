import SwiftUI

// Compatibility wrapper for glassEffect following Apple's Liquid Glass design
extension View {
    @ViewBuilder
    func compatGlassEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect()
        } else {
            // Use thin material with slight opacity for glass-like appearance
            self.background(.thinMaterial.opacity(0.8))
        }
    }

    @ViewBuilder
    func compatGlassEffect<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            // Use thin material with shape for better glass appearance
            self.background(.thinMaterial.opacity(0.8), in: shape)
        }
    }

    @ViewBuilder
    func compatGlassEffectThick<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            // Thicker glass effect for more prominent elements
            self.background(.regularMaterial.opacity(0.9), in: shape)
        }
    }
}