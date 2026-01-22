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
    @Published var isSignalActive: Bool = false  // Indicates if currently receiving valid signal
    @Published var sustainedInTuneTime: Double = 0.0  // Time note has been held in tune

    // MARK: - Private Properties

    // Adaptive dB threshold for intelligent noise rejection
    private let strictMinimumDB: Float = -38.0  // Strict threshold for initial detection (relaxed slightly)
    private let relaxedMinimumDB: Float = -44.0  // Relaxed threshold once locked onto note
    private var currentMinimumDB: Float = -38.0  // Current threshold (starts strict)
    private var isLockedOnNote: Bool = false  // Track if we're locked onto a stable note

    // Smoothing parameters (highly reduced for near-instant response <50ms)
    private let frequencySmoothingFactor: Double = 0.7  // Near-instant frequency updates
    private let centsSmoothingFactor: Double = 0.75  // Near-instant cents display
    private var previousFrequency: Double = 0.0
    private var previousCents: Double = 0.0

    // Signal stability validation (balanced for speed + noise rejection)
    private var recentFrequencies: [Double] = []
    private let stabilityWindowSize = 2  // 2 readings for fast but stable response
    private let stabilityThreshold: Double = 5.0  // Real notes are stable within 5 Hz

    // Amplitude stability validation (strict for noise rejection)
    private var recentAmplitudes: [Float] = []
    private let amplitudeWindowSize = 2  // Track recent amplitudes
    private let maxAmplitudeVariance: Float = 0.3  // Reject if amplitude varies >30%

    // Minimum sustained duration (minimal for near-instant response)
    private var signalStartTime: Date?
    private let minimumDuration: TimeInterval = 0.03  // 30ms sustained signal for <50ms total latency

    // Sustained in-tune tracking
    private var lastUpdateTime: Date = Date()
    private let inTuneThreshold: Double = 3.0  // Within 3 cents is "in tune"

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
            // Audio session is configured app-wide in CadenceApp to support
            // simultaneous playback (metronome) and recording (tuner)

            if !engine.avEngine.isRunning {
                try engine.start()
            }

            tracker.start()
        } catch {
            print("Error starting tuner: \(error.localizedDescription)")
        }
    }

    /// Stops the tuner and stops listening for audio input
    func stop() {
        tracker.stop()

        // Audio session remains active for app-wide use (metronome may still be playing)
        // It will be deactivated when the app terminates

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

        // Convert amplitude to dB for professional-grade threshold
        let dB = amplitudeTodB(amplitude)

        // Check if signal is above adaptive dB threshold
        guard dB > currentMinimumDB else {
            // Signal dropped - keep previous note but mark as inactive
            isSignalActive = false
            sustainedInTuneTime = 0.0
            recentFrequencies.removeAll()
            recentAmplitudes.removeAll()
            signalStartTime = nil
            // Reset to strict threshold when signal is lost
            isLockedOnNote = false
            currentMinimumDB = strictMinimumDB
            return
        }

        // Only process musical frequencies (filters sub-bass and ultrasonic noise)
        // Practical range: E2 (82 Hz) to C7 (2093 Hz) covers most instruments
        guard frequency > 65 && frequency < 2000 else {
            isSignalActive = false
            recentAmplitudes.removeAll()
            signalStartTime = nil
            isLockedOnNote = false
            currentMinimumDB = strictMinimumDB
            return
        }

        // Track amplitude history for stability check
        recentAmplitudes.append(amplitude)
        if recentAmplitudes.count > amplitudeWindowSize {
            recentAmplitudes.removeFirst()
        }

        // Require amplitude stability (real notes don't fluctuate wildly)
        guard recentAmplitudes.count >= amplitudeWindowSize else {
            isSignalActive = false
            return
        }

        let avgAmplitude = recentAmplitudes.reduce(0, +) / Float(recentAmplitudes.count)
        let amplitudeVariances = recentAmplitudes.map { abs($0 - avgAmplitude) / max(avgAmplitude, 0.0001) }
        let maxVariance = amplitudeVariances.max() ?? 1.0

        // Reject if amplitude varies more than threshold (filters background noise)
        guard maxVariance < maxAmplitudeVariance else {
            isSignalActive = false
            // Don't reset frequency buffer - allows frequency stability to build independently
            signalStartTime = nil
            isLockedOnNote = false
            currentMinimumDB = strictMinimumDB
            return
        }

        // Add to recent frequencies for stability validation
        recentFrequencies.append(Double(frequency))
        if recentFrequencies.count > stabilityWindowSize {
            recentFrequencies.removeFirst()
        }

        // Require stable signal before updating display
        guard recentFrequencies.count >= stabilityWindowSize else {
            return
        }

        // Check if frequencies are stable (all within threshold of average)
        let avgFreq = recentFrequencies.reduce(0, +) / Double(recentFrequencies.count)
        let isStable = recentFrequencies.allSatisfy { abs($0 - avgFreq) < stabilityThreshold }

        guard isStable else {
            signalStartTime = nil
            isLockedOnNote = false
            currentMinimumDB = strictMinimumDB
            return
        }

        // Check minimum sustained duration (prevents transient noise spikes)
        if signalStartTime == nil {
            signalStartTime = Date()
        }

        let sustainedDuration = Date().timeIntervalSince(signalStartTime!)
        guard sustainedDuration >= minimumDuration else {
            // Signal is stable but not sustained long enough yet
            return
        }

        // Signal is active, stable, and sustained
        isSignalActive = true

        // Adaptive threshold: Once locked onto a note, relax threshold for softer playing
        if !isLockedOnNote {
            isLockedOnNote = true
            currentMinimumDB = relaxedMinimumDB
        }

        // Apply smoothing to reduce jitter
        let smoothedFrequency = smoothFrequency(avgFreq)

        // Update detected frequency
        detectedFrequency = smoothedFrequency

        // Convert frequency to note and cents
        let (note, cents) = frequencyToNoteAndCents(frequency: smoothedFrequency)

        // Apply smoothing to cents for smooth dot movement
        let smoothedCents = smoothCents(cents)

        detectedNote = note
        detectedCents = smoothedCents

        // Track sustained in-tune time
        updateSustainedTime(cents: smoothedCents)
    }

    /// Converts amplitude (0-1 range) to decibels
    private func amplitudeTodB(_ amplitude: Float) -> Float {
        // Prevent log of zero
        let clampedAmplitude = max(amplitude, 0.00001)
        // Convert to dB: dB = 20 * log10(amplitude)
        return 20.0 * log10(clampedAmplitude)
    }

    /// Smooths frequency changes to reduce display jitter
    private func smoothFrequency(_ newFrequency: Double) -> Double {
        if previousFrequency == 0.0 {
            previousFrequency = newFrequency
            return newFrequency
        }

        let smoothed = previousFrequency * (1.0 - frequencySmoothingFactor) + newFrequency * frequencySmoothingFactor
        previousFrequency = smoothed
        return smoothed
    }

    /// Smooths cents changes for smooth dot movement
    private func smoothCents(_ newCents: Double) -> Double {
        if previousCents == 0.0 {
            previousCents = newCents
            return newCents
        }

        let smoothed = previousCents * (1.0 - centsSmoothingFactor) + newCents * centsSmoothingFactor
        previousCents = smoothed
        return smoothed
    }

    /// Updates the sustained in-tune time tracker
    private func updateSustainedTime(cents: Double) {
        let currentTime = Date()
        let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = currentTime

        // Check if note is in tune (within threshold)
        if abs(cents) < inTuneThreshold {
            // In tune - accumulate time
            sustainedInTuneTime += deltaTime
        } else {
            // Out of tune - reset
            sustainedInTuneTime = 0.0
        }
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
