//
//  AdvancedMetronomeView.swift
//  Cadence
//
//  Created by Claude Code on 12/17/25.
//

import SwiftUI

/// Advanced metronome view showing time signature control and beat grid.
///
/// This view is designed to be displayed in the TabView area, showing only the
/// visualizer components without tempo controls or transport buttons (those are shared).
struct AdvancedMetronomeView: View {
    @ObservedObject var metronome: Metronome
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Time signature control - pinned to top
            TimeSignatureControl(metronome: metronome)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)

            Spacer()
                .frame(height: Theme.Spacing.xl)

            // Beat grid visualization - responsive sizing
            BeatGridView(
                metronome: metronome,
                availableWidth: availableWidth,
                availableHeight: availableHeight - 120 // Account for time signature control + spacing
            )

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Preview

#Preview("4/4 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        AdvancedMetronomeView(
            metronome: {
                let m = Metronome()
                m.timeSignature = TimeSignature(beats: 4, noteValue: 4)
                return m
            }(),
            availableWidth: 350,
            availableHeight: 400
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("12/8 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        AdvancedMetronomeView(
            metronome: {
                let m = Metronome()
                m.timeSignature = TimeSignature(beats: 12, noteValue: 8)
                return m
            }(),
            availableWidth: 350,
            availableHeight: 400
        )
    }
    .preferredColorScheme(.dark)
}
