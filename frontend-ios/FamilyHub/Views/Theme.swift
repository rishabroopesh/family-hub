import SwiftUI

// MARK: - App Gradient

enum AppTheme {
    static let gradient = LinearGradient(
        colors: [.purple, .pink, .orange],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.56, green: 0.27, blue: 0.96), Color(red: 0.93, green: 0.35, blue: 0.60)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let subtleGradient = LinearGradient(
        colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBorder = LinearGradient(
        colors: [Color.purple.opacity(0.5), Color.pink.opacity(0.3), Color.orange.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Gradient Text Modifier

struct GradientText: ViewModifier {
    var gradient: LinearGradient

    func body(content: Content) -> some View {
        content
            .overlay(gradient.mask(content))
    }
}

extension View {
    func gradientForeground(_ gradient: LinearGradient = AppTheme.gradient) -> some View {
        self.overlay(gradient)
            .mask(self)
    }
}

// MARK: - Accent Card Style

struct AccentCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground))
                    .shadow(color: Color.purple.opacity(colorScheme == .dark ? 0.15 : 0.08),
                            radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func accentCard() -> some View {
        self.modifier(AccentCard())
    }
}

// MARK: - Vibrant Badge

struct VibrantBadge: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.subtleGradient)
        .foregroundStyle(AppTheme.accentGradient)
        .clipShape(Capsule())
    }
}

// MARK: - Gradient Accent Bar

struct GradientBar: View {
    var width: CGFloat = 4
    var cornerRadius: CGFloat = 2

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.accentGradient)
            .frame(width: width)
    }
}
