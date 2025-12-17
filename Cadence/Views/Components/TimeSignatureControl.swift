//
//  TimeSignatureControl.swift
//  Cadence
//
//  Created by Andrew Nielsen on 11/26/25.
//

import SwiftUI

/// A control for selecting the time signature (beats per measure and note value)
struct TimeSignatureControl: View {
    @ObservedObject var metronome: Metronome

    // Available options
    private let beatOptions = Array(2...12)
    private let noteValueOptions = [2, 4, 8, 16]

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Time signature display
            timeSignatureDisplay

            Divider()
                .frame(height: 50)
                .background(Theme.Colors.textSecondary.opacity(0.3))

            // Controls
            HStack(spacing: Theme.Spacing.md) {
                // Beats selector
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Beats")
                        .font(.system(size: Theme.Typography.caption, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .fixedSize()
                        .layoutPriority(1)

                    Picker("Beats", selection: $metronome.timeSignature.beats) {
                        ForEach(beatOptions, id: \.self) { beats in
                            Text("\(beats)").tag(beats)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(Theme.Colors.primary)
                }

                // Note value selector
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Note")
                        .font(.system(size: Theme.Typography.caption, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .fixedSize()
                        .layoutPriority(1)

                    Picker("Note Value", selection: $metronome.timeSignature.noteValue) {
                        ForEach(noteValueOptions, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(Theme.Colors.primary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle(padding: Theme.Spacing.md)
    }

    /// Compact display of the current time signature (e.g., "4/4")
    private var timeSignatureDisplay: some View {
        VStack(spacing: 3) {
            Text("\(metronome.timeSignature.beats)")
                .font(.system(size: Theme.Typography.title, weight: .bold))
                .foregroundColor(Theme.Colors.primary)

            Rectangle()
                .fill(Theme.Colors.textSecondary)
                .frame(width: 50, height: 2)
                .cornerRadius(1)

            Text("\(metronome.timeSignature.noteValue)")
                .font(.system(size: Theme.Typography.title, weight: .bold))
                .foregroundColor(Theme.Colors.primary)
        }
        .frame(width: 60)
    }
}

#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        TimeSignatureControl(metronome: Metronome())
            .padding()
    }
}
