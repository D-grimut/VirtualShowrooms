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
final class ScanController: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isScanning = false
    @Published var isFinalizing = false
    @Published var showConfirm = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    // set when tracking degraded mid-scan, which makes the mesh drift
    @Published var hadLimitedTracking = false
    // metres from the camera to the surface at screen centre (high-confidence LiDAR only)
    @Published var distanceToSurface: Float?

    let arView = ARView(frame: .zero)
    // scene reconstruction needs LiDAR (iPhone 12 Pro and newer Pro models, LiDAR iPads)
    let isSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    private var pendingAnchors: [ARMeshAnchor] = []
    private var lastDepthSample: TimeInterval = 0

    override init() {
        super.init()
        arView.automaticallyConfigureSession = false
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.session.delegate = self

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .tracking
        coaching.activatesAutomatically = true
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coaching)

        // camera preview only, so the screen isn't black before the first scan
        arView.session.run(ARWorldTrackingConfiguration())
    }

    func start() {
        guard isSupported else { return }
        clearPending()
        hadLimitedTracking = false
        arView.session.run(buildConfigure(), options: [.resetTracking, .removeExistingAnchors])
        isScanning = true
    }

    func stop() {
        isScanning = false
        isFinalizing = true
        // ARKit keeps refining the most recently seen area for a moment; let it settle before capturing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if let frame = self.arView.session.currentFrame {
                self.pendingAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
            }
            self.arView.session.pause()
            self.distanceToSurface = nil
            self.isFinalizing = false
            self.showConfirm = true
        }
    }

    func export(name: String) {
        let vm = ExportViewModel()
        if let asset = vm.convertToAsset(meshAnchors: pendingAnchors) {
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

    // Object Capture needs the camera to itself
    func suspendPreview() {
        arView.session.pause()
    }

    func resumePreview() {
        arView.session.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }

    private func finishConfirm() {
        clearPending()
        showConfirm = false
        // back to plain camera preview, dropping the scanned mesh
        resumePreview()
    }

    private func clearPending() {
        pendingAnchors = []
    }

    private func buildConfigure() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()

        // no environment probes or classification: they cost CPU/GPU and aren't exported
        configuration.environmentTexturing = .none
        configuration.sceneReconstruction = .mesh

        if type(of: configuration).supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics = .smoothedSceneDepth
        }

        return configuration
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        trackingState = camera.trackingState
        guard isScanning else { return }
        switch camera.trackingState {
        case .notAvailable,
             .limited(.excessiveMotion),
             .limited(.insufficientFeatures),
             .limited(.relocalizing):
            hadLimitedTracking = true
        default:
            break
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isScanning, frame.timestamp - lastDepthSample > 0.2 else { return }
        lastDepthSample = frame.timestamp
        distanceToSurface = centreDepth(of: frame)
    }

    private func centreDepth(of frame: ARFrame) -> Float? {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth,
              let confidenceMap = depthData.confidenceMap else { return nil }
        let depthMap = depthData.depthMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
        }

        let x = CVPixelBufferGetWidth(depthMap) / 2
        let y = CVPixelBufferGetHeight(depthMap) / 2
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap),
              let confidenceBase = CVPixelBufferGetBaseAddress(confidenceMap) else { return nil }

        let confidenceRow = confidenceBase.advanced(by: y * CVPixelBufferGetBytesPerRow(confidenceMap))
        let confidence = confidenceRow.assumingMemoryBound(to: UInt8.self)[x]
        guard confidence == UInt8(ARConfidenceLevel.high.rawValue) else { return nil }

        let depthRow = depthBase.advanced(by: y * CVPixelBufferGetBytesPerRow(depthMap))
        return depthRow.assumingMemoryBound(to: Float32.self)[x]
    }
}

class ExportViewModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var imageViewHeight: CGFloat = 0
    @Published var exportedURL: URL?

    func convertToAsset(meshAnchors: [ARMeshAnchor]) -> MDLAsset? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }

        let asset = MDLAsset()

        for anchor in meshAnchors {
            let mdlMesh = anchor.geometry.toMDLMesh(device: device, modelMatrix: anchor.transform)
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
