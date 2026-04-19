//
//  AudioService.swift
//  Cadence
//
//  Single always-on AVAudioEngine shared by both metronome and tuner.
//  Initialized once at app launch; tab switching requires zero audio graph changes.
//

import Foundation
import AVFoundation
import Accelerate
import SwiftUI

class AudioService: ObservableObject {

    static let shared = AudioService()

    let engine = AVAudioEngine()

    // MARK: - Metronome Nodes

    let clickPlayer = AVAudioPlayerNode()

    // Pre-loaded PCM buffers
    private(set) var downbeatBuffer: AVAudioPCMBuffer!
    private(set) var beatBuffer: AVAudioPCMBuffer!
    private(set) var subdivisionBuffer: AVAudioPCMBuffer!
    private(set) var silentBuffer: AVAudioPCMBuffer!

    // MARK: - Tuner / Pitch Detection

    private let pitchQueue = DispatchQueue(label: "com.cadence.pitch")
    private let bufferSize: AVAudioFrameCount = 4096
    private(set) var inputTapInstalled = false

    /// Closure called on main thread with pitch results. Set by Tuner when listening.
    var pitchCallback: ((PitchResult) -> Void)?

    /// Closure called on main thread when signal drops below threshold. Set by Tuner.
    var pitchErrorCallback: (() -> Void)?

    /// Current signal level in dB (updated from input tap)
    @Published var signalLevel: Float = -160.0

    // MARK: - Interruption Handling

    /// Tracks whether metronome was playing before an audio interruption
    private(set) var wasPlayingBeforeInterruption = false

    /// Closure called to resume metronome after interruption. Set by Metronome.
    var onInterruptionResume: (() -> Void)?

    /// Closure called to stop metronome after interruption without resume. Set by Metronome.
    var onInterruptionStop: (() -> Void)?

    /// Closure called to notify metronome that interruption began (pause scheduling). Set by Metronome.
    var onInterruptionBegan: (() -> Void)?

    /// Set by Metronome so AudioService can check playing state for interruption handling
    var isMetronomePlaying: (() -> Bool)?

    // MARK: - Initialization

    private init() {
        configureSession()
        loadClickBuffers()
        configureGraph()
        startEngine()
        registerForNotifications()
    }

    // MARK: - Audio Session

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioService: Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Audio Graph

    private func configureGraph() {
        // Attach player node
        engine.attach(clickPlayer)

        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)

        // Connect player to mixer
        engine.connect(clickPlayer, to: mainMixer, format: outputFormat)

        // Install input tap for pitch detection
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let level = self.calculateSignalLevel(buffer: buffer)

