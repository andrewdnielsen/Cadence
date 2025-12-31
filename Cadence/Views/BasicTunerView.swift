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
                cents: tuner.detectedCents,
                isSignalActive: tuner.isSignalActive,
                sustainedTime: tuner.sustainedInTuneTime
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
    let isSignalActive: Bool
    let sustainedTime: Double

    // Split note into letter and octave for formatting
    private var noteParts: (letter: String, octave: String) {
        if note == "--" {
            return ("--", "")
        }
        // Extract note letter (can be 1-2 characters for sharps/flats)
        let noteLetterEndIndex = note.lastIndex(where: { $0.isLetter || $0 == "#" || $0 == "♯" || $0 == "♭" }) ?? note.startIndex
        let noteLetter = String(note[...noteLetterEndIndex])
        let octave = String(note[note.index(after: noteLetterEndIndex)...])
        return (noteLetter, octave)
    }

    // Calculate angle for the dot position
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

    // Dot size based on sustained time (grows when held in tune)
    private var dotSize: CGFloat {
        let baseSize: CGFloat = 14  // Reduced for better visual alignment with arc
        let maxSize: CGFloat = 22
        let growthFactor = min(sustainedTime / 1.5, 1.0)  // Max at 1.5 seconds
        return baseSize + (maxSize - baseSize) * growthFactor
    }

    // Glow radius based on sustained time
    private var glowRadius: CGFloat {
        let baseGlow: CGFloat = 8
        let maxGlow: CGFloat = 16
        let growthFactor = min(sustainedTime / 1.5, 1.0)
        return baseGlow + (maxGlow - baseGlow) * growthFactor
    }

    // Inner arc stroke width (grows when sustained in tune)
    private var innerArcStroke: CGFloat {
        let maxStroke: CGFloat = 6
        let growthFactor = min(max(sustainedTime - 0.5, 0.0) / 1.0, 1.0)  // Starts after 0.5s
        return maxStroke * growthFactor
    }

    // Inner arc glow intensity
    private var innerArcGlow: Double {
        let maxGlow = 0.8
        let growthFactor = min(max(sustainedTime - 0.5, 0.0) / 1.0, 1.0)
        return maxGlow * growthFactor
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size * 0.42

            ZStack {
                // Grey arc line (180° semicircle)
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Theme.Colors.surface, lineWidth: 10)
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(90))

                // Inner green arc (grows when sustained in tune)
                if innerArcStroke > 0 {
                    Circle()
                        .trim(from: 0.25, to: 0.75)
                        .stroke(Color.green, lineWidth: innerArcStroke)
                        .frame(width: radius * 2, height: radius * 2)  // Same radius as gray arc to overlay
                        .rotationEffect(.degrees(90))
                        .shadow(color: Color.green.opacity(innerArcGlow), radius: 6, x: 0, y: 0)
                        .shadow(color: Color.green.opacity(innerArcGlow * 0.6), radius: 12, x: 0, y: 0)
                        .shadow(color: Color.green.opacity(innerArcGlow * 0.3), radius: 20, x: 0, y: 0)
                        .animation(Theme.Animation.smoothSpring, value: innerArcStroke)
                }

                // Center marker (green triangle at top)
                Triangle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .offset(y: -radius - 12)

                // Moving dot along the arc
                if note != "--" {
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                        .shadow(color: dotColor.opacity(0.8), radius: 4, x: 0, y: 0)  // Tight inner glow
                        .shadow(color: dotColor.opacity(0.5), radius: glowRadius, x: 0, y: 0)  // Medium glow
                        .shadow(color: dotColor.opacity(0.2), radius: glowRadius * 1.5, x: 0, y: 0)  // Soft outer glow
                        .offset(x: calculateDotX(angle: dotAngle, radius: radius),
                               y: calculateDotY(angle: dotAngle, radius: radius))
                        .opacity(isSignalActive ? 1.0 : 0.3)  // Fade when signal drops
                        .animation(Theme.Animation.smoothSpring, value: dotAngle)
                        .animation(Theme.Animation.smoothSpring, value: dotColor)
                        .animation(Theme.Animation.smoothSpring, value: dotSize)
                        .animation(Theme.Animation.smoothSpring, value: isSignalActive)
                }

                // Note name and cents inside the arc
                VStack(spacing: Theme.Spacing.xs) {
                    // Note display with smaller octave number
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(noteParts.letter)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)

                        if !noteParts.octave.isEmpty {
                            Text(noteParts.octave)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .baselineOffset(-4)
                        }
                    }
                    .monospacedDigit()
                    .opacity(isSignalActive ? 1.0 : 0.3)  // Dim when no signal
                    .animation(Theme.Animation.smoothSpring, value: isSignalActive)

                    if note != "--" {
                        Text(formattedCents)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .monospacedDigit()
                            .opacity(isSignalActive ? 1.0 : 0.3)  // Dim when no signal
                            .animation(Theme.Animation.smoothSpring, value: isSignalActive)
                    }
                }
                .offset(y: radius * 0.15)
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

// MARK: - Triangle Shape (for center marker)

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
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
