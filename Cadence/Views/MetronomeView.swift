//
//  MetronomeView.swift
//  Cadence
//

import SwiftUI

struct MetronomeView: View {
    @ObservedObject var metronome: Metronome

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopControlBar(
                    timeSignature: $metronome.timeSignature,
                    subdivision: $metronome.subdivision,
                    isPlaying: metronome.isPlaying
                )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.sm)
                    .shadow(
                        color: Color.black.opacity(0.18),
                        radius: Theme.Shadow.small.radius,
                        x: Theme.Shadow.small.x,
                        y: Theme.Shadow.small.y
                    )

                VisualizerPager(metronome: metronome)
                    .frame(maxHeight: .infinity)

                BottomControlBar(metronome: metronome)
            }
        }
    }
}

#Preview {
    MetronomeView(metronome: Metronome())
        .preferredColorScheme(.dark)
}
