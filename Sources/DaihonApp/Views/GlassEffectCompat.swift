import SwiftUI

// Enhanced Liquid Glass compatibility following Apple's Tahoe design system
extension View {
    @ViewBuilder
    func compatGlassEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect()
        } else if #available(macOS 15.0, *) {
            self.background(.thinMaterial.opacity(0.85))
        } else {
            self.background(.thinMaterial.opacity(0.85))
        }
    }

    @ViewBuilder
    func compatGlassEffect<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: shape)
        } else if #available(macOS 15.0, *) {
            self.background(.thinMaterial.opacity(0.85), in: shape)
        } else {
            self.background(.thinMaterial.opacity(0.85), in: shape)
        }
    }

    @ViewBuilder
    func compatGlassEffectThick<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: shape)
        } else if #available(macOS 15.0, *) {
            self.background(.regularMaterial.opacity(0.9), in: shape)
        } else {
            self.background(.regularMaterial.opacity(0.9), in: shape)
        }
    }
    
    @ViewBuilder
    func compatGlassEffectUltraThick<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: shape)
        } else if #available(macOS 15.0, *) {
            self.background(.thickMaterial.opacity(0.95), in: shape)
        } else {
            self.background(.thickMaterial.opacity(0.95), in: shape)
        }
    }
}

// Tahoe-style glass panel with proper shadows and borders
struct TahoeGlassPanel<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let shadowIntensity: CGFloat
    
    init(
        cornerRadius: CGFloat = 12,
        shadowIntensity: CGFloat = 0.1,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowIntensity = shadowIntensity
        self.content = content()
    }
    
    var body: some View {
        content
            .compatGlassEffectThick(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: .black.opacity(shadowIntensity),
                radius: 8,
                y: 2
            )
            .shadow(
                color: .black.opacity(shadowIntensity * 0.5),
                radius: 20,
                y: 4
            )
    }
}

// Tahoe-style button with glass effect
struct TahoeGlassButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    let isPressed: Bool
    
    init(
        isPressed: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isPressed = isPressed
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .compatGlassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

// Tahoe-style sidebar background
struct TahoeSidebarBackground: View {
    var body: some View {
        if #available(macOS 15.0, *) {
            Rectangle()
                .fill(.thinMaterial)
        } else {
            Rectangle()
                .fill(Color(NSColor.controlBackgroundColor))
        }
    }
}

// Tahoe-style primary background
struct TahoePrimaryBackground: View {
    var body: some View {
        if #available(macOS 15.0, *) {
            Rectangle()
                .fill(.regularMaterial.opacity(0.3))
        } else {
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        }
    }
}