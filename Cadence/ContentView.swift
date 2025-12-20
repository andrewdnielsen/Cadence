import SwiftUI
import AudioKit
import AudioKitUI
import RiveRuntime

struct ContentView: View {
    @StateObject var metronome = Metronome()

    @State private var riveViewModel = RiveViewModel(fileName: "test", autoPlay: false)
    @State private var currentTab = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: Theme.Spacing.xs)

                    let tabViewHeight = min(max(geometry.size.height * 0.55, 350), 520)

                    TabView(selection: $currentTab) {
                        // Basic metronome visualizer (page 0)
                        BasicMetronomeView(metronome: metronome, riveViewModel: riveViewModel)
                            .tag(0)
                            .accessibilityLabel("Basic view page")

                        // Advanced metronome view (page 1)
                        AdvancedMetronomeView(
                            metronome: metronome,
                            availableWidth: geometry.size.width * 0.85,
                            availableHeight: tabViewHeight
                        )
                        .tag(1)
                        .accessibilityLabel("Advanced view page")
                    }
                    .frame(height: tabViewHeight)
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .animation(.easeInOut(duration: 0.3), value: currentTab)

                    Spacer()
                        .frame(height: Theme.Spacing.md)

                    TempoControls(metronome: metronome)
                        .padding(.horizontal, Theme.Spacing.md)

                    Spacer()
                        .frame(height: Theme.Spacing.lg)

                    TransportButton(metronome: metronome)
                        .padding(.bottom, Theme.Spacing.md)
                }
            }
            .onAppear {
                metronome.setRiveViewModel(riveViewModel)
            }
            .onDisappear {
                metronome.stop()

                // Clear Rive view model reference to prevent memory leaks
                metronome.riveViewModel = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
