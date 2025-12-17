//
//  Metronome.swift
//  Cadence
//
//  Created by Andrew Nielsen on 7/3/25.
//
import Foundation
import AudioKit
import AudioKitEX
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
/// This class uses AudioKit to generate a precise, looping click track based on a given tempo and time signature.
/// It supports different sounds for downbeats and regular beats, and can use either built-in sounds or
/// a custom file if present in the app bundle.
class Metronome: ObservableObject, HasAudioEngine {
    
    // MARK: - Audio Engine Components
    
    /// The main audio engine for processing audio.
    let engine = AudioEngine()
    
    /// The sampler instrument for generating metronome sounds.
    let sampler = AppleSampler()
    
    /// Callback instrument for tracking beat position.
    var callbackInst = CallbackInstrument()
    
    /// The sequencer that handles timing and playback.
    var sequencer = Sequencer()
    
    /// The Rive view model for controlling animation
    var riveViewModel: RiveViewModel?
    
    /// The instance for data-binding to the metronome stick's properties.
    private var metStickInstance: RiveDataBindingViewModel.Instance?
    
    private let animationBaseBPM: Double = 120
    
    // MARK: - Published Properties
    
    /// A boolean indicating whether the metronome is currently playing.
    @Published var isPlaying = false {
            didSet {
                if isPlaying {
                    updateAnimationSpeed()
                    sequencer.play()
                    riveViewModel?.play()
                } else {
                    sequencer.stop()
                    riveViewModel?.pause()
                    updateAnimationSpeed()
                }
            }
        }
    
    /// The tempo of the metronome in beats per minute (BPM).
    ///
    /// Setting this property will automatically update the sequencer's tempo.
    @Published var tempo: BPM = 120 {
        didSet {
            sequencer.tempo = tempo
            updateAnimationSpeed()
        }
    }
    
    /// The time signature for the metronome's beat pattern.
    ///
    /// Changing this will automatically update the sequence to match the new time signature.
    @Published var timeSignature: TimeSignature = TimeSignature() {
        didSet {
            updateSequences()
        }
    }
    
    /// The current beat position (0-based) within the measure.
    @Published var currentBeat = 0
    
    // MARK: - Private Properties
    
    /// The MIDI note number for the downbeat sound.
    private let downbeatNoteNumber = MIDINoteNumber(60)

    /// The MIDI note number for regular beats.
    private let beatNoteNumber = MIDINoteNumber(60)
    
    /// The velocity for beat notes.
    private let beatNoteVelocity = 100.0
    
    /// The name of the custom sound file to look for.
    private let soundResourceName = "click"
    
    /// The extension of the custom sound file.
    private let soundResourceExtension = "sf2"
    
    // MARK: - Initialization
    
    /// Initializes a new metronome instance.
    ///
    /// Sets up the audio engine, sequencer tracks, and loads appropriate sound files.
    /// The metronome will use a custom sound file if present in the bundle,
    /// otherwise it falls back to built-in sounds.
    init() {
        // Add track for metronome sounds
        sequencer.addTrack(for: sampler)
        
        // Add callback track for beat tracking
        callbackInst = CallbackInstrument(midiCallback: { _, beat, _ in
            DispatchQueue.main.async { [unowned self] in
                self.currentBeat = Int(beat)
            }
        })
        
        sequencer.addTrack(for: callbackInst)
        
        engine.output = sampler
        
        setupSampler()
        updateSequences()
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
        print("Rive instance set up and bound successfully.")

        // Use pause() here to ensure the animation starts in a paused state.
        self.riveViewModel?.pause()
        updateAnimationSpeed()
    }
    /// Updates the animation speed based on current tempo
    private func updateAnimationSpeed() {
            guard let speedProperty = metStickInstance?.numberProperty(fromPath: "speed") else {
                return
            }
            
            // Check if the metronome should be playing
            if isPlaying {
                // If playing, calculate speed based on tempo
                let speedMultiplier = Float(tempo) / Float(animationBaseBPM)
                speedProperty.value = speedMultiplier
            } else {
                // If not playing, the speed must be 0
                speedProperty.value = 0
            }
            
            // print("Animation speed set to: \(speedProperty.value)")
        }
    
    
    
    // MARK: - Private Methods
    
    /// Sets up the sampler with appropriate click sounds.
    ///
    /// Attempts to load a custom file from the bundle first,
    /// then falls back to built-in sounds if the custom file is not found.
    private func setupSampler() {
        loadClickSounds()
    }
    
    /// Loads click sounds for the metronome.
    ///
    /// This method first checks for a custom file in the app bundle.
    /// If found, it attempts to load it. If not found or loading fails,
    /// it falls back to built-in General MIDI sounds.
    private func loadClickSounds() {
        // First try to load custom click.wav file
        if let customURL = Bundle.main.url(forResource: soundResourceName, withExtension: soundResourceExtension) {
            do {
                try sampler.loadInstrument(url: customURL)
                print("Loaded custom click sound: \(soundResourceName).\(soundResourceExtension)")
                return
            } catch {
                print("Error loading custom click sound: \(error)")
            }
        }
        
        // Fall back to built-in sounds
        loadDefaultClickSounds()
    }
    
    /// Loads default built-in click sounds.
    ///
    /// Uses AudioKit's built-in General MIDI soundfont for metronome sounds.
    private func loadDefaultClickSounds() {
        do {
            // Load built-in General MIDI soundfont
            if let soundfontURL = Bundle.main.url(forResource: "GeneralUser GS MuseScore v1.442", withExtension: "sf2") {
                try sampler.loadInstrument(url: soundfontURL)
                print("Loaded built-in metronome sounds")
            } else {
                print("Warning: Could not find built-in soundfont")
            }
        } catch {
            print("Error loading built-in metronome sounds: \(error)")
        }
    }
    
    /// Updates the sequencer tracks to match the current time signature.
    ///
    /// This method recreates the MIDI sequences for both the audio track and the
    /// callback track based on the current time signature settings.
    private func updateSequences() {
        // Update audio track
        var track = sequencer.tracks.first!
        track.length = Double(timeSignature.beats)
        track.clear()
        
        // Downbeat
        track.sequence.add(noteNumber: downbeatNoteNumber,
                          velocity: MIDIVelocity(Int(beatNoteVelocity)),
                          position: 0.0,
                          duration: 0.1)
        
        // Other beats
        for beat in 1..<timeSignature.beats {
            track.sequence.add(noteNumber: beatNoteNumber,
                              velocity: MIDIVelocity(Int(beatNoteVelocity)),
                              position: Double(beat),
                              duration: 0.1)
        }
        
        // Update callback track for beat indication
        track = sequencer.tracks[1]
        track.length = Double(timeSignature.beats)
        track.clear()
        
        for beat in 0..<timeSignature.beats {
            track.sequence.add(noteNumber: MIDINoteNumber(beat),
                              position: Double(beat),
                              duration: 0.1)
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts the metronome playback.
    ///
    /// This method starts the audio engine and begins sequence playback.
    func start() {
        do {
            // Only start engine if it's not already running
            if !engine.avEngine.isRunning {
                try engine.start()
            }
            isPlaying = true
        } catch {
            print("Error starting metronome: \(error)")
        }
    }
    
    /// Stops the metronome playback.
    ///
    /// This method stops the sequencer and rewinds it to the beginning.
    /// The audio engine is also stopped to conserve resources.
    func stop() {
        isPlaying = false
    }
    
    /// Toggles the metronome playback state.
    ///
    /// If the metronome is playing, it will be stopped.
    /// If it's stopped, it will be started.
    func toggle() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }
}
