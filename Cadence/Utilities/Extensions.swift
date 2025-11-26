//
//  Extensions.swift
//  Cadence
//
//  Created by Andrew Nielsen on 11/26/25.
//

import SwiftUI

// MARK: - View Extensions

extension View {
    /// Applies a card-style background with surface color, corner radius, and shadow
    func cardStyle(padding: CGFloat = Theme.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.CornerRadius.lg)
            .shadow(
                color: Color.black.opacity(0.3),
                radius: Theme.Shadow.medium.radius,
                x: Theme.Shadow.medium.x,
                y: Theme.Shadow.medium.y
            )
    }

    /// Applies a scale effect on press with spring animation
    func pressableScale() -> some View {
        self.buttonStyle(PressableScaleButtonStyle())
    }

    /// Adds a glow effect with the specified color
    func glowEffect(color: Color, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Button Styles

/// Button style that scales down on press with spring animation
struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(Theme.Animation.smoothSpring, value: configuration.isPressed)
    }
}

/// Custom solid button style with primary color
struct SolidButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Sizes.buttonHeightLarge)
            .background(Theme.Colors.primary)
            .cornerRadius(Theme.CornerRadius.circle)
            .shadow(
                color: Theme.Colors.primary.opacity(0.4),
                radius: Theme.Shadow.large.radius,
                x: Theme.Shadow.large.x,
                y: Theme.Shadow.large.y
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Theme.Animation.spring, value: configuration.isPressed)
    }
}
