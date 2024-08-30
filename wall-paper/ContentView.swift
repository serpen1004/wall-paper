import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ContentView: View {
    @State var session = ARKitSession()
    @State private var immersionState: ImmersionStyle = .mixed
    @State private var rootEntity = Entity()
    @State private var planeAnchors: [UUID: PlaneAnchor] = [:]
    @State private var entityMap: [UUID: Entity] = [:]
    
    var body: some View {
        VStack {
            Button("Start ARKit experience RUDRA") {
                Task {
                    print("Starting ARKit session...")
                    await activateARKitSession()
                }
            }
            .padding()
        }
    }
    
    private func activateARKitSession() async {
        print("Activating ARKit session...")
        let planeData = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
        
        if PlaneDetectionProvider.isSupported {
            do {
                try await session.run([planeData])
                
                for await update in planeData.anchorUpdates {
                    if update.anchor.classification == .window {
                        // Skip planes that are windows.
                        continue
                    }
                    switch update.event {
                    case .added, .updated:
                        await updatePlane(update.anchor)
                    case .removed:
                        await removePlane(update.anchor)
                    }
                }
                print("Plane detection started.")
            } catch {
                print("ARKit session error: \(error)")
            }
        } else {
            print("Plane detection not supported.")
        }
    }
   
    @MainActor
    private func updatePlane(_ anchor: PlaneAnchor) async {
        if planeAnchors[anchor.id] == nil {
            // Add a new entity to represent this plane.
            let entity = ModelEntity(mesh: .generateText(anchor.classification.description))
            entityMap[anchor.id] = entity
            rootEntity.addChild(entity)
        }
        
        entityMap[anchor.id]?.transform = Transform(matrix: anchor.originFromAnchorTransform)
        planeAnchors[anchor.id] = anchor
    }

    @MainActor
    private func removePlane(_ anchor: PlaneAnchor) async {
        entityMap[anchor.id]?.removeFromParent()
        entityMap.removeValue(forKey: anchor.id)
        planeAnchors.removeValue(forKey: anchor.id)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
