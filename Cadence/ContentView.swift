import SwiftUI
import AudioKit
import AudioKitUI
import RiveRuntime

struct ContentView: View {
    @StateObject var metronome = Metronome()

    @State private var riveViewModel = RiveViewModel(fileName: "test", autoPlay: false)

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.sm) {
                // Top spacing
                Spacer()
                    .frame(height: Theme.Spacing.sm)

                // Time signature control
                TimeSignatureControl(metronome: metronome)
                    .padding(.horizontal, Theme.Spacing.md)
                    .transition(.scale.combined(with: .opacity))

                // Rive metronome animation
                riveViewModel.view()
                    .frame(width: 350, height: 350)

                // Tempo controls
                TempoControls(metronome: metronome)
                    .padding(.horizontal, Theme.Spacing.md)

                Spacer()
                    .frame(minHeight: Theme.Spacing.sm)

                // Play/stop button at bottom
                TransportButton(metronome: metronome)
                    .padding(.bottom, Theme.Spacing.md)
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
