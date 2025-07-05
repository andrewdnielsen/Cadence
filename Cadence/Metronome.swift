//
//  Metronome.swift
//  Cadence
//
//  Created by Andrew Nielsen on 7/3/25.
//

import Foundation
import AudioKit
import AVFoundation

struct TimeSignature {
    var beats: Int = 4
    var noteValue: Int = 4
}

/// A class encapsulating the logic for a metronome.
///
/// This class uses AudioKit to generate a precise, looping click track based on a given tempo and time signature.
class Metronome {
    /// A boolean indicating whether the metronome is currently playing.
    var isRunning: Bool = false
    
    /// The tempo of the metronome in beats per minute (BPM).
    ///
    /// Setting this property will automatically update the sequencer's tempo.
    var bpm: Double = 120 {
        didSet {
            sequencer.setTempo(bpm)
        }
    }
    
    /// The time signature for the metronome's beat pattern.
    var timeSignature: TimeSignature = TimeSignature()
    
    let engine = AudioEngine()
    let player = AudioPlayer()
    let sequencer = AppleSequencer()
    var callbackInstrument: MIDICallbackInstrument!
    
    /// The name of the sound file to be used for the metronome click.
    private let soundResourceName = "click"
    /// The extension of the sound file.
    private let soundResourceExtension = "wav"
    
    init() {
        // Defining what happens on each beat by creating a MIDICallbackInstrument
        callbackInstrument = MIDICallbackInstrument { [weak self] status, note, velocity in
            
            // Creating a MIDIstatus object and checking if it is .noteOn, otherwise do nothing
            guard let midiStatus = MIDIStatus(byte: status), midiStatus.type == .noteOn else { return }
            
            // Playing the sound if it is a valid noteOn event
            self?.player.play()
        }
        
        // Loading in the metronome click sound
        
        if let fileURL = Bundle.main.url(forResource: soundResourceName, withExtension: soundResourceExtension) {
            do {
                try player.load(url: fileURL)
            } catch {
                print("Error loading audio file: \(error)")
            }
        } else {
            print("Could not find \(soundResourceName).\(soundResourceExtension)")
        }
        
        
        // Connect player to engine's output
        engine.output = player
        
        
        // Creating sequence of beats
        let track = sequencer.newTrack()
        
        // Setting up the track to play the callbackInstrument
        track?.setMIDIOutput(callbackInstrument.midiIn)
        
        // Adding a note to the track for each beat defined in our time signature
        
        for beat in 0..<timeSignature.beats{
            track?.add(noteNumber: MIDINoteNumber(60),
                       velocity: 127,
                       position: Duration(beats: Double(beat)),
                       duration: Duration(beats: 0.1))
        }
        
        // Setting sequencer to match time signature
        sequencer.setLength(Duration(beats: Double(timeSignature.beats)))
        sequencer.enableLooping()
        sequencer.setTempo(bpm)
    }
    
    /// Starts the metronome.
    func start() {
        // temporary, to be removed later
        do {
            try engine.start()
        } catch {
            print("Error starting engine: \(error)")
        }
        
        sequencer.play()
        self.isRunning = true
    }
    
    /// Stops the metronome.
    ///
    /// This stops and rewins the sequencer so it will start again on beat 1.
    func stop() {
        sequencer.stop()
        sequencer.rewind()
        
        self.isRunning = false
    // used until stopping the engine is built into the UI
        engine.stop() //to be removed later
    }
}


