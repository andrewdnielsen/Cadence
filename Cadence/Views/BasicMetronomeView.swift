import SwiftUI
import RiveRuntime

struct BasicMetronomeView: View {
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
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    BasicMetronomeView(riveViewModel: RiveViewModel(fileName: "test", autoPlay: false))
        .preferredColorScheme(.dark)
}
