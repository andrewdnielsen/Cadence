//
//  PitchDetection.swift
//  Cadence
//
//  YIN pitch detection algorithm vendored from Tuna (https://github.com/vadymmarkov/Tuna)
//  Original YIN implementation adapted from pYIN by Matthias Mauch,
//  Centre for Digital Music, Queen Mary, University of London.
//
//  License: MIT (same as Tuna)
//

import Foundation
import Accelerate
import AVFoundation

// MARK: - Pitch Result

struct PitchResult {
    let frequency: Double
    let noteName: String
    let octave: Int
    let cents: Double
}

// MARK: - YIN Pitch Detector

struct YINPitchDetector {

    private static let threshold: Float = 0.05
    private static let referenceFrequency = 440.0
    private static let noteLetters = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]

    /// Detect pitch from an AVAudioPCMBuffer
    /// - Parameters:
    ///   - buffer: The audio buffer to analyze
    ///   - sampleRate: The sample rate of the audio
    /// - Returns: A PitchResult if a valid pitch was detected, nil otherwise
    static func detectPitch(buffer: AVAudioPCMBuffer, sampleRate: Float) -> PitchResult? {
        guard let pointer = buffer.floatChannelData else { return nil }

        let count = Int(buffer.frameLength)
        let elements = Array(UnsafeBufferPointer(start: pointer.pointee, count: count))

        // YIN difference function (vDSP accelerated)
        var diffBuffer = differenceA(buffer: elements)

        // Cumulative mean normalized difference
        cumulativeDifference(yinBuffer: &diffBuffer)

        // Find the first dip below threshold
        let tau = absoluteThreshold(yinBuffer: diffBuffer, withThreshold: threshold)

        guard tau > 0 else { return nil }

        // Refine with parabolic interpolation
        let interpolatedTau = parabolicInterpolation(yinBuffer: diffBuffer, tau: tau)
        let frequency = Double(sampleRate / interpolatedTau)

        // Validate frequency range (C1 ~ 32 Hz to C8 ~ 4186 Hz)
        guard frequency > 20.0 && frequency < 4190.0 else { return nil }

        // Calculate note, octave, and cents
        let semitones = 12.0 * log2(frequency / referenceFrequency)
        let roundedSemitones = Int(round(semitones))

        // Note letter (A-based indexing)
        var letterIndex = roundedSemitones < 0
            ? noteLetters.count - abs(roundedSemitones) % noteLetters.count
            : roundedSemitones % noteLetters.count
        if letterIndex == 12 { letterIndex = 0 }

        let noteName = noteLetters[letterIndex]

        // Octave (A4 = index 0, standard octave 4)
        let octave: Int
        if roundedSemitones < 0 {
            octave = 4 - (abs(roundedSemitones) + 2) / 12
        } else {
            octave = 4 + (roundedSemitones + 9) / 12
        }

        // Cents offset from nearest note
        let nearestNoteFrequency = pow(2.0, Double(roundedSemitones) / 12.0) * referenceFrequency
        let cents = 1200.0 * log2(frequency / nearestNoteFrequency)

        return PitchResult(frequency: frequency, noteName: noteName, octave: octave, cents: cents)
    }

    // MARK: - YIN Algorithm Core

    /// Accelerated difference function using vDSP
    private static func differenceA(buffer: [Float]) -> [Float] {
        let bufferHalfCount = buffer.count / 2
        var resultBuffer = [Float](repeating: 0.0, count: bufferHalfCount)
        var tempBuffer = [Float](repeating: 0.0, count: bufferHalfCount)
        var tempBufferSq = [Float](repeating: 0.0, count: bufferHalfCount)
        let len = vDSP_Length(bufferHalfCount)
        var vSum: Float = 0.0

        buffer.withUnsafeBufferPointer { bufferPtr in
            guard let baseAddress = bufferPtr.baseAddress else { return }
            for tau in 0..<bufferHalfCount {
                let bufferTau = baseAddress.advanced(by: tau)
                vDSP_vsub(baseAddress, 1, bufferTau, 1, &tempBuffer, 1, len)
                vDSP_vsq(tempBuffer, 1, &tempBufferSq, 1, len)
                vDSP_sve(tempBufferSq, 1, &vSum, len)
                resultBuffer[tau] = vSum
            }
        }

        return resultBuffer
    }

    /// Cumulative mean normalized difference function
    private static func cumulativeDifference(yinBuffer: inout [Float]) {
        yinBuffer[0] = 1.0
        var runningSum: Float = 0.0

        for tau in 1..<yinBuffer.count {
            runningSum += yinBuffer[tau]
            if runningSum == 0 {
                yinBuffer[tau] = 1
            } else {
                yinBuffer[tau] *= Float(tau) / runningSum
            }
        }
    }

    /// Find the first dip below threshold
    private static func absoluteThreshold(yinBuffer: [Float], withThreshold threshold: Float) -> Int {
        var tau = 2
        var minTau = 0
        var minVal: Float = 1000.0

        while tau < yinBuffer.count {
            if yinBuffer[tau] < threshold {
                while (tau + 1) < yinBuffer.count && yinBuffer[tau + 1] < yinBuffer[tau] {
                    tau += 1
                }
                return tau
            } else {
                if yinBuffer[tau] < minVal {
                    minVal = yinBuffer[tau]
                    minTau = tau
                }
            }
            tau += 1
        }

        if minTau > 0 {
            return -minTau
        }

        return 0
    }

    /// Parabolic interpolation to refine tau estimate
    private static func parabolicInterpolation(yinBuffer: [Float], tau: Int) -> Float {
        guard tau != yinBuffer.count else {
            return Float(tau)
        }

        var betterTau: Float = 0.0

        if tau > 0 && tau < yinBuffer.count - 1 {
            let s0 = yinBuffer[tau - 1]
            let s1 = yinBuffer[tau]
            let s2 = yinBuffer[tau + 1]

            var adjustment = (s2 - s0) / (2.0 * (2.0 * s1 - s2 - s0))
            if abs(adjustment) > 1 {
                adjustment = 0
            }
            betterTau = Float(tau) + adjustment
        } else {
            betterTau = Float(tau)
        }

        return abs(betterTau)
    }
}
