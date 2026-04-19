//
//  Metronome.swift
//  Cadence
//
//  Created by Andrew Nielsen on 7/3/25.
//
import Foundation
import AVFoundation
import SwiftUI
import RiveRuntime

/// A structure representing a musical time signature.
struct TimeSignature {
    /// The number of beats per measure (numerator).
    var beats: Int = 4
    /// The note value that gets one beat (denominator).
    var noteValue: Int = 4
}

/// A class encapsulating the logic for a metronome.
///
/// Uses AVAudioPlayerNode via the shared AudioService for sample-accurate click scheduling.
/// Uses a single-beat completion-callback chain with `.dataConsumed` callbacks: each beat's
/// callback schedules the next beat using the current tempo, so tempo changes take effect
/// immediately without needing to restart the scheduling chain.
class Metronome: ObservableObject {

    // MARK: - Audio

    private let audioService = AudioService.shared

    // MARK: - Rive Animation

    /// The Rive view model for controlling animation
    var riveViewModel: RiveViewModel?

    /// The instance for data-binding to the metronome stick's properties.
    private var metStickInstance: RiveDataBindingViewModel.Instance?

    /// Cached reference to the Rive speed property to avoid per-frame path lookups.
    private var cachedSpeedProperty: RiveDataBindingViewModel.Instance.NumberProperty?

    private let animationBaseBPM: Double = 120

    // MARK: - Scheduling State

    /// Number of beats to pre-schedule ahead
    private let lookAheadCount = 2

    /// Monotonically increasing generation counter — each new scheduling chain
    /// gets a unique generation so stale completion handlers are always rejected.
    private var schedulingGeneration: UInt = 0

    /// The beat index within the current chain (0, 1, 2, ...)
    private var scheduledBeatIndex: Int = 0

    /// Host time of the next beat to schedule
    private var nextBeatHostTime: UInt64 = 0

    // MARK: - Published Properties

    /// A boolean indicating whether the metronome is currently playing.
    @Published var isPlaying = false

    /// The tempo of the metronome in beats per minute (BPM).
    @Published var tempo: Double = 120 {
        didSet {
            updateAnimationSpeed()
        }
    }

    /// The time signature for the metronome's beat pattern.
    @Published var timeSignature: TimeSignature = TimeSignature() {
        didSet {
            currentBeat = 0
            resetBeats()

            if isPlaying {
                cancelPendingBuffers()
                beginScheduling()
            }
        }
    }

    /// The current beat position (0-based) within the measure.
    @Published var currentBeat = 0

    /// Array tracking which beats are enabled (true) or disabled (false).
    @Published var beatsEnabled: [Bool] = []

    // MARK: - Initialization

    init() {
        resetBeats()

        // Register for interruption handling
        audioService.isMetronomePlaying = { [weak self] in
            self?.isPlaying ?? false
        }
        audioService.onInterruptionBegan = { [weak self] in
            guard let self = self, self.isPlaying else { return }
            // Pause scheduling but keep isPlaying true so UI stays in "playing" state
            self.cancelPendingBuffers()
        }
        audioService.onInterruptionResume = { [weak self] in
            guard let self = self, self.isPlaying else { return }
            self.beginScheduling()
        }
        audioService.onInterruptionStop = { [weak self] in
            self?.stop()
        }
    }

    // MARK: - Rive Animation Methods

    /// Sets the Rive view model for animation control
    func setRiveViewModel(_ viewModel: RiveViewModel) {
        self.riveViewModel = viewModel
        rebindRiveInstance()

        self.riveViewModel?.pause()
        updateAnimationSpeed()
    }

    /// Re-establishes the Rive data binding for the metStick view model instance.
    /// Must be called after any operation that invalidates bindings (e.g., reset()).
    private func rebindRiveInstance() {
        guard let riveFile = riveViewModel?.riveModel?.riveFile,
              let metStickViewModel = riveFile.viewModelNamed("metStick"),
              let instance = metStickViewModel.createDefaultInstance()
        else {
            print("Error: Failed to set up Rive ViewModel instance.")
            return
        }

        riveViewModel?.riveModel?.stateMachine?.bind(viewModelInstance: instance)
        self.metStickInstance = instance
        self.cachedSpeedProperty = instance.numberProperty(fromPath: "speed")
    }

    /// Updates the animation speed based on current tempo
    private func updateAnimationSpeed() {
        guard let cachedSpeedProperty else { return }
        cachedSpeedProperty.value = Float(tempo) / Float(animationBaseBPM)
    }

    // MARK: - Scheduling

    /// Returns a safe scheduling offset based on the device's IO buffer duration
    private func safeOffsetTicks() -> UInt64 {
        let ioBufferDuration = AVAudioSession.sharedInstance().ioBufferDuration
        let offset = max(ioBufferDuration * 2, 0.010) // At least 10ms
        return AVAudioTime.hostTime(forSeconds: offset)
    }

