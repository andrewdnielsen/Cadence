import SwiftUI
import AudioKit
import AudioKitUI
import RiveRuntime

struct ContentView: View {
    @StateObject var metronome = Metronome()
    
    @State private var riveViewModel =  RiveViewModel(fileName: "test", autoPlay: false)
     
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                riveViewModel.view()
                HStack {
                    Button(action: {
                        metronome.toggle()
                    }) {
                        Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                    }
                    
                }
                Text("Tempo: \(Int(metronome.tempo)) BPM")
                    .padding()
                Slider(value: Binding(
                    get: { Double(metronome.tempo) },
                    set: { metronome.tempo = BPM($0) }
                ), in: 60...200, step: 1)
            }

        }
        .onAppear {
            metronome.setRiveViewModel(riveViewModel)
        }
        .onDisappear {
            metronome.stop()
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
