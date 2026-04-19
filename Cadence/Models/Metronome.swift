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

// MARK: - Subdivision

/// The rhythmic subdivision played between beats.
///
/// Each case defines a (clicksPerCycle, beatsPerCycle) ratio.
/// The click interval = beatDuration × beatsPerCycle / clicksPerCycle.
///
/// Most subdivisions have beatsPerCycle = 1 (all clicks within a single beat).
/// Quarter triplet and half triplet are cross-beat: their cycles span 2 and 4
/// beats respectively, so they do NOT click on every beat of the measure —
/// this is the musically correct 3-against-2 / 3-against-4 polyrhythm behavior.
enum Subdivision: Int, CaseIterable, Identifiable {
    case quarter          // 1 per beat
    case eighth           // 2 per beat
    case eighthTriplet    // 3 per beat
    case sixteenth        // 4 per beat
    case sixteenthTriplet // 6 per beat
    case thirtySecond     // 8 per beat
    case quarterTriplet   // 3 per 2 beats
    case halfTriplet      // 3 per 4 beats
    case quintuplet       // 5 per beat
    case sextuplet        // 6 per beat (same interval as sixteenthTriplet)
    case septuplet        // 7 per beat

    var id: Int { rawValue }

    /// Number of clicks in one cycle.
    var clicksPerCycle: Int {
        switch self {
        case .quarter:          return 1
        case .eighth:           return 2
        case .eighthTriplet:    return 3
        case .sixteenth:        return 4
        case .sixteenthTriplet: return 6
        case .thirtySecond:     return 8
        case .quarterTriplet:   return 3
        case .halfTriplet:      return 3
        case .quintuplet:       return 5
        case .sextuplet:        return 6
        case .septuplet:        return 7
        }
    }

    /// Number of beats one cycle spans. 1 for all simple subdivisions;
    /// 2 for quarter triplet; 4 for half triplet.
    var beatsPerCycle: Int {
        switch self {
        case .quarterTriplet: return 2
        case .halfTriplet:    return 4
        default:              return 1
        }
    }

    /// Short label for UI display (e.g. in the subdivision picker).
    var label: String {
        switch self {
        case .quarter:          return "1/4"
        case .eighth:           return "1/8"
        case .eighthTriplet:    return "1/8T"
        case .sixteenth:        return "1/16"
        case .sixteenthTriplet: return "1/16T"
        case .thirtySecond:     return "1/32"
        case .quarterTriplet:   return "1/4T"
        case .halfTriplet:      return "1/2T"
        case .quintuplet:       return "×5"
        case .sextuplet:        return "×6"
        case .septuplet:        return "×7"
        }
    }

    /// Full name for accessibility labels.
    var fullName: String {
        switch self {
        case .quarter:          return "Quarter note"
        case .eighth:           return "8th notes"
        case .eighthTriplet:    return "8th note triplet"
        case .sixteenth:        return "16th notes"
        case .sixteenthTriplet: return "16th note triplet"
        case .thirtySecond:     return "32nd notes"
        case .quarterTriplet:   return "Quarter triplet"
        case .halfTriplet:      return "Half note triplet"
        case .quintuplet:       return "Quintuplet"
        case .sextuplet:        return "Sextuplet"
        case .septuplet:        return "Septuplet"
        }
    }
}

// MARK: - TimeSignature

/// A musical time signature.
struct TimeSignature {
    /// The number of beats per measure (numerator). Valid range: 1–12.
    var beats: Int = 4
    /// The note value that gets one beat (denominator). Valid values: 2, 4, 8, 16.
    var noteValue: Int = 4
}

// MARK: - Metronome

/// Manages all metronome state and audio scheduling.
///
/// Scheduling model: click-based (not beat-based). Each scheduled audio buffer
/// represents one click. The click interval is derived from tempo and subdivision.
/// Beat boundaries are detected mathematically from the global click index.
///
/// Tempo changes take effect on the very next click (uses current `tempo` in
/// completion callbacks, not a captured value). Subdivision and time signature
/// changes restart the scheduling chain immediately.
class Metronome: ObservableObject {

    // MARK: - Audio

    private let audioService = AudioService.shared

    // MARK: - Rive Animation (retired — coupling code retained for future cleanup)

    var riveViewModel: RiveViewModel?
    private var metStickInstance: RiveDataBindingViewModel.Instance?
    private var cachedSpeedProperty: RiveDataBindingViewModel.Instance.NumberProperty?
    private let animationBaseBPM: Double = 120

    // MARK: - Scheduling State

