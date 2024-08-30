import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    let session = ARKitSession()
    let planeData = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
    
    @State private var rootEntity = Entity()
    @State private var planeAnchors: [UUID: PlaneAnchor] = [:]
    @State private var entityMap: [UUID: Entity] = [:]
    
    var body: some View {
        RealityView { content in
            if let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(scene)
                
                Task {
                    await startSession()
                }
            }
        }
    }
    
    private func startSession() async {
        do {
            try await session.run([planeData])
            
            for await update in planeData.anchorUpdates {
                if update.anchor.classification == .window {
                    continue
                }
                switch update.event {
                case .added, .updated:
                    await updatePlane(update.anchor)
                case .removed:
                    await removePlane(update.anchor)
                }
            }
        } catch {
            print("ARKit session error: \(error)")
        }
    }
    
    @MainActor
    private func updatePlane(_ anchor: PlaneAnchor) async {
        if planeAnchors[anchor.id] == nil {
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

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
