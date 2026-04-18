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
/// Beats are scheduled one at a time with a 1-beat look-ahead chain to prevent gaps
/// while allowing immediate response to tempo/time-signature changes.
class Metronome: ObservableObject {

    // MARK: - Audio

    private let audioService = AudioService.shared

    // MARK: - Rive Animation

    /// The Rive view model for controlling animation
    var riveViewModel: RiveViewModel?

    /// The instance for data-binding to the metronome stick's properties.
    private var metStickInstance: RiveDataBindingViewModel.Instance?

    private let animationBaseBPM: Double = 120

    // MARK: - Scheduling State

    /// Monotonically increasing generation counter — each new scheduling chain
    /// gets a unique generation so stale completion handlers are always rejected.
    private var schedulingGeneration: UInt = 0

    /// The beat index within the current chain (0, 1, 2, ...)
    private var scheduledBeatIndex: Int = 0

    /// Host time of the next beat to schedule
    private var nextBeatHostTime: UInt64 = 0

    // MARK: - Published Properties

    /// A boolean indicating whether the metronome is currently playing.
    @Published var isPlaying = false {
        didSet {
            if isPlaying {
                updateAnimationSpeed()
                riveViewModel?.play()
            } else {
                // Cancel all pending buffers
                audioService.downbeatPlayer.stop()
                audioService.beatPlayer.stop()
                audioService.silentPlayer.stop()
                // Re-arm players for next start
                audioService.downbeatPlayer.play()
                audioService.beatPlayer.play()
                audioService.silentPlayer.play()

                riveViewModel?.pause()
                updateAnimationSpeed()
            }
        }
    }

    /// The tempo of the metronome in beats per minute (BPM).
    @Published var tempo: Double = 120 {
        didSet {
            updateAnimationSpeed()

            if isPlaying {
                rescheduleFromCurrentPosition()
            }
        }
    }

    /// The time signature for the metronome's beat pattern.
    @Published var timeSignature: TimeSignature = TimeSignature() {
        didSet {
            resetBeats()

            if isPlaying {
                // Reset to downbeat with new time signature
                currentBeat = 0
                rescheduleFromCurrentPosition()
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
        guard let riveFile = viewModel.riveModel?.riveFile,
              let metStickViewModel = riveFile.viewModelNamed("metStick"),
              let instance = metStickViewModel.createDefaultInstance()
        else {
            print("Error: Failed to set up Rive ViewModel instance.")
            return
        }

        viewModel.riveModel?.stateMachine?.bind(viewModelInstance: instance)
        self.metStickInstance = instance

        self.riveViewModel?.pause()
        updateAnimationSpeed()
    }

    /// Updates the animation speed based on current tempo
    private func updateAnimationSpeed() {
        guard let speedProperty = metStickInstance?.numberProperty(fromPath: "speed") else {
            return
        }
        let speedMultiplier = Float(tempo) / Float(animationBaseBPM)
        speedProperty.value = speedMultiplier
    }

    // MARK: - Scheduling

    /// Schedules the next beat in the chain
    private func scheduleNextBeat(beatIndex: Int, hostTime: UInt64) {
        guard isPlaying else { return }

        let generation = self.schedulingGeneration
        let beat = beatIndex % timeSignature.beats
        let beatDuration = 60.0 / tempo
        let beatHostTicks = AVAudioTime.hostTime(forSeconds: beatDuration)

        let time = AVAudioTime(hostTime: hostTime)
        let player: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer

        if beatsEnabled.count > beat && beatsEnabled[beat] {
            if beat == 0 {
                player = audioService.downbeatPlayer
                buffer = audioService.downbeatBuffer
            } else {
                player = audioService.beatPlayer
                buffer = audioService.beatBuffer
            }
        } else {
            // Muted beat — use silent buffer to maintain sample-accurate timing
            player = audioService.silentPlayer
            buffer = audioService.silentBuffer
        }

        player.scheduleBuffer(buffer, at: time, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Reject stale completions from previous scheduling chains
                guard self.isPlaying, generation == self.schedulingGeneration else { return }
                self.currentBeat = beat
                self.scheduledBeatIndex = beatIndex + 1
                self.nextBeatHostTime = hostTime + beatHostTicks
                self.scheduleNextBeat(beatIndex: self.scheduledBeatIndex, hostTime: self.nextBeatHostTime)
            }
        }
    }

    /// Starts the scheduling chain from the current host time
    private func beginScheduling() {
        let hostTime: UInt64
        if let lastRenderTime = audioService.engine.outputNode.lastRenderTime,
           lastRenderTime.isHostTimeValid {
            hostTime = lastRenderTime.hostTime
        } else {
            hostTime = mach_absolute_time()
        }

        // Add ~5ms offset to avoid scheduling in the past
        let offsetTicks = AVAudioTime.hostTime(forSeconds: 0.005)
        let startTime = hostTime + offsetTicks

        schedulingGeneration &+= 1
        scheduledBeatIndex = 0
        nextBeatHostTime = startTime
        scheduleNextBeat(beatIndex: 0, hostTime: startTime)
    }

    /// Cancels all pending buffers and re-arms players
    private func cancelPendingBuffers() {
        schedulingGeneration &+= 1 // invalidate in-flight callbacks before firing them
        audioService.downbeatPlayer.stop()
        audioService.beatPlayer.stop()
        audioService.silentPlayer.stop()
        audioService.downbeatPlayer.play()
        audioService.beatPlayer.play()
        audioService.silentPlayer.play()
    }

    /// Reschedules from the next beat at the current tempo
    private func rescheduleFromCurrentPosition() {
        cancelPendingBuffers()

        let hostTime: UInt64
        if let lastRenderTime = audioService.engine.outputNode.lastRenderTime,
           lastRenderTime.isHostTimeValid {
            hostTime = lastRenderTime.hostTime
        } else {
            hostTime = mach_absolute_time()
        }
        let offsetTicks = AVAudioTime.hostTime(forSeconds: 0.005)

        let nextBeat = (currentBeat + 1) % timeSignature.beats
        nextBeatHostTime = hostTime + offsetTicks
        scheduledBeatIndex = nextBeat
        scheduleNextBeat(beatIndex: nextBeat, hostTime: nextBeatHostTime)
    }

    // MARK: - Public Methods

    /// Starts the metronome playback.
    func start() {
        isPlaying = true
        currentBeat = 0
        beginScheduling()
    }

    /// Stops the metronome playback.
    func stop() {
        isPlaying = false
        currentBeat = 0

        // TODO: Add Rive state machine trigger to snap metronome stick to center on stop
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
    }
}
