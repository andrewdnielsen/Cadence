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
    private let maxBPMDigits = 3

    // Inline editing state
    @State private var isEditingBPM = false
    @State private var bpmText = ""
    @State private var originalTempo: Double = 0
    @State private var showBorder = false
    @FocusState private var isBPMFocused: Bool
    @State private var textSelection: TextSelection?
    @State private var isCancelling = false

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
                    TextField("", text: $bpmText, selection: $textSelection)
                        .font(.system(size: Theme.Typography.displayLarge, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($isBPMFocused)
                        .frame(minWidth: 120, maxWidth: 180)
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
                        .onChange(of: bpmText) { oldValue, newValue in
                            if newValue.count > maxBPMDigits {
                                bpmText = oldValue
                            }
                        }
                        .accessibilityLabel("BPM")
                        .accessibilityHint("Enter value between \(Int(minTempo)) and \(Int(maxTempo))")
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
                        .accessibilityLabel("Beats per minute")
                        .accessibilityValue("\(Int(metronome.tempo))")
                        .accessibilityHint("Double tap to edit")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .frame(height: 80)

            Text("BPM")
                .font(.system(size: Theme.Typography.body, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(2)
        }
        .onChange(of: isBPMFocused) { _, newValue in
            if !newValue && isEditingBPM && !isCancelling {
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
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(Int(metronome.tempo)) BPM")
            .accessibilityHint("Adjust from \(Int(minTempo)) to \(Int(maxTempo)) BPM")

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

        // Auto-select all text after the field appears
        DispatchQueue.main.async {
            textSelection = TextSelection(range: bpmText.startIndex..<bpmText.endIndex)
        }
    }

    /// Cancel editing and revert to original value
    private func cancelEditing() {
        // Set cancelling flag to prevent onChange from calling finishEditing
        isCancelling = true

        // Remove border immediately
        showBorder = false

        // Dismiss the keyboard
        isBPMFocused = false

        // Clear text selection
        textSelection = nil

        // Revert to original tempo immediately
        metronome.tempo = BPM(originalTempo)
        bpmText = "\(Int(originalTempo))"

        // Exit editing mode after keyboard animation completes (smooth transition)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isEditingBPM = false
            isCancelling = false
        }
    }

    /// Finish editing and validate input
    private func finishEditing() {
        // Remove border immediately
        showBorder = false

        // Dismiss the keyboard
        isBPMFocused = false

        // Clear text selection
        textSelection = nil

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
