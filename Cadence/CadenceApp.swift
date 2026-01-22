//
//  CadenceApp.swift
//  Cadence
//
//  Created by Andrew Nielsen on 7/3/25.
//

import SwiftUI
import AVFoundation

@main
struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    configureAudioSession()
                }
        }
    }

    /// Configures the audio session to support both playback (metronome) and recording (tuner)
    private func configureAudioSession() {
        #if !targetEnvironment(simulator)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session configured for simultaneous playback and recording")
        } catch {
            print("Error configuring audio session: \(error.localizedDescription)")
        }
        #endif
    }
}
