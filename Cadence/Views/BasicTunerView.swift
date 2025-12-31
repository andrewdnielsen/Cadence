//
//  BasicTunerView.swift
//  Cadence
//
//  Created by Claude Code on 2025-12-21.
//

import SwiftUI

struct BasicTunerView: View {
    @ObservedObject var tuner: Tuner

    var body: some View {
        VStack {
            Spacer()

            // Compact circular tuner with arc and moving dot
            CompactCircularTuner(
                note: tuner.detectedNote,
                cents: tuner.detectedCents
            )
            .frame(height: 280)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            if !tuner.isListening {
                tuner.isListening = true
            }
        }
        .onDisappear {
            if tuner.isListening {
                tuner.isListening = false
            }
        }
    }
}

// MARK: - Compact Circular Tuner

struct CompactCircularTuner: View {
    let note: String
    let cents: Double

    // Calculate angle for the dot position
    // -50 cents = -90°, 0 cents = 0° (top), +50 cents = +90°
    private var dotAngle: Double {
        let clampedCents = max(-50, min(50, cents))
        return (clampedCents / 50.0) * 90.0
    }

    // Dot color based on cents offset
    private var dotColor: Color {
        let absCents = abs(cents)
        if absCents < 5 {
            return .green
        } else if absCents < 25 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size * 0.42
            let dotRadius: CGFloat = 10

            ZStack {
                // Grey arc line (180° semicircle)
                Circle()
                    .trim(from: 0.25, to: 0.75)  // Bottom half removed
                    .stroke(Theme.Colors.surface, lineWidth: 10)
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(90))  // Rotate so open end is at bottom

                // Moving dot along the arc (only shown when note detected)
                if note != "--" {
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotRadius * 2, height: dotRadius * 2)
                        .shadow(color: dotColor.opacity(0.6), radius: 8, x: 0, y: 0)
                        .offset(x: calculateDotX(angle: dotAngle, radius: radius),
                               y: calculateDotY(angle: dotAngle, radius: radius))
                        .animation(Theme.Animation.smoothSpring, value: dotAngle)
                        .animation(Theme.Animation.smoothSpring, value: dotColor)
                }

                // Note name and cents inside the arc
                VStack(spacing: Theme.Spacing.xs) {
                    Text(note)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .monospacedDigit()

                    if note != "--" {
                        Text(formattedCents)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .monospacedDigit()
                    }
                }
                .offset(y: radius * 0.15)  // Slightly below center for better visual balance
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    // Calculate X position of dot on the arc
    private func calculateDotX(angle: Double, radius: CGFloat) -> CGFloat {
        return radius * sin(angle * .pi / 180.0)
    }

    // Calculate Y position of dot on the arc
    private func calculateDotY(angle: Double, radius: CGFloat) -> CGFloat {
        return -radius * cos(angle * .pi / 180.0)
    }

    // Format cents with +/- sign
    private var formattedCents: String {
        if cents == 0 {
            return "0 cents"
        }
        let rounded = Int(round(cents))
        let sign = rounded > 0 ? "+" : ""
        return "\(sign)\(rounded) cents"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        BasicTunerView(tuner: Tuner())
    }
    .preferredColorScheme(.dark)
}
