//
//  ARWrapper.swift
//  VirtualShowrooms
//
//  Created by Kelvin J on 5/17/23.
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewWrapper: UIViewRepresentable {
    @ObservedObject var controller: ScanController

    func makeUIView(context: Context) -> ARView {
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) { }
}

// Owns the ARView and the scan lifecycle (start -> stop -> export/discard)
final class ScanController: ObservableObject {
    @Published var isScanning = false
    @Published var showConfirm = false

    let arView = ARView(frame: .zero)
    // scene reconstruction needs LiDAR (iPhone 12 Pro and newer Pro models, LiDAR iPads)
    let isSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)

    private var pendingAnchors: [ARMeshAnchor] = []
    private var pendingCamera: ARCamera?

    init() {
        arView.automaticallyConfigureSession = false
        arView.debugOptions.insert(.showSceneUnderstanding)
        // camera preview only, so the screen isn't black before the first scan
        arView.session.run(ARWorldTrackingConfiguration())
    }

    func start() {
        guard isSupported else { return }
        clearPending()
        arView.session.run(buildConfigure(), options: [.resetTracking, .removeExistingAnchors])
        isScanning = true
    }

    func stop() {
        if let frame = arView.session.currentFrame {
            pendingAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
            pendingCamera = frame.camera
        }
        arView.session.pause()
        isScanning = false
        showConfirm = true
    }

    func export(name: String) {
        let vm = ExportViewModel()
        if let camera = pendingCamera,
           let asset = vm.convertToAsset(meshAnchors: pendingAnchors, camera: camera) {
            do {
                try vm.export(asset: asset, fileName: name)
            } catch {
                print("Export error")
            }
        }
        finishConfirm()
    }

    func discard() {
        finishConfirm()
    }

    private func finishConfirm() {
        clearPending()
        showConfirm = false
        // back to plain camera preview, dropping the scanned mesh
        arView.session.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }

    private func clearPending() {
        pendingAnchors = []
        pendingCamera = nil
    }

    private func buildConfigure() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()

        configuration.environmentTexturing = .automatic
        configuration.sceneReconstruction = .meshWithClassification

        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }

        return configuration
    }
}

class ExportViewModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var imageViewHeight: CGFloat = 0
    @Published var exportedURL: URL?

    func convertToAsset(meshAnchors: [ARMeshAnchor], camera: ARCamera) -> MDLAsset? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let asset = MDLAsset()

        for anchor in meshAnchors {
            let mdlMesh = anchor.geometry.toMDLMesh(device: device, camera: camera, modelMatrix: anchor.transform)
            asset.add(mdlMesh)
        }

        return asset
    }

    // What is an mdl asset? -> An indexed container for 3D objects and associated information, such as transform hierarchies, meshes, cameras, and lights
    @discardableResult
    func export(asset: MDLAsset, fileName: String) throws -> URL {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "com.original.VirtualShowrooms", code: 153)
        }

        let folderName = "OBJ_FILES" // Replace with the desired folder name
        let folderURL = directory.appendingPathComponent(folderName)

        // Create the folder if it doesn't exist
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

//        if fileName is "", use default UUID
        let url = folderURL.appendingPathComponent("\( fileName.isEmpty ? UUID().uuidString : fileName ).obj")

        do {
            try asset.export(to: url)
            print("Object saved successfully at: ", url)

            return url
        } catch {
            print("Error saving .obj file \(error)")
        }

        return url
    }
}
