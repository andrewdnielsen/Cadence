//
//  VisualizerPager.swift
//  Cadence
//
//  Swipeable paged area. Placeholder views stand in for tickets #17, #18, #19.
//

import SwiftUI

struct VisualizerPager: View {
    @ObservedObject var metronome: Metronome
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            VisualizerPlaceholder(ticketNumber: 17, description: "Pendulum Visualizer")
                .tag(0)

            VisualizerPlaceholder(ticketNumber: 18, description: "Beat Grid Visualizer")
                .tag(1)

            VisualizerPlaceholder(ticketNumber: 19, description: "Circular Visualizer")
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .tint(metronome.isPlaying ? Theme.Colors.accentActive : Theme.Colors.accentResting)
    }
}

// MARK: - Placeholder

private struct VisualizerPlaceholder: View {
    let ticketNumber: Int
    let description: String

    var body: some View {
        ZStack {
            Theme.Colors.surface
                .cornerRadius(Theme.CornerRadius.md)

            VStack(spacing: Theme.Spacing.sm) {
                Text("#\(ticketNumber)")
                    .font(Theme.Typography.monoDisplay(Theme.Typography.displayMedium))
                    .foregroundColor(Theme.Colors.textTertiary)

                Text(description)
                    .font(Theme.Typography.sansRegular(Theme.Typography.caption))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        // Bottom padding keeps content clear of the page indicator dots
        .padding(.bottom, Theme.Spacing.xl)
    }
}

#Preview {
    VisualizerPager(metronome: Metronome())
        .frame(height: 400)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