    /// Returns the current host time from the audio engine
    private func currentHostTime() -> UInt64 {
        if let lastRenderTime = audioService.engine.outputNode.lastRenderTime,
           lastRenderTime.isHostTimeValid {
            return lastRenderTime.hostTime
        }
        return mach_absolute_time()
    }

    /// Schedules a single beat. When `chain` is true, attaches a completion
    /// callback that schedules the next beat — only the last beat in a
    /// look-ahead batch should chain, to avoid spawning parallel scheduling loops.
    private func scheduleNextBeat(beatIndex: Int, hostTime: UInt64, generation: UInt, chain: Bool = true) {
        guard isPlaying, generation == schedulingGeneration else { return }

        let beat = beatIndex % timeSignature.beats
        let time = AVAudioTime(hostTime: hostTime)
        let sourceBuffer: AVAudioPCMBuffer

        if beatsEnabled.count > beat && beatsEnabled[beat] {
            if beat == 0 {
                sourceBuffer = audioService.downbeatBuffer
            } else {
                sourceBuffer = audioService.beatBuffer
            }
        } else {
            sourceBuffer = audioService.silentBuffer
        }

        // Schedule the UI update proactively at the exact audio play time,
        // rather than reactively from the .dataConsumed callback.
        let beatTimeSeconds = AVAudioTime.seconds(forHostTime: hostTime)
        let beatTimeNanos = UInt64(beatTimeSeconds * 1_000_000_000)
        let deadline = DispatchTime(uptimeNanoseconds: beatTimeNanos)
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            guard let self = self, self.isPlaying, generation == self.schedulingGeneration else { return }
            self.currentBeat = beat
        }

        if chain {
            audioService.clickPlayer.scheduleBuffer(sourceBuffer, at: time, completionCallbackType: .dataConsumed) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    guard self.isPlaying, generation == self.schedulingGeneration else { return }

                    // Compute next beat timing using current tempo (not captured),
                    // so slider changes take effect on the very next beat.
                    let beatDuration = 60.0 / self.tempo
                    let beatHostTicks = AVAudioTime.hostTime(forSeconds: beatDuration)
                    let nextHostTime = hostTime + beatHostTicks
                    let nextIndex = beatIndex + 1

                    self.scheduledBeatIndex = nextIndex
                    self.nextBeatHostTime = nextHostTime
                    self.scheduleNextBeat(beatIndex: nextIndex, hostTime: nextHostTime, generation: generation)
                }
            }
        } else {
            audioService.clickPlayer.scheduleBuffer(sourceBuffer, at: time)
        }
    }

    /// Starts the scheduling chain from the current host time, pre-filling the look-ahead pipeline
    private func beginScheduling() {
        let hostTime = currentHostTime()
        let startTime = hostTime + safeOffsetTicks()

        schedulingGeneration &+= 1
        let generation = schedulingGeneration

        let beatDuration = 60.0 / tempo
        let beatHostTicks = AVAudioTime.hostTime(forSeconds: beatDuration)

        // Pre-schedule multiple beats to fill the look-ahead pipeline.
        // Only the last beat chains via its completion callback to avoid
        // spawning parallel scheduling loops.
        var beatIndex = 0
        var beatTime = startTime
        for i in 0..<lookAheadCount {
            let isLast = (i == lookAheadCount - 1)
            scheduleNextBeat(beatIndex: beatIndex, hostTime: beatTime, generation: generation, chain: isLast)
            beatIndex += 1
            beatTime += beatHostTicks
        }

        scheduledBeatIndex = beatIndex
        nextBeatHostTime = beatTime
    }

    /// Cancels all pending buffers and re-arms the player
    private func cancelPendingBuffers() {
        schedulingGeneration &+= 1
        audioService.clickPlayer.stop()
        audioService.clickPlayer.play()
    }

    // MARK: - Public Methods

    /// Starts the metronome playback.
    func start() {
        isPlaying = true
        currentBeat = 0
        updateAnimationSpeed()
        riveViewModel?.play()
        beginScheduling()
    }

    /// Stops the metronome playback.
    func stop() {
        cancelPendingBuffers()
        isPlaying = false
        currentBeat = 0

        // Reset animation to rest position and re-establish data binding
        // (reset() invalidates bindings by recreating the state machine internally)
        riveViewModel?.reset()
        rebindRiveInstance()
        riveViewModel?.pause()
        updateAnimationSpeed()
    }

    /// Toggles the metronome playback state.
    func toggle() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    /// Resets all beats to enabled state based on current time signature.
    func resetBeats() {
        beatsEnabled = Array(repeating: true, count: timeSignature.beats)
    }

    /// Toggles the enabled state of a specific beat.
    func toggleBeat(at index: Int) {
        guard index >= 0 && index < beatsEnabled.count else { return }
        beatsEnabled[index].toggle()
    }

    deinit {
        stop()
        riveViewModel = nil
        metStickInstance = nil
        cachedSpeedProperty = nil
    }
}
