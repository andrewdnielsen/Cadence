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
/// The grid automatically adjusts tile size and spacing to fit the screen.
struct BeatGridView: View {
    @ObservedObject var metronome: Metronome
    let availableWidth: CGFloat?

    var body: some View {
        let rows = buildBeatRows(for: metronome.timeSignature)
        let sizing = calculateSizing(beatCount: metronome.timeSignature.beats, rows: rows)

        VStack(spacing: sizing.spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, beatIndices in
                HStack(spacing: sizing.spacing) {
                    ForEach(beatIndices, id: \.self) { index in
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
                        .frame(width: sizing.tileSize, height: sizing.tileSize)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Helper Methods

    /// Builds rows of beat indices based on time signature
    /// - Parameter timeSignature: The time signature to layout
    /// - Returns: Array of arrays, where each inner array contains beat indices for that row
    private func buildBeatRows(for timeSignature: TimeSignature) -> [[Int]] {
        let beatCount = timeSignature.beats
        let noteValue = timeSignature.noteValue
        let beatsPerRow: Int

        // Determine beats per row based on time signature patterns
        if beatCount > 3 && beatCount % 3 == 0 && noteValue == 8 {
            // Compound time signatures (6/8, 9/8, 12/8): group in threes
            beatsPerRow = 3
        } else if beatCount >= 12 && beatCount % 4 == 0 {
            // Large time signatures divisible by 4 (12/4, 16/4): group in fours
            beatsPerRow = 4
        } else if beatCount == 7 || beatCount == 8 {
            // 7/4 or 8/4: use 4 beats per row for better layout
            beatsPerRow = 4
        } else if beatCount <= 6 {
            // 2-6 beats: single row
            beatsPerRow = beatCount
        } else {
            // 9+ beats (not multiples of 3): split into 2 rows
            beatsPerRow = (beatCount + 1) / 2
        }

        // Build rows array
        var rows: [[Int]] = []
        for startIndex in stride(from: 0, to: beatCount, by: beatsPerRow) {
            let endIndex = min(startIndex + beatsPerRow, beatCount)
            rows.append(Array(startIndex..<endIndex))
        }

        return rows
    }

    /// Calculates tile size and spacing based on available width and beat layout
    /// - Parameters:
    ///   - beatCount: Total number of beats
    ///   - rows: Array of beat rows from buildBeatRows()
    /// - Returns: Sizing information for tiles and spacing
    private func calculateSizing(beatCount: Int, rows: [[Int]]) -> (tileSize: CGFloat, spacing: CGFloat) {
        // Default sizing
        let defaultTileSize: CGFloat = 60
        let defaultSpacing: CGFloat = 8
        let minimumTileSize: CGFloat = 40
        let minimumSpacing: CGFloat = 4

        // If no width constraint provided, use defaults
        guard let maxWidth = availableWidth else {
            return (defaultTileSize, defaultSpacing)
        }

        // Calculate the maximum beats in any single row
        let maxBeatsInRow = rows.map { $0.count }.max() ?? 1

        // Calculate required width at default size
        let horizontalPadding: CGFloat = Theme.Spacing.md * 2 // Left and right padding
        let availableForGrid = maxWidth - horizontalPadding

        // Required width = (tiles × tileSize) + (gaps × spacing)
        let defaultRequiredWidth = CGFloat(maxBeatsInRow) * defaultTileSize + CGFloat(maxBeatsInRow - 1) * defaultSpacing

        // Calculate scale factor
        let scaleFactor = min(1.0, availableForGrid / defaultRequiredWidth)

        // Apply scaling with minimums
        let scaledTileSize = max(minimumTileSize, defaultTileSize * scaleFactor)
        let scaledSpacing = max(minimumSpacing, defaultSpacing * scaleFactor)

        return (scaledTileSize, scaledSpacing)
    }
}

// MARK: - Preview

#Preview("4/4 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        GeometryReader { geometry in
            VStack {
                Text("4/4 Time Signature")
                    .font(.system(size: Theme.Typography.title, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, Theme.Spacing.md)

                BeatGridView(
                    metronome: {
                        let m = Metronome()
                        m.timeSignature = TimeSignature(beats: 4, noteValue: 4)
                        return m
                    }(),
                    availableWidth: geometry.size.width * 0.85
                )
            }
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("6/8 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        GeometryReader { geometry in
            VStack {
                Text("6/8 Time Signature")
                    .font(.system(size: Theme.Typography.title, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, Theme.Spacing.md)

                BeatGridView(
                    metronome: {
                        let m = Metronome()
                        m.timeSignature = TimeSignature(beats: 6, noteValue: 8)
                        return m
                    }(),
                    availableWidth: geometry.size.width * 0.85
                )
            }
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("12/8 Time Signature") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        GeometryReader { geometry in
            VStack {
                Text("12/8 Time Signature")
                    .font(.system(size: Theme.Typography.title, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, Theme.Spacing.md)

                BeatGridView(
                    metronome: {
                        let m = Metronome()
                        m.timeSignature = TimeSignature(beats: 12, noteValue: 8)
                        return m
                    }(),
                    availableWidth: geometry.size.width * 0.85
                )
            }
        }
    }
    .preferredColorScheme(.dark)
}
