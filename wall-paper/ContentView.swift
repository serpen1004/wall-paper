import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Photos

struct ContentView: View {
    @State var session = ARKitSession()
    @State private var immersionState: ImmersionStyle = .mixed
    @State private var rootEntity = Entity()
    @State private var planeAnchors: [UUID: PlaneAnchor] = [:]
    @State private var entityMap: [UUID: Entity] = [:]
    @State private var currentModelEntity: ModelEntity?
    @State private var isSessionRunning = false
    
    var body: some View {
        VStack {
            Button("Start ARKit experience bro") {
                Task {
                    print("Starting ARKit session...")
                    await activateARKitSession()
                    isSessionRunning = true
                }
            }
            .padding()
            .disabled(isSessionRunning)
            
            Button("Add Custom 3D Model") {
                Task {
                    await addCustomModel(named: "MyCustomModel")
                }
            }
            .padding()
            
            Button("Toggle AR Session Config") {
                Task {
                    toggleSessionConfiguration()
                }
            }
            .padding()
            .disabled(!isSessionRunning)
            
            Button("Capture Screenshot") {
                Task {
                    captureScreenshot()
                }
            }
            .padding()
            .disabled(!isSessionRunning)
            
            Button("Reset AR Session") {
                Task {
                    resetARSession()
                }
            }
            .padding()
            .disabled(!isSessionRunning)
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
    
    private func addCustomModel(named modelName: String) async {
        if let customModel = try? await Entity(named: modelName, in: realityKitContentBundle) as? ModelEntity {
            rootEntity.addChild(customModel)
            currentModelEntity = customModel
            print("Custom model \(modelName) added.")
            addGesturesToModel()
        } else {
            print("Failed to load custom model: \(modelName)")
        }
    }
    
    private func toggleSessionConfiguration() {
        if immersionState == .mixed {
            immersionState = .immersive
            print("Switched to immersive mode.")
        } else {
            immersionState = .mixed
            print("Switched to mixed mode.")
        }
        session.configuration?.immersion = immersionState
    }
    
    private func captureScreenshot() {
        guard let currentFrame = session.currentFrame else {
            print("Failed to capture screenshot: no current frame.")
            return
        }
        let ciImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            print("Screenshot captured and saved to Photos.")
        }
    }
    
    private func resetARSession() {
        session.pause()
        session = ARKitSession()
        rootEntity.children.removeAll()
        planeAnchors.removeAll()
        entityMap.removeAll()
        isSessionRunning = false
        print("AR session reset.")
    }
    
    private func addGesturesToModel() {
        guard let modelEntity = currentModelEntity else { return }
        let rotationGesture = EntityGestureRecognizer(type: .rotation, target: modelEntity)
        let translationGesture = EntityGestureRecognizer(type: .translation, target: modelEntity)
        
        modelEntity.addGestureRecognizer(rotationGesture)
        modelEntity.addGestureRecognizer(translationGesture)
        
        print("Gestures added to model.")
    }
}

import ARKit

// Add a button to change AR session configuration
var body: some View {
    VStack {
        Button("Start ARKit experience Bro") {
            Task {
                print("Starting ARKit session...")
                await activateARKitSession()
            }
        }
        .padding()
        
        Button("Place Custom 3D Model") {
            placeCustomModel()
        }
        .padding()
        
        Button("Change AR Session Configuration") {
            changeARConfiguration()
        }
        .padding()
    }
}

// Function to change AR session configuration dynamically
private func changeARConfiguration() {
    let newConfiguration = ARWorldTrackingConfiguration()
    newConfiguration.planeDetection = [.horizontal]
    session.run(newConfiguration, options: [.resetTracking, .removeExistingAnchors])
    print("AR session configuration changed.")
}


#Preview(windowStyle: .automatic) {
    ContentView()
}

