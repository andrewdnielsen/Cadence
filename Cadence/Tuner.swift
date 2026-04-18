//
//  Tuner.swift
//  Cadence
//
//  Created by Claude Code on 2025-12-21.
//  Rewritten to use vendored YIN algorithm via AudioService's always-on input tap.
//

import Foundation
import AVFoundation
import SwiftUI

class Tuner: ObservableObject {

    // MARK: - Audio Service

    private let audioService = AudioService.shared

    // MARK: - Published Properties
    @Published var isListening = false {
        didSet {
            if isListening {
                subscribe()
            } else {
                unsubscribe()
            }
        }
    }

    @Published var detectedFrequency: Double = 0.0
    @Published var detectedNote: String = "--"
    @Published var detectedCents: Double = 0.0
    @Published var amplitude: Double = 0.0
    @Published var isSignalActive: Bool = false
    @Published var sustainedInTuneTime: Double = 0.0

    // MARK: - Private Properties

    // Adaptive dB threshold for intelligent noise rejection
    private let strictMinimumDB: Float = -38.0
    private let relaxedMinimumDB: Float = -44.0
    private var currentMinimumDB: Float = -38.0
    private var isLockedOnNote: Bool = false

    // Smoothing parameters
    private let frequencySmoothingFactor: Double = 0.7
    private let centsSmoothingFactor: Double = 0.75
    private var previousFrequency: Double = 0.0
    private var previousCents: Double = 0.0

    // Signal stability validation
    private var recentFrequencies: [Double] = []
    private let stabilityWindowSize = 1
    private let stabilityThreshold: Double = 8.0

    // Amplitude stability validation
    private var recentAmplitudes: [Float] = []
    private let amplitudeWindowSize = 1
    private let maxAmplitudeVariance: Float = 0.4

    // Minimum sustained duration
    private var signalStartTime: Date?
    private let minimumDuration: TimeInterval = 0.015

    // Sustained in-tune tracking
    private var lastUpdateTime: Date = Date()
    private let inTuneThreshold: Double = 3.0

    // MARK: - Public Methods

    func toggle() {
        isListening.toggle()
    }

    // MARK: - Subscription

    /// Subscribes to pitch results from AudioService's always-on input tap
    private func subscribe() {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async { self.isListening = false }
        return
        #endif

        audioService.pitchCallback = { [weak self] result in
            self?.processPitch(result: result)
        }
        audioService.pitchErrorCallback = { [weak self] in
            self?.handlePitchError()
        }
    }

    /// Unsubscribes from pitch results and resets state
    private func unsubscribe() {
        audioService.pitchCallback = nil
        audioService.pitchErrorCallback = nil

        // Reset displayed values
        detectedFrequency = 0.0
        detectedNote = "--"
        detectedCents = 0.0
        amplitude = 0.0
        isSignalActive = false
        sustainedInTuneTime = 0.0

        resetInternalState()
    }

    // MARK: - Pitch Processing

    private func handlePitchError() {
        isSignalActive = false
        sustainedInTuneTime = 0.0
        resetInternalState()
    }

    private func resetInternalState() {
        recentFrequencies.removeAll()
        recentAmplitudes.removeAll()
        signalStartTime = nil
        isLockedOnNote = false
        currentMinimumDB = strictMinimumDB
    }

    private func processPitch(result: PitchResult) {
        let frequency = Float(result.frequency)
        let signalLevel = audioService.signalLevel

        // Update amplitude for display (convert from dB to 0-1 range for UI)
        self.amplitude = Double(pow(10.0, signalLevel / 20.0))

        let dB = signalLevel

        // Check if signal is above adaptive dB threshold
        guard dB > currentMinimumDB else {
            isSignalActive = false
            sustainedInTuneTime = 0.0
            resetInternalState()
            return
        }

        // Only process musical frequencies
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

        guard recentAmplitudes.count >= amplitudeWindowSize else {
            isSignalActive = false
            return
        }

        let avgAmplitude = recentAmplitudes.reduce(0, +) / Float(recentAmplitudes.count)
        let amplitudeVariances = recentAmplitudes.map { abs($0 - avgAmplitude) / max(avgAmplitude, 0.0001) }
        let maxVariance = amplitudeVariances.max() ?? 1.0

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

        guard recentFrequencies.count >= stabilityWindowSize else {
            return
        }

        let avgFreq = recentFrequencies.reduce(0, +) / Double(recentFrequencies.count)
        let isStable = recentFrequencies.allSatisfy { abs($0 - avgFreq) < stabilityThreshold }

        guard isStable else {
            signalStartTime = nil
            isLockedOnNote = false
            currentMinimumDB = strictMinimumDB
            return
        }

        // Check minimum sustained duration
        if signalStartTime == nil {
            signalStartTime = Date()
        }

        let sustainedDuration = Date().timeIntervalSince(signalStartTime!)
        guard sustainedDuration >= minimumDuration else {
            return
        }

        // Signal is active, stable, and sustained
        isSignalActive = true

        if !isLockedOnNote {
            isLockedOnNote = true
            currentMinimumDB = relaxedMinimumDB
        }

        // Apply smoothing
        let smoothedFrequency = smoothFrequency(avgFreq)
        detectedFrequency = smoothedFrequency

        let noteString = "\(result.noteName)\(result.octave)"
        let smoothedCents = smoothCents(result.cents)

        detectedNote = noteString
        detectedCents = smoothedCents

        updateSustainedTime(cents: smoothedCents)
    }

    private func smoothFrequency(_ newFrequency: Double) -> Double {
        if previousFrequency == 0.0 {
            previousFrequency = newFrequency
            return newFrequency
        }
        let smoothed = previousFrequency * (1.0 - frequencySmoothingFactor) + newFrequency * frequencySmoothingFactor
        previousFrequency = smoothed
        return smoothed
    }

    private func smoothCents(_ newCents: Double) -> Double {
        if previousCents == 0.0 {
            previousCents = newCents
            return newCents
        }
        let smoothed = previousCents * (1.0 - centsSmoothingFactor) + newCents * centsSmoothingFactor
        previousCents = smoothed
        return smoothed
    }

    private func updateSustainedTime(cents: Double) {
        let currentTime = Date()
        let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = currentTime

        if abs(cents) < inTuneThreshold {
            sustainedInTuneTime += deltaTime
        } else {
            sustainedInTuneTime = 0.0
        }
    }

    deinit {
        if isListening {
            unsubscribe()
        }
    }
}
