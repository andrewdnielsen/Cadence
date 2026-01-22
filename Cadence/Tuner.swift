//
//  Tuner.swift
//  Cadence
//
//  Created by Claude Code on 2025-12-21.
//  Rewritten to use Tuna library for near-instant pitch detection
//

import Foundation
import AVFoundation
import SwiftUI
import Tuna

class Tuner: ObservableObject {

    // MARK: - Pitch Engine
    private var pitchEngine: PitchEngine!

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
    private let strictMinimumDB: Float = -38.0  // Strict threshold for initial detection
    private let relaxedMinimumDB: Float = -44.0  // Relaxed threshold once locked onto note
    private var currentMinimumDB: Float = -38.0  // Current threshold (starts strict)
    private var isLockedOnNote: Bool = false  // Track if we're locked onto a stable note

    // Smoothing parameters (optimized for near-instant response)
    private let frequencySmoothingFactor: Double = 0.7  // Fast frequency updates
    private let centsSmoothingFactor: Double = 0.75  // Fast cents display
    private var previousFrequency: Double = 0.0
    private var previousCents: Double = 0.0

    // Signal stability validation (minimal for maximum speed)
    private var recentFrequencies: [Double] = []
    private let stabilityWindowSize = 1  // Single reading for instant response
    private let stabilityThreshold: Double = 8.0  // Relaxed for speed

    // Amplitude stability validation
    private var recentAmplitudes: [Float] = []
    private let amplitudeWindowSize = 1  // Minimal tracking for speed
    private let maxAmplitudeVariance: Float = 0.4  // Relaxed for speed

    // Minimum sustained duration (optimized for speed)
    private var signalStartTime: Date?
    private let minimumDuration: TimeInterval = 0.015  // 15ms for near-instant response

    // Sustained in-tune tracking
    private var lastUpdateTime: Date = Date()
    private let inTuneThreshold: Double = 3.0  // Within 3 cents is "in tune"

    // MARK: - Initialization
    init() {
        // Initialize Tuna pitch engine with YIN algorithm (fastest and most accurate)
        pitchEngine = PitchEngine(
            bufferSize: 4096,  // Default buffer size
            estimationStrategy: .yin  // YIN algorithm for monophonic pitch detection
        ) { [weak self] result in
            guard let self = self else { return }

            // Process result on main queue (Tuna already dispatches to main)
            switch result {
            case .success(let pitch):
                self.processPitch(pitch: pitch)
            case .failure(let error):
                // Handle errors (e.g., level below threshold)
                self.handlePitchError(error)
            }
        }
    }

    // MARK: - Public Methods

    /// Starts the tuner and begins listening for audio input
    func start() {
        pitchEngine.start()
        print("Tuner started with Tuna engine")
        print("Initial level threshold: \(pitchEngine.levelThreshold)")
    }

    /// Stops the tuner and stops listening for audio input
    func stop() {
        pitchEngine.stop()

        // Reset displayed values
        detectedFrequency = 0.0
        detectedNote = "--"
        detectedCents = 0.0
        amplitude = 0.0
        isSignalActive = false
        sustainedInTuneTime = 0.0

        // Reset internal state
        resetInternalState()

        print("Tuner stopped")
    }

    /// Toggles the tuner on/off
    func toggle() {
        isListening.toggle()
    }

    // MARK: - Private Methods

    /// Handles pitch detection errors
    private func handlePitchError(_ error: Error) {
        print("Pitch error: \(error)")
        // Signal dropped or level too low - keep previous note but mark as inactive
        isSignalActive = false
        sustainedInTuneTime = 0.0
        resetInternalState()
    }

    /// Resets internal validation state
    private func resetInternalState() {
        recentFrequencies.removeAll()
        recentAmplitudes.removeAll()
        signalStartTime = nil
        isLockedOnNote = false
        currentMinimumDB = strictMinimumDB
    }

    /// Processes the detected pitch and updates published properties
    private func processPitch(pitch: Pitch) {
        let frequency = Float(pitch.frequency)
        let signalLevel = pitchEngine.signalLevel  // Already in dB format from Tuna!

        print("Pitch detected - Freq: \(frequency) Hz, Level dB: \(signalLevel)")

        // Update amplitude for display (convert from dB to 0-1 range for UI)
        self.amplitude = Double(pow(10.0, signalLevel / 20.0))

        // signalLevel is already in dB format, use directly
        let dB = signalLevel
        print("dB: \(dB), threshold: \(currentMinimumDB)")

        // Check if signal is above adaptive dB threshold
        guard dB > currentMinimumDB else {
            // Signal dropped - keep previous note but mark as inactive
            isSignalActive = false
            sustainedInTuneTime = 0.0
            resetInternalState()
            return
        }

        // Only process musical frequencies (filters sub-bass and ultrasonic noise)
        // Practical range: E2 (82 Hz) to C7 (2093 Hz) covers most instruments
        guard frequency > 65 && frequency < 2000 else {
            isSignalActive = false
            resetInternalState()
            return
        }

        // Track amplitude history for stability check
        recentAmplitudes.append(signalLevel)
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

        // Extract note name and cents from Tuna's Pitch object
        let note = pitch.note  // Note struct
        let noteString = "\(note.letter.description)\(note.octave)"  // Convert to "A4" format
        let cents = pitch.offsets.closest.cents  // Already calculated by Tuna!

        // Apply smoothing to cents for smooth dot movement
        let smoothedCents = smoothCents(cents)

        detectedNote = noteString
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

    // MARK: - Cleanup
    deinit {
        if isListening {
            stop()
        }
    }
}