            self.pitchQueue.async {
                let result = YINPitchDetector.detectPitch(buffer: buffer, sampleRate: Float(inputFormat.sampleRate))

                DispatchQueue.main.async {
                    self.signalLevel = level

                    if let result = result {
                        self.pitchCallback?(result)
                    } else {
                        self.pitchErrorCallback?()
                    }
                }
            }
        }
        inputTapInstalled = true
    }

    private func startEngine() {
        engine.prepare()
        do {
            try engine.start()

            // Pre-arm player node so first play has no latency
            clickPlayer.play()
        } catch {
            print("AudioService: Failed to start engine: \(error)")
        }
    }

    // MARK: - Buffer Loading

    private func loadClickBuffers() {
        downbeatBuffer = loadWAVBuffer(named: "high")
        beatBuffer = loadWAVBuffer(named: "low")

        // Trim click buffers to a fixed short duration at load time.
        // Professional metronome clicks are 20-80ms; trimming once here
        // eliminates all per-beat allocation in the scheduling loop.
        let maxClickDuration: Double = 0.080 // 80ms
        downbeatBuffer = trimBufferAtLoad(downbeatBuffer, maxDuration: maxClickDuration)
        beatBuffer = trimBufferAtLoad(beatBuffer, maxDuration: maxClickDuration)

        // Create subdivision buffer as an attenuated copy of the beat buffer (~40% amplitude)
        if let beat = beatBuffer {
            subdivisionBuffer = attenuateBuffer(beat, gain: 0.40)
        }

        // Create silent buffer matching click duration for muted-beat timing
        if let refBuffer = downbeatBuffer {
            let silentBuf = AVAudioPCMBuffer(
                pcmFormat: refBuffer.format,
                frameCapacity: refBuffer.frameLength
            )!
            silentBuf.frameLength = refBuffer.frameLength
            // Buffer is already zeroed by default
            silentBuffer = silentBuf
        }
    }

    /// Returns a new buffer with all samples multiplied by `gain`. Uses Accelerate for efficiency.
    private func attenuateBuffer(_ buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer? {
        guard let attenuated = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
        attenuated.frameLength = buffer.frameLength

        let channelCount = Int(buffer.format.channelCount)
        if let src = buffer.floatChannelData, let dst = attenuated.floatChannelData {
            for ch in 0..<channelCount {
                vDSP_vsmul(src[ch], 1, [gain], dst[ch], 1, vDSP_Length(buffer.frameLength))
            }
        }
        return attenuated
    }

    /// Trims a buffer to maxDuration seconds. Returns the original if already short enough.
    private func trimBufferAtLoad(_ buffer: AVAudioPCMBuffer?, maxDuration: Double) -> AVAudioPCMBuffer? {
        guard let buffer = buffer else { return nil }
        let maxFrames = AVAudioFrameCount(maxDuration * buffer.format.sampleRate)
        guard buffer.frameLength > maxFrames else { return buffer }

        guard let trimmed = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: maxFrames) else {
            return buffer
        }
        trimmed.frameLength = maxFrames

        let channelCount = Int(buffer.format.channelCount)
        if let src = buffer.floatChannelData, let dst = trimmed.floatChannelData {
            for ch in 0..<channelCount {
                memcpy(dst[ch], src[ch], Int(maxFrames) * MemoryLayout<Float>.size)
            }
        } else if let src = buffer.int16ChannelData, let dst = trimmed.int16ChannelData {
            for ch in 0..<channelCount {
                memcpy(dst[ch], src[ch], Int(maxFrames) * MemoryLayout<Int16>.size)
            }
        } else if let src = buffer.int32ChannelData, let dst = trimmed.int32ChannelData {
            for ch in 0..<channelCount {
                memcpy(dst[ch], src[ch], Int(maxFrames) * MemoryLayout<Int32>.size)
            }
        }

        return trimmed
    }

    private func loadWAVBuffer(named name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("AudioService: Could not find \(name).wav in bundle")
            return nil
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)

            // If formats match, read directly; otherwise use a converter
            if file.processingFormat == outputFormat {
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                ) else {
                    print("AudioService: Could not create buffer for \(name).wav")
                    return nil
                }
                try file.read(into: buffer)
                return buffer
            } else {
                let sourceBuffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                )!
                try file.read(into: sourceBuffer)

                guard let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat) else {
                    print("AudioService: Could not create format converter for \(name).wav")
                    return nil
                }

                // Calculate output frame count based on sample rate ratio
                let sampleRateRatio = outputFormat.sampleRate / file.processingFormat.sampleRate
                let outputFrameCount = AVAudioFrameCount(Double(file.length) * sampleRateRatio)

                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: outputFrameCount
                ) else {
                    print("AudioService: Could not create buffer for \(name).wav")
                    return nil
                }

                var conversionError: NSError?
                var inputConsumed = false
                converter.convert(to: buffer, error: &conversionError) { _, outStatus in
                    if inputConsumed {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return sourceBuffer
                }

                if let error = conversionError {
                    print("AudioService: Conversion error for \(name).wav: \(error)")
                    return nil
                }

                return buffer
            }
        } catch {
            print("AudioService: Error loading \(name).wav: \(error)")
            return nil
        }
    }

    // MARK: - Signal Level

    private func calculateSignalLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return -160.0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return -160.0 }

        var rms: Float = 0.0
        vDSP_measqv(channelData[0], 1, &rms, vDSP_Length(count))

        if rms > 0 {
            return 10.0 * log10f(rms)
        } else {
            return -160.0
        }
    }

    // MARK: - Notifications

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesWereReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleRouteChange(notification: Notification) {
        // AVAudioPlayerNode with pre-buffered PCM is route-change agnostic.
        // Only restart if the engine stopped unexpectedly.
        if !engine.isRunning {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
                clickPlayer.play()
            } catch {
                print("AudioService: Failed to restart engine after route change: \(error)")
            }
        }
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isMetronomePlaying?() ?? false
            DispatchQueue.main.async { [weak self] in
                self?.onInterruptionBegan?()
            }

        case .ended:
            let shouldResume: Bool
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            } else {
                shouldResume = false
            }

            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
                clickPlayer.play()
            } catch {
                print("AudioService: Failed to restart engine after interruption: \(error)")
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if shouldResume && self.wasPlayingBeforeInterruption {
                    self.onInterruptionResume?()
                } else if self.wasPlayingBeforeInterruption {
                    self.onInterruptionStop?()
                }
                self.wasPlayingBeforeInterruption = false
            }

        @unknown default:
            break
        }
    }

    @objc private func handleMediaServicesWereReset(notification: Notification) {
        // Media server was killed by the OS — entire audio graph is destroyed.
        // Must rebuild everything from scratch.
        inputTapInstalled = false
        configureSession()
        loadClickBuffers()
        configureGraph()
        startEngine()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isMetronomePlaying?() == true {
                self.onInterruptionResume?()
            }
        }
    }

    @objc private func handleWillEnterForeground(notification: Notification) {
        // Fallback for cases where interruption .ended was never delivered
        if !engine.isRunning {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
                clickPlayer.play()
            } catch {
                print("AudioService: Failed to restart engine on foreground entry: \(error)")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
