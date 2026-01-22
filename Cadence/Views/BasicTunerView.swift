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

    // Dot size based on sustained time (grows slowly and dramatically)
    private var dotSize: CGFloat {
        let baseSize: CGFloat = 14
        let maxSize: CGFloat = 28  // Larger max size for dramatic growth
        let growthFactor = min(sustainedTime / 3.0, 1.0)  // Slower growth over 3 seconds
        return baseSize + (maxSize - baseSize) * growthFactor
    }

    // Glow radius based on sustained time (more dramatic)
    private var glowRadius: CGFloat {
        let baseGlow: CGFloat = 8
        let maxGlow: CGFloat = 24  // Larger glow
        let growthFactor = min(sustainedTime / 3.0, 1.0)  // Slower growth
        return baseGlow + (maxGlow - baseGlow) * growthFactor
    }

    // Glow intensity based on sustained time
    private var glowIntensity: Double {
        min(sustainedTime / 3.0, 1.0)
    }

    // Check if in tune
    private var isInTune: Bool {
        abs(cents) < 3.0
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size * 0.42

            ZStack {
                // Grey arc line (180° semicircle)
                Circle()
                    .trim(from: 0.0, to: 0.5)
                    .stroke(Theme.Colors.surface, lineWidth: 10)
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(180))

                // Center marker (green triangle at top)
                Triangle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .offset(y: -radius - 12)
                    .shadow(color: isInTune ? .green.opacity(0.6) : .clear, radius: 8)
                    .scaleEffect(isInTune ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.7), value: isInTune)

                // Moving dot along the arc
                if note != "--" {
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                        // Enhanced layered glow effect
                        .shadow(color: dotColor.opacity(0.9), radius: 4, x: 0, y: 0)  // Tight inner glow
                        .shadow(color: dotColor.opacity(0.6 * glowIntensity), radius: glowRadius * 0.5, x: 0, y: 0)  // Medium glow
                        .shadow(color: dotColor.opacity(0.4 * glowIntensity), radius: glowRadius, x: 0, y: 0)  // Outer glow
                        .shadow(color: dotColor.opacity(0.2 * glowIntensity), radius: glowRadius * 1.5, x: 0, y: 0)  // Soft halo
                        .modifier(ArcPositionModifier(angle: dotAngle, radius: radius))
                        .opacity(isSignalActive ? 1.0 : 0.3)  // Fade when signal drops
                        .animation(.spring(duration: 0.3, bounce: 0.15), value: dotAngle)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dotSize)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: glowRadius)
                        .animation(.easeInOut(duration: 0.2), value: isSignalActive)
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
                    .animation(.easeInOut(duration: 0.2), value: isSignalActive)

                    if note != "--" {
                        Text(formattedCents)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .monospacedDigit()
                            .opacity(isSignalActive ? 1.0 : 0.3)  // Dim when no signal
                            .animation(.easeInOut(duration: 0.2), value: isSignalActive)
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

// MARK: - Arc Position Modifier

/// Custom modifier that positions view along an arc by animating the angle
/// This ensures the view always follows the arc curve, never cuts across
struct ArcPositionModifier: AnimatableModifier {
    var angle: Double  // This gets interpolated by SwiftUI
    let radius: CGFloat

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(
            x: radius * sin(angle * .pi / 180.0),
            y: -radius * cos(angle * .pi / 180.0)
        )
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
