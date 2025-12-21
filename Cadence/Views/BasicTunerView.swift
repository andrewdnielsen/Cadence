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
        VStack(spacing: Theme.Spacing.md) {
            // Note Display Card
            NoteDisplayCard(tuner: tuner)

            // Tuning Indicator
            TuningIndicator(cents: tuner.detectedCents)
                .padding(.horizontal, Theme.Spacing.xl)

            // Cents Display
            CentsDisplay(cents: tuner.detectedCents)

            // Frequency Display
            FrequencyDisplay(frequency: tuner.detectedFrequency)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, Theme.Spacing.lg)
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
}

// MARK: - Note Display Card

struct NoteDisplayCard: View {
    @ObservedObject var tuner: Tuner

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("NOTE")
                .font(.system(size: Theme.Typography.caption, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(2)

            Text(tuner.detectedNote)
                .font(.system(size: Theme.Typography.displayHuge, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 120)
        }
        .cardStyle(padding: Theme.Spacing.xl)
    }
}

// MARK: - Tuning Indicator

struct TuningIndicator: View {
    let cents: Double

    // Tuning states
    private var tuningState: TuningState {
        if abs(cents) < 5 {
            return .inTune
        } else if cents > 0 {
            return .sharp
        } else {
            return .flat
        }
    }

    // Calculate needle position (-1 to 1, clamped at ±50 cents)
    private var needlePosition: Double {
        let clamped = max(-50, min(50, cents))
        return clamped / 50.0
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Visual indicator with needle
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background gradient bar
                    HStack(spacing: 0) {
                        // Flat side (red gradient)
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.8),
                                Color.orange.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )

                        // In-tune center (green)
                        Color.green
                            .frame(width: geometry.size.width * 0.2)

                        // Sharp side (yellow/red gradient)
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.6),
                                Color.red.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .frame(height: 12)
                    .cornerRadius(Theme.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .stroke(Theme.Colors.surface, lineWidth: 2)
                    )

                    // Tick marks
                    HStack(spacing: 0) {
                        ForEach(0..<11) { index in
                            Rectangle()
                                .fill(Theme.Colors.textSecondary.opacity(0.3))
                                .frame(width: 1, height: index == 5 ? 20 : 12)

                            if index < 10 {
                                Spacer()
                            }
                        }
                    }
                    .offset(y: -6)

                    // Needle indicator
                    NeedleIndicator()
                        .offset(x: needlePosition * (geometry.size.width / 2) * 0.9)
                        .animation(Theme.Animation.smoothSpring, value: needlePosition)
                }
                .frame(height: 40)
            }
            .frame(height: 40)

            // Tuning state label
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: tuningStateIcon)
                    .font(.system(size: Theme.Typography.body, weight: .semibold))

                Text(tuningStateText)
                    .font(.system(size: Theme.Typography.body, weight: .semibold))
            }
            .foregroundColor(tuningStateColor)
            .animation(Theme.Animation.smoothSpring, value: tuningState)
        }
        .padding(.vertical, Theme.Spacing.md)
        .cardStyle()
    }

    private var tuningStateIcon: String {
        switch tuningState {
        case .inTune: return "checkmark.circle.fill"
        case .sharp: return "arrow.up.circle.fill"
        case .flat: return "arrow.down.circle.fill"
        }
    }

    private var tuningStateText: String {
        switch tuningState {
        case .inTune: return "IN TUNE"
        case .sharp: return "SHARP"
        case .flat: return "FLAT"
        }
    }

    private var tuningStateColor: Color {
        switch tuningState {
        case .inTune: return .green
        case .sharp: return .orange
        case .flat: return .orange
        }
    }
}

// MARK: - Needle Indicator

struct NeedleIndicator: View {
    var body: some View {
        VStack(spacing: 0) {
            // Triangle pointer
            Triangle()
                .fill(Theme.Colors.textPrimary)
                .frame(width: 12, height: 8)

            // Vertical line
            Rectangle()
                .fill(Theme.Colors.textPrimary)
                .frame(width: 2, height: 25)
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Triangle Shape

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

// MARK: - Cents Display

struct CentsDisplay: View {
    let cents: Double

    private var formattedCents: String {
        let rounded = Int(round(cents))
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("CENTS")
                .font(.system(size: Theme.Typography.caption, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(2)

            Text(formattedCents)
                .font(.system(size: Theme.Typography.displayMedium, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .monospacedDigit()
                .animation(.none, value: cents)
        }
    }
}

// MARK: - Frequency Display

struct FrequencyDisplay: View {
    let frequency: Double

    private var formattedFrequency: String {
        frequency > 0 ? String(format: "%.1f Hz", frequency) : "-- Hz"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "waveform")
                .font(.system(size: Theme.Typography.caption))

            Text(formattedFrequency)
                .font(.system(size: Theme.Typography.caption, weight: .medium))
        }
        .foregroundColor(Theme.Colors.textSecondary)
    }
}

// MARK: - Tuner Transport Button

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
                    .fill(tuner.isListening ? Color.red : Theme.Colors.primary)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(
                        color: (tuner.isListening ? Color.red : Theme.Colors.primary).opacity(0.4),
                        radius: Theme.Shadow.large.radius,
                        x: 0,
                        y: Theme.Shadow.large.y
                    )

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

// MARK: - Tuning State Enum

enum TuningState {
    case inTune
    case sharp
    case flat
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
