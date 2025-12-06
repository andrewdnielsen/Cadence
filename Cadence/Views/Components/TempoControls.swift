//
//  TempoControls.swift
//  Cadence
//
//  Created by Andrew Nielsen on 11/26/25.
//

import SwiftUI
import AudioKit

/// A comprehensive tempo control with BPM display and slider
struct TempoControls: View {
    @ObservedObject var metronome: Metronome

    // Tempo range
    private let minTempo: Double = 10
    private let maxTempo: Double = 400

    // Inline editing state
    @State private var isEditingBPM = false
    @State private var bpmText = ""
    @State private var originalTempo: Double = 0
    @State private var showBorder = false
    @FocusState private var isBPMFocused: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // BPM display
            bpmDisplay

            // Slider
            tempoSlider
        }
    }

    /// BPM display with inline editing
    private var bpmDisplay: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ZStack {
                if isEditingBPM {
                    // Inline editing TextField
                    TextField("", text: $bpmText)
                        .font(.system(size: Theme.Typography.displayLarge, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($isBPMFocused)
                        .frame(width: 150)
                        .padding(.vertical, 4)
                        .overlay(
                            Group {
                                if showBorder {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.Colors.primary, lineWidth: 2)
                                }
                            }
                        )
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Button("Cancel") {
                                    cancelEditing()
                                }

                                Spacer()

                                Button("Done") {
                                    finishEditing()
                                }
                                .fontWeight(.semibold)
                            }
                        }
                        .onSubmit {
                            finishEditing()
                        }
                } else {
                    // Normal BPM display
                    Text("\(Int(metronome.tempo))")
                        .font(.system(size: Theme.Typography.displayLarge, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .animation(.none, value: metronome.tempo)
                        .frame(height: 80)
                        .onTapGesture {
                            startEditing()
                        }
                }
            }
            .frame(height: 80)

            Text("BPM")
                .font(.system(size: Theme.Typography.body, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(2)
        }
        .onChange(of: isBPMFocused) { _, newValue in
            if !newValue && isEditingBPM {
                finishEditing()
            }
        }
    }

    /// Styled slider for tempo adjustment
    private var tempoSlider: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Slider(
                value: Binding(
                    get: { Double(metronome.tempo) },
                    set: { metronome.tempo = BPM($0) }
                ),
                in: minTempo...maxTempo,
                step: 1
            )
            .accentColor(Theme.Colors.primary)

            // Min/max labels
            HStack {
                Text("\(Int(minTempo))")
                    .font(.system(size: Theme.Typography.caption, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                Text("\(Int(maxTempo))")
                    .font(.system(size: Theme.Typography.caption, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
    }

    // MARK: - Editing Functions

    /// Start editing BPM
    private func startEditing() {
        originalTempo = metronome.tempo
        bpmText = "\(Int(metronome.tempo))"
        isEditingBPM = true
        showBorder = true
        isBPMFocused = true
    }

    /// Cancel editing and revert to original value
    private func cancelEditing() {
        // Remove border immediately
        showBorder = false

        // Dismiss the keyboard
        isBPMFocused = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isEditingBPM = false
            // Revert to original tempo
            metronome.tempo = BPM(originalTempo)
        }
    }

    /// Finish editing and validate input
    private func finishEditing() {
        // Remove border immediately
        showBorder = false

        // Dismiss the keyboard
        isBPMFocused = false

        // Try to parse the input
        guard let newBPM = Double(bpmText) else {
            // Invalid input, revert after keyboard dismisses
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isEditingBPM = false
            }
            return
        }

        // Validate range
        let clampedBPM = min(max(newBPM, minTempo), maxTempo)

        // Update tempo immediately so slider responds right away
        metronome.tempo = BPM(clampedBPM)

        // Exit editing mode after keyboard animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isEditingBPM = false
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        TempoControls(metronome: Metronome())
            .padding()
    }
}
