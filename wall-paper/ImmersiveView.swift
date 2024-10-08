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
    @State private var isPlaneDetectionActive = true  // New state for toggling plane detection
    
    var body: some View {
        VStack {
            RealityView { content in
                if let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                    content.add(scene)
                    
                    Task {
                        await startSession()
                    }
                }
            }
            
            controlPanel  // Refactored control panel for better organization
        }
    }
    
    // Improved control panel with more functionality and better structure
    private var controlPanel: some View {
        VStack {
            HStack {
                Button("Place Model") {
                    placeCustomModel()
                }
                .padding()
                
                Button("Change Config") {
                    changeARConfiguration()
                }
                .padding()
            }
            
            HStack {
                Button("Capture Screenshot") {
                    captureScreenshot()
                }
                .padding()
                
                Button("Reset Session") {
                    resetARSession()
                }
                .padding()
            }
            
            HStack {
                Button(isPlaneDetectionActive ? "Pause Plane Detection" : "Resume Plane Detection") {
                    togglePlaneDetection()
                }
                .padding()
                
                Button("Remove All Entities") {
                    removeAllEntities()
                }
                .padding()
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
    
    private func placeCustomModel() {
        let customEntity = try! ModelEntity.load(named: "custom_model")
        customEntity.position = [0, 0, -1]
        rootEntity.addChild(customEntity)
        print("Custom model placed.")
    }
    
    private func changeARConfiguration() {
        let newConfiguration = ARWorldTrackingConfiguration()
        newConfiguration.planeDetection = [.horizontal]
        session.run(newConfiguration, options: [.resetTracking, .removeExistingAnchors])
        print("AR session configuration changed.")
    }
    
    private func captureScreenshot() {
        let arView = ARView(frame: UIScreen.main.bounds)
        let image = arView.snapshot()
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        print("Screenshot captured.")
    }
    
    private func resetARSession() {
        session.pause()
        rootEntity.children.removeAll()
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("AR session reset.")
    }
    
    // Updated toggle function with state management and print statements
    private func togglePlaneDetection() {
        if isPlaneDetectionActive {
            session.pause()
            isPlaneDetectionActive = false
            print("Plane detection paused.")
        } else {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            session.run(configuration)
            isPlaneDetectionActive = true
            print("Plane detection resumed.")
        }
    }
    
    // Updated to include print statements and better logic
    private func removeAllEntities() {
        rootEntity.children.removeAll()
        entityMap.removeAll()
        planeAnchors.removeAll()
        print("All entities removed from the scene.")
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
        print("Plane updated with ID: \(anchor.id)")
    }
    
    @MainActor
    private func removePlane(_ anchor: PlaneAnchor) async {
        entityMap[anchor.id]?.removeFromParent()
        entityMap.removeValue(forKey: anchor.id)
        planeAnchors.removeValue(forKey: anchor.id)
        print("Plane removed with ID: \(anchor.id)")
    }
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
