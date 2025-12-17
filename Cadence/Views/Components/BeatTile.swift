//
//  BeatTile.swift
//  Cadence
//
//  Created by Claude Code on 12/17/25.
//

import SwiftUI

/// A visual tile representing a single beat in the metronome sequence.
///
/// The tile displays different states:
/// - Downbeat (first beat): Visually distinct with primary color
/// - Regular beat: Secondary styling
/// - Disabled: Dimmed appearance
/// - Current beat: Highlighted during playback
struct BeatTile: View {
    /// The beat number (1-based for display, e.g., "1", "2", "3")
    let beatNumber: Int

    /// Whether this is the downbeat (first beat of the measure)
    let isDownbeat: Bool

    /// Whether this beat is currently enabled
    @Binding var isEnabled: Bool

    /// Whether this beat is currently being played
    let isCurrent: Bool

    /// Callback when tile is tapped to toggle state
    let onToggle: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            onToggle()
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(tileColor)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(borderColor, lineWidth: isCurrent ? 3 : 0)
                    )
                    .shadow(
                        color: shadowColor,
                        radius: isCurrent ? 8 : 4,
                        x: 0,
                        y: 2
                    )

                // Beat number
                Text("\(beatNumber)")
                    .font(.system(size: Theme.Typography.title, weight: .bold))
                    .foregroundColor(textColor)
            }
            .scaleEffect(scaleEffect)
            .opacity(opacity)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPressed = false
                    }
                }
        )
        .animation(Theme.Animation.smoothSpring, value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }

    // MARK: - Computed Properties

    /// The color of the tile based on state
    private var tileColor: Color {
        if !isEnabled {
            return Theme.Colors.surface
        }
        return isDownbeat ? Theme.Colors.primary : Color.gray.opacity(0.3)
    }

    /// The border color when current beat is playing
    private var borderColor: Color {
        return isCurrent ? Theme.Colors.primary : .clear
    }

    /// The shadow color based on state
    private var shadowColor: Color {
        if isCurrent && isEnabled {
            return Theme.Colors.primary.opacity(0.6)
        }
        return Color.black.opacity(0.2)
    }

    /// The text color based on state
    private var textColor: Color {
        if !isEnabled {
            return Theme.Colors.textSecondary.opacity(0.4)
        }
        return isDownbeat ? .white : Theme.Colors.textPrimary
    }

    /// Scale effect for press and current beat
    private var scaleEffect: CGFloat {
        if isPressed {
            return 0.9
        }
        if isCurrent && isEnabled {
            return 1.1
        }
        return 1.0
    }

    /// Opacity based on enabled state
    private var opacity: Double {
        return isEnabled ? 1.0 : 0.4
    }
}

// MARK: - Preview

#Preview("Beat States") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        VStack(spacing: Theme.Spacing.xl) {
            Text("Beat Tile States")
                .font(.system(size: Theme.Typography.title, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)

            // Downbeat - Enabled
            HStack(spacing: Theme.Spacing.lg) {
                BeatTile(
                    beatNumber: 1,
                    isDownbeat: true,
                    isEnabled: .constant(true),
                    isCurrent: false,
                    onToggle: {}
                )
                Text("Downbeat\nEnabled")
                    .font(.system(size: Theme.Typography.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Regular Beat - Enabled
            HStack(spacing: Theme.Spacing.lg) {
                BeatTile(
                    beatNumber: 2,
                    isDownbeat: false,
                    isEnabled: .constant(true),
                    isCurrent: false,
                    onToggle: {}
                )
                Text("Regular\nEnabled")
                    .font(.system(size: Theme.Typography.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Beat - Disabled
            HStack(spacing: Theme.Spacing.lg) {
                BeatTile(
                    beatNumber: 3,
                    isDownbeat: false,
                    isEnabled: .constant(false),
                    isCurrent: false,
                    onToggle: {}
                )
                Text("Beat\nDisabled")
                    .font(.system(size: Theme.Typography.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Current Beat
            HStack(spacing: Theme.Spacing.lg) {
                BeatTile(
                    beatNumber: 4,
                    isDownbeat: false,
                    isEnabled: .constant(true),
                    isCurrent: true,
                    onToggle: {}
                )
                Text("Current\nBeat")
                    .font(.system(size: Theme.Typography.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
