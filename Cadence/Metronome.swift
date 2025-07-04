//
//  Metronome.swift
//  Cadence
//
//  Created by Andrew Nielsen on 7/3/25.
//

import Foundation
import AudioKit

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
}
