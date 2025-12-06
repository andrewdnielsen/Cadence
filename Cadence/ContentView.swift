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

            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: Theme.Spacing.lg)

                // Time signature control - Hidden for now, will be used in advanced view
                // TimeSignatureControl(metronome: metronome)
                //     .padding(.horizontal, Theme.Spacing.md)
                //     .transition(.scale.combined(with: .opacity))

                // Swipeable content area
                TabView {
                    // Basic view
                    riveViewModel.view()
                        .frame(width: 400, height: 400)
                }
                .frame(height: 400)
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer()
                    .frame(height: Theme.Spacing.md)

                // Tempo controls
                TempoControls(metronome: metronome)
                    .padding(.horizontal, Theme.Spacing.md)

                Spacer()
                    .frame(height: Theme.Spacing.lg)

                // Play/pause button
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
