import SwiftUI
import ARKit
import RealityKit

@main
struct WallcraftUCApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}
