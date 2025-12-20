//
//  TransportButton.swift
//  Cadence
//
//  Created by Andrew Nielsen on 11/26/25.
//

import SwiftUI

/// A large, prominent play/stop button for controlling the metronome
struct TransportButton: View {
    @ObservedObject var metronome: Metronome

    @State private var isPressed = false

    var body: some View {
        let buttonSize: CGFloat = 90
        let iconSize: CGFloat = 36

        Button(action: {
            metronome.toggle()
        }) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary)
                    .frame(width: buttonSize, height: buttonSize)


                // Icon
                Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: metronome.isPlaying ? 0 : 3)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(Theme.Animation.spring) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(Theme.Animation.spring) {
                        isPressed = false
                    }
                }
        )
        .animation(Theme.Animation.spring, value: metronome.isPlaying)
        .accessibilityLabel(metronome.isPlaying ? "Stop" : "Play")
        .accessibilityValue(metronome.isPlaying ? "Playing" : "Stopped")
        .accessibilityHint("Double tap to toggle the metronome")
    }

}

#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        VStack(spacing: 40) {
            // Stopped state
            TransportButton(metronome: {
                let m = Metronome()
                return m
            }())

            // Playing state
            TransportButton(metronome: {
                let m = Metronome()
                m.start()
                return m
            }())
        }
    }
}
