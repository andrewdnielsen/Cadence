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
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Note Display
            Text(tuner.detectedNote)
                .font(.system(size: Theme.Typography.displayHuge, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .accessibilityLabel("Detected note")
                .accessibilityValue(tuner.detectedNote)

            // Frequency Display
            Text(String(format: "%.1f Hz", tuner.detectedFrequency))
                .font(.system(size: Theme.Typography.title))
                .foregroundColor(Theme.Colors.textSecondary)
                .accessibilityLabel("Frequency")
                .accessibilityValue("\(Int(tuner.detectedFrequency)) hertz")

            // Cents Display with Color Coding
            VStack(spacing: Theme.Spacing.sm) {
                // Cents Value
                Text(String(format: "%+.0f", tuner.detectedCents))
                    .font(.system(size: Theme.Typography.displayMedium, weight: .semibold))
                    .foregroundColor(centsColor)
                    .accessibilityLabel("Cents offset")
                    .accessibilityValue("\(Int(tuner.detectedCents)) cents \(tuner.detectedCents > 0 ? "sharp" : "flat")")

                Text("cents")
                    .font(.system(size: Theme.Typography.subtitle))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Visual Tuning Indicator
            TuningIndicator(cents: tuner.detectedCents)
                .frame(width: 280, height: 60)
                .padding(.vertical, Theme.Spacing.md)

            // Amplitude Indicator
            HStack(spacing: Theme.Spacing.sm) {
                Text("Signal:")
                    .font(.system(size: Theme.Typography.body))
                    .foregroundColor(Theme.Colors.textSecondary)

                ProgressView(value: min(tuner.amplitude, 1.0), total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.Colors.primary))
                    .frame(width: 150)

                Text(String(format: "%.1f", tuner.amplitude))
                    .font(.system(size: Theme.Typography.body))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            // Start/Stop Button
            TunerTransportButton(tuner: tuner)
                .padding(.bottom, Theme.Spacing.md)
        }
        .onAppear {
            // Auto-start tuner when view appears
            if !tuner.isListening {
                tuner.isListening = true
            }
        }
        .onDisappear {
            // Stop tuner when view disappears
            if tuner.isListening {
                tuner.isListening = false
            }
        }
    }

    // Color coding based on tuning accuracy
    private var centsColor: Color {
        let absCents = abs(tuner.detectedCents)

        if tuner.detectedNote == "--" {
            return Theme.Colors.textSecondary
        } else if absCents < 5 {
            return .green // Very close - in tune
        } else if absCents < 15 {
            return .yellow // Getting close
        } else {
            return .red // Out of tune
        }
    }
}

// MARK: - Tuning Indicator Component

struct TuningIndicator: View {
    let cents: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background line
                Rectangle()
                    .fill(Theme.Colors.surface)
                    .frame(height: 4)

                // Center marker (perfect tune)
                Rectangle()
                    .fill(.green)
                    .frame(width: 3, height: 40)

                // Tick marks
                ForEach([-50, -25, 0, 25, 50], id: \.self) { tick in
                    Rectangle()
                        .fill(Theme.Colors.textSecondary.opacity(0.5))
                        .frame(width: 1, height: tick == 0 ? 30 : 20)
                        .offset(x: CGFloat(tick) * (geometry.size.width / 100) / 2)
                }

                // Moving indicator
                if cents != 0 || cents == 0 {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 16, height: 16)
                        .offset(x: offset(for: cents, width: geometry.size.width))
                        .animation(Theme.Animation.smoothSpring, value: cents)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var indicatorColor: Color {
        let absCents = abs(cents)

        if absCents < 5 {
            return .green
        } else if absCents < 15 {
            return .yellow
        } else {
            return .red
        }
    }

    private func offset(for cents: Double, width: CGFloat) -> CGFloat {
        // Clamp cents to -50 to +50 range
        let clampedCents = max(-50, min(50, cents))
        // Map to pixel offset
        return CGFloat(clampedCents) * (width / 100) / 2
    }
}

// MARK: - Tuner Transport Button Component

struct TunerTransportButton: View {
    @ObservedObject var tuner: Tuner

    @State private var isPressed = false

    var body: some View {
        let buttonSize: CGFloat = 90
        let iconSize: CGFloat = 36

        Button(action: {
            tuner.toggle()
        }) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary)
                    .frame(width: buttonSize, height: buttonSize)

                // Icon
                Image(systemName: tuner.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(Theme.Animation.spring) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(Theme.Animation.spring) {
                        isPressed = false
                    }
                }
        )
        .animation(Theme.Animation.spring, value: tuner.isListening)
        .accessibilityLabel(tuner.isListening ? "Stop tuner" : "Start tuner")
        .accessibilityValue(tuner.isListening ? "Listening" : "Stopped")
        .accessibilityHint("Double tap to toggle the tuner")
    }
}

#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        BasicTunerView(tuner: Tuner())
    }
    .preferredColorScheme(.dark)
}
