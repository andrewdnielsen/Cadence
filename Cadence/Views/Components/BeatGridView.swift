//
//  BeatGridView.swift
//  Cadence
//
//  Created by Claude Code on 12/17/25.
//

import SwiftUI

/// A grid view displaying all beat tiles for the current time signature.
///
/// This view dynamically generates BeatTile components based on the metronome's
/// time signature and provides visual feedback for the current beat during playback.
struct BeatGridView: View {
    @ObservedObject var metronome: Metronome

    var body: some View {
        let columns = gridColumns(for: metronome.timeSignature.beats)

        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(0..<metronome.timeSignature.beats, id: \.self) { index in
                BeatTile(
                    beatNumber: index + 1,
                    isDownbeat: index == 0,
                    isEnabled: Binding(
                        get: {
                            guard index < metronome.beatsEnabled.count else { return true }
                            return metronome.beatsEnabled[index]
                        },
                        set: { _ in
                            metronome.toggleBeat(at: index)
                        }
                    ),
                    isCurrent: metronome.isPlaying && metronome.currentBeat == index,
                    onToggle: {
                        metronome.toggleBeat(at: index)
                    }
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Helper Methods

    /// Calculates optimal grid columns based on number of beats
    /// - Parameter beatCount: Total number of beats in the measure
    /// - Returns: Array of GridItem columns for LazyVGrid
    private func gridColumns(for beatCount: Int) -> [GridItem] {
        let beatsPerRow: Int

        // Special handling for compound time signatures (multiples of 3)
        if beatCount > 3 && beatCount % 3 == 0 {
            // Multiples of 3 (6/8, 9/8, 12/8): group in threes
            // 6/8: 2 rows × 3, 9/8: 3 rows × 3, 12/8: 4 rows × 3
            beatsPerRow = 3
        } else if beatCount <= 6 {
            // 2-6 beats (not multiples of 3): single row
            beatsPerRow = beatCount
        } else if beatCount <= 8 {
            // 7-8 beats: single row
            beatsPerRow = beatCount
        } else {
            // 9+ beats (not multiples of 3): split into 2 rows
            beatsPerRow = (beatCount + 1) / 2
        }

        // Adaptive sizing: use fixed width for small counts, flexible for larger
        if beatsPerRow <= 5 {
            // 5 or fewer beats per row: use fixed width for consistent spacing
            // 70pt = 60pt tile + 10pt spacing buffer
            return Array(repeating: GridItem(.fixed(70), spacing: Theme.Spacing.sm), count: beatsPerRow)
        } else {
            // 6+ beats per row: use adaptive sizing to fit screen
            return Array(repeating: GridItem(.adaptive(minimum: 60, maximum: 70), spacing: Theme.Spacing.sm), count: beatsPerRow)
        }
    }
}

// MARK: - Preview

#Preview("4/4 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        VStack {
            Text("4/4 Time Signature")
                .font(.system(size: Theme.Typography.title, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.bottom, Theme.Spacing.md)

            BeatGridView(metronome: {
                let m = Metronome()
                m.timeSignature = TimeSignature(beats: 4, noteValue: 4)
                return m
            }())
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("6/8 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        VStack {
            Text("6/8 Time Signature")
                .font(.system(size: Theme.Typography.title, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.bottom, Theme.Spacing.md)

            BeatGridView(metronome: {
                let m = Metronome()
                m.timeSignature = TimeSignature(beats: 6, noteValue: 8)
                return m
            }())
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("12/8 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        VStack {
            Text("12/8 Time Signature")
                .font(.system(size: Theme.Typography.title, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.bottom, Theme.Spacing.md)

            BeatGridView(metronome: {
                let m = Metronome()
                m.timeSignature = TimeSignature(beats: 12, noteValue: 8)
                return m
            }())
        }
    }
    .preferredColorScheme(.dark)
}