    /// Number of clicks to pre-schedule at startup to prime the pipeline.
    /// Larger values provide a bigger audio buffer but more initial scheduling work.
    private let lookAheadCount = 8

    /// Monotonically increasing generation counter. Each new chain gets a unique
    /// generation so stale completion handlers are silently rejected.
    private var schedulingGeneration: UInt = 0

    /// The click index of the next click to be scheduled.
    private var scheduledClickIndex: Int = 0

    /// Host time of the next click to schedule.
    private var nextClickHostTime: UInt64 = 0

    // MARK: - Published Properties

    @Published var isPlaying = false

    /// Tempo in BPM. Valid range: 20–300. Clamped on set.
    @Published var tempo: Double = 120 {
        didSet {
            let clamped = min(max(tempo, 20), 300)
            if clamped != tempo {
                tempo = clamped  // one recursive call, which exits cleanly since value is now in range
                return
            }
            updateAnimationSpeed()
        }
    }

    @Published var timeSignature: TimeSignature = TimeSignature() {
        didSet {
            currentBeat = 0
            currentSubdivisionIndex = 0
            resetBeats()
            if isPlaying {
                cancelPendingBuffers()
                beginScheduling()
            }
        }
    }

    @Published var subdivision: Subdivision = .quarter {
        didSet {
            currentSubdivisionIndex = 0
            if isPlaying {
                cancelPendingBuffers()
                beginScheduling()
            }
        }
    }

    /// Current beat position (0-based) within the measure. Updated on beat boundaries.
    @Published var currentBeat = 0

    /// Position within the current subdivision cycle (0 = on a beat, 1+ = subdivision clicks).
    @Published var currentSubdivisionIndex = 0

    /// Which beats are enabled (true) or muted (false). Indexed by beat position.
    @Published var beatsEnabled: [Bool] = []

    // MARK: - Initialization

