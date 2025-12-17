//
//  AdvancedMetronomeView.swift
//  Cadence
//
//  Created by Claude Code on 12/17/25.
//

import SwiftUI

/// Advanced metronome view with time signature control and beat tile visualization.
///
/// This view provides detailed control for complex practice scenarios, including:
/// - Time signature selection
/// - Individual beat enable/disable via tiles
/// - Visual beat tracking during playback
/// - Full tempo controls
struct AdvancedMetronomeView: View {
    @ObservedObject var metronome: Metronome

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: Theme.Spacing.md) {
                // Top spacing
                Spacer()
                    .frame(height: Theme.Spacing.sm)

                // Time signature control
                TimeSignatureControl(metronome: metronome)
                    .padding(.horizontal, Theme.Spacing.md)

                // Beat grid visualization
                BeatGridView(
                    metronome: metronome,
                    availableWidth: geometry.size.width * 0.85
                )
                .padding(.vertical, Theme.Spacing.lg)

                Spacer()

                // Tempo controls
                TempoControls(metronome: metronome)
                    .padding(.horizontal, Theme.Spacing.md)

                Spacer()
                    .frame(height: Theme.Spacing.lg)

                // Play/stop button
                TransportButton(metronome: metronome)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
    }
}

// MARK: - Preview

#Preview("4/4 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        AdvancedMetronomeView(metronome: {
            let m = Metronome()
            m.timeSignature = TimeSignature(beats: 4, noteValue: 4)
            return m
        }())
    }
    .preferredColorScheme(.dark)
}

#Preview("6/8 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        AdvancedMetronomeView(metronome: {
            let m = Metronome()
            m.timeSignature = TimeSignature(beats: 6, noteValue: 8)
            return m
        }())
    }
    .preferredColorScheme(.dark)
}

#Preview("12/8 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        AdvancedMetronomeView(metronome: {
            let m = Metronome()
            m.timeSignature = TimeSignature(beats: 12, noteValue: 8)
            return m
        }())
    }
    .preferredColorScheme(.dark)
}

#Preview("Playing State") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        AdvancedMetronomeView(metronome: {
            let m = Metronome()
            m.timeSignature = TimeSignature(beats: 4, noteValue: 4)
            m.currentBeat = 2 // Simulate playing on beat 3
            return m
        }())
    }
    .preferredColorScheme(.dark)
}
