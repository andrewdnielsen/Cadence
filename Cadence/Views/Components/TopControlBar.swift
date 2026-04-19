//
//  TopControlBar.swift
//  Cadence
//
//  Floating card with meter fraction (left) and subdivision selector (right).
//
//  Takes discrete bindings rather than the full Metronome object so it does not
//  re-render on every beat tick (which would interrupt open Menu interactions).
//

import SwiftUI

struct TopControlBar: View {
    @Binding var timeSignature: TimeSignature
    @Binding var subdivision: Subdivision
    let isPlaying: Bool

    @State private var showingSubdivisionSheet = false

    var body: some View {
        HStack(spacing: 0) {
            meterFraction
            divider
            subdivisionSelector
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.CornerRadius.lg)
        .sheet(isPresented: $showingSubdivisionSheet) {
            SubdivisionSheet(subdivision: $subdivision)
        }
    }

    // MARK: - Meter Fraction

    private var meterFraction: some View {
        VStack(spacing: 0) {
            // Numerator
            Menu {
                ForEach(1...12, id: \.self) { n in
                    Button {
                        timeSignature.beats = n
                    } label: {
                        Text("\(n)")
                    }
                }
            } label: {
                Text("\(timeSignature.beats)")
                    .font(Theme.Typography.monoDisplay(28))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(minWidth: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Beats per measure: \(timeSignature.beats)")

            // Fraction bar
            Rectangle()
                .fill(Theme.Colors.textSecondary)
                .frame(width: 28, height: 1.5)
                .padding(.vertical, 4)

            // Denominator
            Menu {
                ForEach([2, 4, 8, 16], id: \.self) { d in
                    Button {
                        timeSignature.noteValue = d
                    } label: {
                        Text("\(d)")
                    }
                }
            } label: {
                Text("\(timeSignature.noteValue)")
                    .font(Theme.Typography.monoDisplay(28))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(minWidth: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Note value: \(timeSignature.noteValue)")
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.textTertiary.opacity(0.35))
            .frame(width: 1, height: 44)
            .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Subdivision Selector

    private var subdivisionSelector: some View {
        Button {
            showingSubdivisionSheet = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(subdivision.label)
                        .font(Theme.Typography.monoLabel(17))
                        .foregroundColor(
                            isPlaying
                                ? Theme.Colors.accentActive
                                : Theme.Colors.textPrimary
                        )

                    Text(subdivision.fullName)
                        .font(Theme.Typography.sansRegular(Theme.Typography.small))
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Subdivision: \(subdivision.fullName)")
        .accessibilityHint("Double tap to change subdivision")
    }
}

#Preview {
    TopControlBar(
        timeSignature: .constant(TimeSignature()),
        subdivision: .constant(.eighth),
        isPlaying: false
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
