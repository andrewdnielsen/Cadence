//
//  Tuner.swift
//  Cadence
//
//  Created by Claude Code on 2025-12-21.
//

import Foundation
import AVFoundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import SwiftUI

class Tuner: ObservableObject, HasAudioEngine {

    // MARK: - Audio Engine Components
    let engine = AudioEngine()

    private let mic: AudioEngine.InputNode
    private let tappableNode: Fader
    private let silence: Fader
    private var tracker: PitchTap!

    // MARK: - Published Properties
    @Published var isListening = false {
        didSet {
            if isListening {
                start()
            } else {
                stop()
            }
        }
    }

    @Published var detectedFrequency: Double = 0.0
    @Published var detectedNote: String = "--"
    @Published var detectedCents: Double = 0.0
    @Published var amplitude: Double = 0.0

    // MARK: - Private Properties
    private let minimumAmplitude: Float = 0.1
    private let smoothingFactor: Double = 0.3
    private var previousFrequency: Double = 0.0

    // Note names for conversion
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - Initialization
    init() {
        // Get microphone input
        guard let input = engine.input else {
            fatalError("Audio input not available")
        }

        mic = input

        // Create fader chain to prevent feedback
        tappableNode = Fader(mic)
        silence = Fader(tappableNode, gain: 0)
        engine.output = silence

        // Set up pitch tracking
        tracker = PitchTap(mic) { [weak self] pitch, amplitude in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.processPitch(frequency: pitch[0], amplitude: amplitude[0])
            }
        }
    }

    // MARK: - Public Methods

    /// Starts the tuner and begins listening for audio input
    func start() {
        do {
            // Request microphone permission
            #if !targetEnvironment(simulator)
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            if !engine.avEngine.isRunning {
                try engine.start()
            }

            tracker.start()

            print("Tuner started successfully")
        } catch {
            print("Error starting tuner: \(error.localizedDescription)")
        }
    }

    /// Stops the tuner and stops listening for audio input
    func stop() {
        tracker.stop()

        #if !targetEnvironment(simulator)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
        #endif

        // Reset displayed values
        DispatchQueue.main.async { [weak self] in
            self?.detectedFrequency = 0.0
            self?.detectedNote = "--"
            self?.detectedCents = 0.0
            self?.amplitude = 0.0
        }

        print("Tuner stopped")
    }

    /// Toggles the tuner on/off
    func toggle() {
        isListening.toggle()
    }

    // MARK: - Private Methods

    /// Processes the detected pitch and updates published properties
    private func processPitch(frequency: Float, amplitude: Float) {
        // Update amplitude
        self.amplitude = Double(amplitude)

        // Only process if amplitude is above threshold (filter out noise/silence)
        guard amplitude > minimumAmplitude else {
            // If signal is too weak, reset to default state
            if detectedNote != "--" {
                detectedFrequency = 0.0
                detectedNote = "--"
                detectedCents = 0.0
            }
            return
        }

        // Only process valid frequencies (~20Hz - 20kHz)
        // Musical range is typically 27.5 Hz (A0) to 4186 Hz (C8)
        guard frequency > 20 && frequency < 5000 else {
            return
        }

        // Apply smoothing to reduce jitter
        let smoothedFrequency = smoothFrequency(Double(frequency))

        // Update detected frequency
        detectedFrequency = smoothedFrequency

        // Convert frequency to note and cents
        let (note, cents) = frequencyToNoteAndCents(frequency: smoothedFrequency)

        detectedNote = note
        detectedCents = cents
    }

    /// Smooths frequency changes to reduce display jitter
    private func smoothFrequency(_ newFrequency: Double) -> Double {
        if previousFrequency == 0.0 {
            previousFrequency = newFrequency
            return newFrequency
        }

        let smoothed = previousFrequency * (1.0 - smoothingFactor) + newFrequency * smoothingFactor
        previousFrequency = smoothed
        return smoothed
    }

    /// Converts a frequency in Hz to the nearest note name and cents offset
    /// - Parameter frequency: The frequency in Hz
    /// - Returns: A tuple containing the note name (e.g., "A4") and cents offset (-50 to +50)
    private func frequencyToNoteAndCents(frequency: Double) -> (note: String, cents: Double) {
        // A4 = 440 Hz is the reference note (note number 69 in MIDI)
        let a4Frequency = 440.0
        let a4NoteNumber = 69.0

        // Formula: n = 12 * log2(f / 440)
        let halfStepsFromA4 = 12.0 * log2(frequency / a4Frequency)

        let midiNoteNumber = a4NoteNumber + halfStepsFromA4

        let nearestNoteNumber = round(midiNoteNumber)

        let nearestNoteFrequency = a4Frequency * pow(2.0, (nearestNoteNumber - a4NoteNumber) / 12.0)

        // Formula: cents = 1200 * log2(f / f_target)
        let cents = 1200.0 * log2(frequency / nearestNoteFrequency)

        // Get note name and octave
        let noteIndex = Int(nearestNoteNumber) % 12
        let octave = Int(nearestNoteNumber) / 12 - 1
        let noteName = noteNames[noteIndex]

        return ("\(noteName)\(octave)", cents)
    }

    // MARK: - Cleanup
    deinit {
        if isListening {
            stop()
        }
        tracker = nil
    }
}
