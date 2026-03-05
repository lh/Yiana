import SwiftUI

@main
struct YialeApp: App {
    init() {
        ICloudContainer.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
