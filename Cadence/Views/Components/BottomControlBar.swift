//
//  BottomControlBar.swift
//  Cadence
//
//  BPM display (with tap tempo), tempo slider, and play/pause button.
//

import SwiftUI

struct BottomControlBar: View {
    @ObservedObject var metronome: Metronome

    // Tap tempo state
    @State private var isTapTempoMode = false
    @State private var tapTimestamps: [Date] = []
    @State private var tapTempoWorkItem: DispatchWorkItem?
    @State private var justActivatedTapTempo = false
    @State private var tapPulse = false

    private var accent: Color {
        metronome.isPlaying ? Theme.Colors.accentActive : Theme.Colors.accentResting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hairline separator from visualizer
            Rectangle()
                .fill(Theme.Colors.surface)
                .frame(height: 1)

            VStack(spacing: Theme.Spacing.md) {
                bpmDisplay
                tempoSlider
                playPauseButton
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .background(Theme.Colors.background)
    }

    // MARK: - BPM Display

    private var bpmDisplay: some View {
        VStack(spacing: 6) {
            ZStack {
                // Tap tempo pill background
                if isTapTempoMode {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Colors.accentResting.opacity(0.45))
                        .padding(.horizontal, -(Theme.Spacing.lg))
                        .padding(.vertical, -(Theme.Spacing.xs))
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(Int(metronome.tempo))")
                        .font(Theme.Typography.monoDisplay(Theme.Typography.displayHuge))
                        .foregroundColor(bpmTextColor)
                        .contentTransition(.numericText())
                        .animation(Theme.Animation.smoothSpring, value: Int(metronome.tempo))
                        .brightness(tapPulse ? 0.12 : 0)
                        .animation(.easeOut(duration: 0.08), value: tapPulse)

                    Text("BPM")
                        .font(Theme.Typography.sansRegular(Theme.Typography.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.bottom, 6)
                }
            }

            if isTapTempoMode {
                Text("Tap to set tempo")
                    .font(Theme.Typography.sansRegular(Theme.Typography.small))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Theme.Animation.smoothSpring, value: isTapTempoMode)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel("\(Int(metronome.tempo)) beats per minute")
        .accessibilityHint(isTapTempoMode ? "Tap to set tempo" : "Long press to activate tap tempo")
        .onLongPressGesture(minimumDuration: 0.4) {
            if isTapTempoMode {
                withAnimation(Theme.Animation.smoothSpring) {
                    exitTapTempoMode(commit: false)
                }
            } else {
                withAnimation(Theme.Animation.smoothSpring) {
                    activateTapTempoMode()
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    guard isTapTempoMode else { return }
                    if justActivatedTapTempo {
                        justActivatedTapTempo = false
                    } else {
                        recordTap()
                    }
                }
        )
    }

    private var bpmTextColor: Color {
        if isTapTempoMode { return Theme.Colors.accentActive }
        return metronome.isPlaying ? Theme.Colors.accentActive : Theme.Colors.textPrimary
    }

    // MARK: - Tempo Slider

    private var tempoSlider: some View {
        VStack(spacing: 4) {
            Slider(value: $metronome.tempo, in: 20...300, step: 1)
                .tint(accent)
                .accessibilityLabel("Tempo")
                .accessibilityValue("\(Int(metronome.tempo)) BPM")

            HStack {
                Text("20")
                Spacer()
                Text("300")
            }
            .font(Theme.Typography.monoLabel(Theme.Typography.small))
            .foregroundColor(Theme.Colors.textTertiary)
        }
    }

    // MARK: - Play / Pause

    private var playPauseButton: some View {
        Button {
            withAnimation(Theme.Animation.smoothSpring) {
                if isTapTempoMode { exitTapTempoMode(commit: false) }
                metronome.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: Theme.Sizes.buttonHeightLarge, height: Theme.Sizes.buttonHeightLarge)

                Image(systemName: metronome.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    // Optical centering — play triangle's visual weight skews left
                    .offset(x: metronome.isPlaying ? 0 : 2)
            }
        }
        .pressableScale()
        .accessibilityLabel(metronome.isPlaying ? "Pause" : "Play")
    }

    // MARK: - Tap Tempo Logic

    private func activateTapTempoMode() {
        isTapTempoMode = true
        tapTimestamps = []
        justActivatedTapTempo = true
        resetInactivityTimer()
    }

    private func exitTapTempoMode(commit: Bool) {
        if commit, let bpm = calculateBPM(from: tapTimestamps) {
            metronome.tempo = bpm
        }
        tapTimestamps = []
        isTapTempoMode = false
        tapTempoWorkItem?.cancel()
        tapTempoWorkItem = nil
    }

    private func recordTap() {
        tapTimestamps.append(Date())

        // Update BPM in real-time from rolling average
        if let bpm = calculateBPM(from: tapTimestamps) {
            withAnimation { metronome.tempo = bpm }
        }

        // Pulse feedback on the BPM number
        tapPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { tapPulse = false }

        resetInactivityTimer()
    }

    private func resetInactivityTimer() {
        tapTempoWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(Theme.Animation.smoothSpring) {
                exitTapTempoMode(commit: true)
            }
        }
        tapTempoWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    /// Calculates BPM from a series of tap timestamps using a rolling average of
    /// the last 8 inter-tap intervals. Returns nil if fewer than 2 taps recorded.
    private func calculateBPM(from timestamps: [Date]) -> Double? {
        guard timestamps.count >= 2 else { return nil }
        let intervals = zip(timestamps, timestamps.dropFirst()).map { $1.timeIntervalSince($0) }
        let recent = Array(intervals.suffix(8))
        let avg = recent.reduce(0, +) / Double(recent.count)
        guard avg > 0 else { return nil }
        return min(max(60.0 / avg, 20), 300)
    }
}

#Preview {
    BottomControlBar(metronome: Metronome())
        .preferredColorScheme(.dark)
        .background(Color.black)
}
