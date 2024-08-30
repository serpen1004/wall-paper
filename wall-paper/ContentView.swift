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
    @State private var isPlaneDetectionActive = true  // State for toggling plane detection
    
    // New state for lighting and user interaction
    @State private var lightIntensity: Float = 1.0
    @State private var lightColor: UIColor = .white
    @State private var isUserInteractionEnabled: Bool = true
    @State private var annotationText: String = "Sample Annotation"
    
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
            
            // New Buttons for additional functionalities
            HStack {
                Button("Save Session State") {
                    saveARSessionState()
                }
                .padding()
                
                Button("Load Session State") {
                    loadARSessionState()
                }
                .padding()
            }
            
            HStack {
                Slider(value: $lightIntensity, in: 0...2, step: 0.1) {
                    Text("Light Intensity")
                }
                .padding()
                
                ColorPicker("Light Color", selection: Binding(
                    get: { Color(lightColor) },
                    set: { lightColor = UIColor($0) }
                ))
                .padding()
                
                Button("Adjust Lighting") {
                    adjustLighting(intensity: lightIntensity, color: lightColor)
                }
                .padding()
            }
            
            HStack {
                Toggle("User Interaction", isOn: $isUserInteractionEnabled)
                    .padding()
                
                Button("Toggle Interaction") {
                    toggleUserInteraction(isEnabled: isUserInteractionEnabled)
                }
                .padding()
            }
            
            HStack {
                TextField("Annotation Text", text: $annotationText)
                    .padding()
                
                Button("Add Annotation") {
                    addAnnotation(at: [0, 0, -1], text: annotationText)
                }
                .padding()
            }
            
            HStack {
                Button("Change Model Appearance") {
                    if let firstEntityID = entityMap.keys.first {
                        let newTexture = try! TextureResource.load(named: "new_texture")
                        changeModelAppearance(entityID: firstEntityID, texture: newTexture)
                    }
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
    
    private func removeAllEntities() {
        rootEntity.children.removeAll()
        entityMap.removeAll()
        planeAnchors.removeAll()
        print("All entities removed from the scene.")
    }
    
    private func saveARSessionState() {
        // Example code to save session state
        let sessionState = session.currentFrame?.capturedImage
        // Save the state to a file or user defaults
        print("AR session state saved.")
    }
    
    private func loadARSessionState() {
        // Example code to load session state
        // Retrieve the saved state from file or user defaults
        print("AR session state loaded.")
    }
    
    private func adjustLighting(intensity: Float, color: UIColor) {
        let light = DirectionalLightComponent()
        light.intensity = intensity
        light.color = color
        rootEntity.components[DirectionalLightComponent.self] = light
        print("Lighting adjusted.")
    }
    
    private func toggleUserInteraction(isEnabled: Bool) {
        rootEntity.components[InteractionComponent.self]?.isEnabled = isEnabled
        print("User interaction \(isEnabled ? "enabled" : "disabled").")
    }
    
    private func addAnnotation(at position: SIMD3<Float>, text: String) {
        let annotationEntity = ModelEntity(mesh: .generateText(text))
        annotationEntity.position = position
        rootEntity.addChild(annotationEntity)
        print("Annotation added at position \(position).")
    }
    
    private func changeModelAppearance(entityID: UUID, texture: TextureResource) {
        guard let modelEntity = entityMap[entityID] else { return }
        modelEntity.model?.materials = [SimpleMaterial(texture: texture)]
        print("Appearance of model with ID \(entityID) changed.")
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
