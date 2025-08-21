import SwiftUI
import AudioKit
import AudioKitUI

struct ContentView: View {
    @StateObject var metronome = Metronome()
    
    var body: some View {
        VStack {
            VStack() {
                HStack {
                    Button(action: {
                        metronome.toggle()
                    }) {
                        Text(metronome.isPlaying ? "Stop" : "Start")
                    }
                    
                }
            }

        }
        .onDisappear {
            metronome.stop()
        }
    }
}

#Preview {
    ContentView()
}
