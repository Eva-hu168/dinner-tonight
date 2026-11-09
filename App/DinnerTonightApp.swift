import SwiftUI

@main
struct DinnerTonightApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if model.data.profile == nil {
                    OnboardingView()
                } else {
                    HomeView()
                }
            }
            .environment(model)
            .tint(.brand)
        }
    }
}
