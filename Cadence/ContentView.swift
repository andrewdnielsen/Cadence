import SwiftUI
import RiveRuntime

struct ContentView: View {
    @StateObject var metronome = Metronome()
    @StateObject var tuner = Tuner()

    @State private var riveViewModel = RiveViewModel(fileName: "test", autoPlay: false)

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView {
            MetronomeTab(metronome: metronome, riveViewModel: riveViewModel)
                .tabItem {
                    Label("Metronome", systemImage: "metronome")
                }

            TunerTab(tuner: tuner)
                .tabItem {
                    Label("Tuner", systemImage: "tuningfork")
                }
        }
        .onAppear {
            metronome.setRiveViewModel(riveViewModel)
        }
        .onDisappear {
            metronome.stop()
            tuner.isListening = false
            metronome.riveViewModel = nil
        }
    }
}

// MARK: - Tab Bar Appearance

private func configureTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(Theme.Colors.background)

    let normalAttrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor(Theme.Colors.textSecondary)
    ]
    let selectedAttrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor(Theme.Colors.primary)
    ]

    appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Theme.Colors.textSecondary)
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
    appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Theme.Colors.primary)
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
}

// MARK: - Metronome Tab

private struct MetronomeTab: View {
    @ObservedObject var metronome: Metronome
    let riveViewModel: RiveViewModel

    @State private var currentPage = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: Theme.Spacing.xs)

                    let tabViewHeight = min(max(geometry.size.height * 0.55, 350), 520)

                    TabView(selection: $currentPage) {
                        BasicMetronomeView(metronome: metronome, riveViewModel: riveViewModel)
                            .tag(0)
                            .accessibilityLabel("Basic view page")

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
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

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
            .ignoresSafeArea(.keyboard)
        }
    }
}

// MARK: - Tuner Tab

private struct TunerTab: View {
    @ObservedObject var tuner: Tuner

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            BasicTunerView(tuner: tuner)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
