import SwiftUI
import RiveRuntime

struct BasicMetronomeView: View {
    @ObservedObject var metronome: Metronome
    let riveViewModel: RiveViewModel

    var body: some View {
        GeometryReader { geometry in
            riveViewModel.view()
                .frame(
                    width: min(geometry.size.width * 0.95, 500),
                    height: min(geometry.size.width * 0.95, 500)
                )
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onAppear {
                    // Sync animation state with metronome when view appears
                    if metronome.isPlaying {
                        riveViewModel.play()
                    } else {
                        riveViewModel.pause()
                    }
                }
                .onDisappear {
                    // Always pause animation when view disappears
                    riveViewModel.pause()
                }
        }
    }
}

#Preview {
    BasicMetronomeView(
        metronome: Metronome(),
        riveViewModel: RiveViewModel(fileName: "test", autoPlay: false)
    )
    .preferredColorScheme(.dark)
}
