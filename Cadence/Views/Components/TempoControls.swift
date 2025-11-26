//
//  TempoControls.swift
//  Cadence
//
//  Created by Andrew Nielsen on 11/26/25.
//

import SwiftUI
import AudioKit

/// A comprehensive tempo control with BPM display and slider
struct TempoControls: View {
    @ObservedObject var metronome: Metronome

    // Tempo range
    private let minTempo: Double = 40
    private let maxTempo: Double = 240

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // BPM display
            bpmDisplay

            // Slider
            tempoSlider
        }
    }

    /// BPM display
    private var bpmDisplay: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(Int(metronome.tempo))")
                .font(.system(size: Theme.Typography.displayLarge, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .animation(.none, value: metronome.tempo) // Prevent animation on text change

            Text("BPM")
                .font(.system(size: Theme.Typography.body, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(2)
        }
    }

    /// Styled slider for tempo adjustment
    private var tempoSlider: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Slider(
                value: Binding(
                    get: { Double(metronome.tempo) },
                    set: { metronome.tempo = BPM($0) }
                ),
                in: minTempo...maxTempo,
                step: 1
            )
            .accentColor(Theme.Colors.primary)

            // Min/max labels
            HStack {
                Text("\(Int(minTempo))")
                    .font(.system(size: Theme.Typography.caption, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                Text("\(Int(maxTempo))")
                    .font(.system(size: Theme.Typography.caption, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
    }
}

#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        TempoControls(metronome: Metronome())
            .padding()
    }
}
