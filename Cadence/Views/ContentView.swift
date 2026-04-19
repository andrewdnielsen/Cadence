//
//  ContentView.swift
//  Cadence
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var metronome: Metronome

    var body: some View {
        MetronomeView(metronome: metronome)
    }
}
