
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



@main
struct WallcraftUCApp: App {
   @State private var session = ARKitSession()
   @State private var immersionState: ImmersionStyle = .mixed
   
   var body: some Scene {
       WindowGroup {
           ContentView()
       }
       ImmersiveSpace(id: "appSpace") {
           ImmersiveView()
               .task {
                   let configuration = ARWorldTrackingConfiguration.Configuration()
                   configuration.planeDetection = [.horizontal, .vertical]
                   
                   session.run(configuration)
                   
                   for await frame in session.updates {
                       for anchor in frame.anchors {
                           if let planeAnchor = anchor as? ARPlaneAnchor {
                               // Handle detected planes here
                               print("Plane detected: \(planeAnchor)")
                           }
                       }
                   }
               }
       }
       .immersionStyle(selection: $immersionState, in: .mixed)
   }
}


