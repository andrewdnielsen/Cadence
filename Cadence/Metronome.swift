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

class Metronome {
    var isRunning: Bool = false
    var bpm: Double = 120
    var timeSignature: TimeSignature = TimeSignature()
    
    let engine = AudioEngine()
    let player = AudioPlayer()
    let sequencer = AppleSequencer()
    var callbackInstrument: MIDICallbackInstrument!
    
    init() {
        // Defining what happens on each beat by creating a MIDICallbackInstrument
        callbackInstrument = MIDICallbackInstrument { [weak self] status, note, velocity in
            
            // Creating a MIDIstatus object and checking if it is .noteOn, otherwise do nothing
            guard let midiStatus = MIDIStatus(byte: status), midiStatus.type == .noteOn else { return }
            
            // Playing the sound if it is a valid noteOn event
            self?.player.play()
        }
        
        // Loading in the metronome click sound
        
        if let fileURL = Bundle.main.url(forResource: "click", withExtension: "wav") {
            do {
                try player.load(url: fileURL)
            } catch {
                print("Error loading audio file: \(error)")
            }
        } else {
            print("Could not find click.wav")
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
}
