//
//  CadenceApp.swift
//  Cadence
//
//  Created by Andrew Nielsen on 7/3/25.
//

import SwiftUI

@main
struct CadenceApp: App {
    @StateObject private var audioService = AudioService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioService)
        }
    }
}
