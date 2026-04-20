//
//  SubdivisionSheet.swift
//  Cadence
//
//  Half-sheet picker for all 11 subdivision types, presented as a 3-column grid.
//

import SwiftUI

struct SubdivisionSheet: View {
    @Binding var subdivision: Subdivision
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(Subdivision.allCases) { sub in
                        subdivisionCell(sub)
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Subdivision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.sansMedium(Theme.Typography.body))
                        .foregroundColor(Theme.Colors.accentActive)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.background)
    }

    private func subdivisionCell(_ sub: Subdivision) -> some View {
        let isSelected = subdivision == sub

        return Button {
            subdivision = sub
            dismiss()
        } label: {
            VStack(spacing: 5) {
                RhythmPatternView(
                    subdivision: sub,
                    color: isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary
                )
                .frame(height: 36)

                Text(sub.fullName)
                    .font(Theme.Typography.sansRegular(Theme.Typography.small))
                    .foregroundColor(
                        isSelected ? Theme.Colors.textSecondary : Theme.Colors.textTertiary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm + 4)
            .padding(.horizontal, Theme.Spacing.xs)
            .background(isSelected ? Theme.Colors.accentResting : Theme.Colors.surface)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .strokeBorder(
                        isSelected ? Theme.Colors.accentActive : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sub.fullName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SubdivisionSheet(subdivision: .constant(.eighth))
        .preferredColorScheme(.dark)
}