    init() {
        resetBeats()

        audioService.isMetronomePlaying = { [weak self] in
            self?.isPlaying ?? false
        }
        audioService.onInterruptionBegan = { [weak self] in
            guard let self = self, self.isPlaying else { return }
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

    // MARK: - Rive (retired)

    func setRiveViewModel(_ viewModel: RiveViewModel) {
        self.riveViewModel = viewModel
        rebindRiveInstance()
        self.riveViewModel?.pause()
        updateAnimationSpeed()
    }

    private func rebindRiveInstance() {
        guard let riveFile = riveViewModel?.riveModel?.riveFile,
              let metStickViewModel = riveFile.viewModelNamed("metStick"),
              let instance = metStickViewModel.createDefaultInstance()
        else { return }

        riveViewModel?.riveModel?.stateMachine?.bind(viewModelInstance: instance)
        self.metStickInstance = instance
        self.cachedSpeedProperty = instance.numberProperty(fromPath: "speed")
    }

    private func updateAnimationSpeed() {
        guard let cachedSpeedProperty else { return }
        cachedSpeedProperty.value = Float(tempo) / Float(animationBaseBPM)
    }

    // MARK: - Scheduling helpers

    /// Returns the duration (seconds) between consecutive clicks at the given tempo.
    private func clickDuration(forTempo tempo: Double) -> Double {
        let beatDuration = 60.0 / tempo
        return beatDuration * Double(subdivision.beatsPerCycle) / Double(subdivision.clicksPerCycle)
    }

    /// Returns true if the given click index falls on a beat boundary.
    private func isOnBeat(_ clickIndex: Int) -> Bool {
        (clickIndex * subdivision.beatsPerCycle) % subdivision.clicksPerCycle == 0
    }

    /// Returns the beat position within the measure for a click on a beat boundary.
    /// Call only when `isOnBeat(clickIndex)` is true.
    private func beatPosition(forClickIndex clickIndex: Int) -> Int {
        (clickIndex * subdivision.beatsPerCycle / subdivision.clicksPerCycle) % timeSignature.beats
    }

    /// Returns the buffer to use for the given click index, respecting mute state.
    private func buffer(forClickIndex clickIndex: Int) -> AVAudioPCMBuffer {
        if isOnBeat(clickIndex) {
            let beat = beatPosition(forClickIndex: clickIndex)
            guard beatsEnabled.count > beat, beatsEnabled[beat] else {
                return audioService.silentBuffer
            }
            return beat == 0 ? audioService.downbeatBuffer : audioService.beatBuffer
        } else {
            // Subdivision click — mute if its parent beat is muted.
            let parentBeat = (clickIndex * subdivision.beatsPerCycle / subdivision.clicksPerCycle) % timeSignature.beats
            guard beatsEnabled.count > parentBeat, beatsEnabled[parentBeat] else {
                return audioService.silentBuffer
            }
            return audioService.subdivisionBuffer
        }
    }

    private func safeOffsetTicks() -> UInt64 {
        let ioBufferDuration = AVAudioSession.sharedInstance().ioBufferDuration
        let offset = max(ioBufferDuration * 2, 0.010)
        return AVAudioTime.hostTime(forSeconds: offset)
    }

    private func currentHostTime() -> UInt64 {
        if let lastRenderTime = audioService.engine.outputNode.lastRenderTime,
           lastRenderTime.isHostTimeValid {
            return lastRenderTime.hostTime
        }
        return mach_absolute_time()
    }

    // MARK: - Scheduling

    /// Schedules a single click. When `chain` is true, attaches a completion callback
    /// that schedules the next click — only the last click in the look-ahead batch
    /// should chain, to avoid parallel scheduling loops.
    private func scheduleNextClick(clickIndex: Int, hostTime: UInt64, generation: UInt, chain: Bool = true) {
        guard isPlaying, generation == schedulingGeneration else { return }

        let buf = buffer(forClickIndex: clickIndex)
        let time = AVAudioTime(hostTime: hostTime)
        let onBeat = isOnBeat(clickIndex)
        let beatPos = onBeat ? beatPosition(forClickIndex: clickIndex) : -1
        let subdivPos = clickIndex % subdivision.clicksPerCycle

        // Schedule the UI update to fire at the exact audio play time.
        let nowHostTime = mach_absolute_time()
        let deltaSeconds = AVAudioTime.seconds(forHostTime: hostTime) - AVAudioTime.seconds(forHostTime: nowHostTime)
        let deadline = DispatchTime.now() + max(deltaSeconds, 0)
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            guard let self = self, self.isPlaying, generation == self.schedulingGeneration else { return }
            if onBeat { self.currentBeat = beatPos }
            self.currentSubdivisionIndex = subdivPos
        }

        if chain {
            audioService.clickPlayer.scheduleBuffer(buf, at: time, completionCallbackType: .dataConsumed) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    guard self.isPlaying, generation == self.schedulingGeneration else { return }

                    // Use current tempo (not captured) so slider changes take effect immediately.
                    let interval = self.clickDuration(forTempo: self.tempo)
                    let intervalTicks = AVAudioTime.hostTime(forSeconds: interval)
                    let nextHostTime = hostTime + intervalTicks
                    let nextIndex = clickIndex + 1

                    self.scheduledClickIndex = nextIndex
                    self.nextClickHostTime = nextHostTime
                    self.scheduleNextClick(clickIndex: nextIndex, hostTime: nextHostTime, generation: generation)
                }
            }
        } else {
            audioService.clickPlayer.scheduleBuffer(buf, at: time)
        }
    }

    /// Primes the scheduling pipeline with `lookAheadCount` clicks, then hands
    /// off to the completion-callback chain.
    private func beginScheduling() {
        let hostTime = currentHostTime()
        let startTime = hostTime + safeOffsetTicks()

        schedulingGeneration &+= 1
        let generation = schedulingGeneration

        let interval = clickDuration(forTempo: tempo)
        let intervalTicks = AVAudioTime.hostTime(forSeconds: interval)

        var clickIndex = 0
        var clickTime = startTime
        for i in 0..<lookAheadCount {
            let isLast = (i == lookAheadCount - 1)
            scheduleNextClick(clickIndex: clickIndex, hostTime: clickTime, generation: generation, chain: isLast)
            clickIndex += 1
            clickTime += intervalTicks
        }

        scheduledClickIndex = clickIndex
        nextClickHostTime = clickTime
    }

    private func cancelPendingBuffers() {
        schedulingGeneration &+= 1
        audioService.clickPlayer.stop()
        audioService.clickPlayer.play()
    }

    // MARK: - Public Methods

    func start() {
        isPlaying = true
        currentBeat = 0
        currentSubdivisionIndex = 0
        updateAnimationSpeed()
        riveViewModel?.play()
        beginScheduling()
    }

    func stop() {
        cancelPendingBuffers()
        isPlaying = false
        currentBeat = 0
        currentSubdivisionIndex = 0

        riveViewModel?.reset()
        rebindRiveInstance()
        riveViewModel?.pause()
        updateAnimationSpeed()
    }

    func toggle() {
        isPlaying ? stop() : start()
    }

    func resetBeats() {
        beatsEnabled = Array(repeating: true, count: timeSignature.beats)
    }

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
