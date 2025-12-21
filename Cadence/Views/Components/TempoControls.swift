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
                // Normal BPM display - always present, hidden when editing
                Text("\(Int(metronome.tempo))")
                    .font(.system(size: Theme.Typography.displayLarge, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(height: 80)
                    .opacity(isEditingBPM ? 0 : 1)
                    .animation(.none, value: isEditingBPM)
                    .animation(.none, value: metronome.tempo)
                    .allowsHitTesting(!isEditingBPM)
                    .onTapGesture {
                        startEditing()
                    }
                    .accessibilityLabel("Beats per minute")
                    .accessibilityValue("\(Int(metronome.tempo))")
                    .accessibilityHint("Double tap to edit")
                    .accessibilityAddTraits(.isButton)

                // Inline editing TextField - always present, hidden when not editing
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
                    .opacity(isEditingBPM ? 1 : 0)
                    .animation(.none, value: isEditingBPM)
                    .allowsHitTesting(isEditingBPM)
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
            }
            .frame(height: 80)

            Text("BPM")
                .font(.system(size: Theme.Typography.body, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(2)
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
        // Batch all state updates together to minimize main thread work
        originalTempo = metronome.tempo
        bpmText = "\(Int(metronome.tempo))"

        withAnimation(.none) {
            isEditingBPM = true
            showBorder = true
        }

        // Focus field - text selection will happen automatically via the TextField's selection binding
        isBPMFocused = true

        // Defer text selection to next run loop to ensure TextField is ready
        DispatchQueue.main.async { [self] in
            textSelection = TextSelection(range: bpmText.startIndex..<bpmText.endIndex)
        }
    }

    /// Cancel editing and revert to original value
    private func cancelEditing() {
        showBorder = false
        isBPMFocused = false
        textSelection = nil
        isEditingBPM = false

        metronome.tempo = BPM(originalTempo)
        bpmText = "\(Int(originalTempo))"
    }

    /// Finish editing and validate input
    private func finishEditing() {
        showBorder = false
        isBPMFocused = false
        textSelection = nil
        isEditingBPM = false

        guard let newBPM = Double(bpmText) else {
            return
        }

        let clampedBPM = min(max(newBPM, minTempo), maxTempo)
        metronome.tempo = BPM(clampedBPM)
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
