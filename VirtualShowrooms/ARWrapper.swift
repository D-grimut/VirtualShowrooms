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
    // not observed: the ARView never needs updating from published state
    let controller: ScanController

    func makeUIView(context: Context) -> ARView {
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) { }
}

// Owns the ARView and the pothole scan lifecycle:
// idle -> locating the road surface -> scanning (depth fusion) -> analysing -> result -> save/discard
final class ScanController: NSObject, ObservableObject, ARSessionDelegate {
    enum Phase {
        case idle
        case locatingSurface
        case scanning
        case analyzing
        case result(PotholeResult)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var trackingState: ARCamera.TrackingState = .notAvailable
    // metres from the camera to the surface at screen centre (high-confidence LiDAR only)
    @Published private(set) var distanceToSurface: Float?
    @Published private(set) var movingTooFast = false
    @Published private(set) var framesIntegrated = 0
    @Published private(set) var coveragePreview: UIImage?

    let arView = ARView(frame: .zero)
    // raw LiDAR depth needs a LiDAR device (iPhone 12 Pro and newer Pro models, LiDAR iPads)
    let isSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)

    var isCapturing: Bool {
        switch phase {
        case .locatingSurface, .scanning: return true
        default: return false
        }
    }

    // fusion runs off the main thread; `grid` and `lastPreview` are only touched on this queue
    private let processing = DispatchQueue(label: "VirtualShowrooms.pothole-fusion", qos: .userInitiated)
    private var grid: HeightmapGrid?
    private var lastPreview: TimeInterval = 0

    // main thread only
    private var isBusy = false
    private var lastPose: (time: TimeInterval, transform: simd_float4x4)?
    private var lastDistanceSample: TimeInterval = 0
    // bumped on every reset so an in-flight frame from an earlier scan can't change the new one
    private var scanGeneration = 0
    // published to the UI only with each coverage preview, so SwiftUI doesn't re-render every frame
    private var fusedFrames = 0

    // depth and pose drift apart when moving fast, which smears the heightmap
    private static let maxSpeed: Float = 0.35          // m/s
    private static let maxAngularSpeed: Float = .pi / 4 // 45°/s

    override init() {
        super.init()
        arView.automaticallyConfigureSession = false
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
        resetScanState()
        arView.session.run(buildConfigure(), options: [.resetTracking, .removeExistingAnchors])
        phase = .locatingSurface
    }

    func stop() {
        guard case .scanning = phase else {
            // stopped before the surface was found: nothing to analyse
            discard()
            return
        }
        phase = .analyzing
        let frames = fusedFrames
        processing.async { [weak self] in
            guard let self else { return }
            let outcome: Result<PotholeResult, Error>
            if let grid = self.grid {
                outcome = Result { try PotholeAnalyzer.analyze(grid: grid, framesIntegrated: frames) }
            } else {
                outcome = .failure(PotholeAnalysisError.notEnoughData)
            }
            DispatchQueue.main.async {
                self.arView.session.pause()
                switch outcome {
                case .success(let result): self.phase = .result(result)
                case .failure(let error): self.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    func save(name: String) {
        guard case .result(let result) = phase else { return }
        phase = .analyzing
        processing.async { [weak self] in
            var failure: String?
            do {
                try PotholeExporter.save(result, name: name)
            } catch {
                failure = "Couldn't save the scan: \(error.localizedDescription)"
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if let failure {
                    self.phase = .failed(failure)
                } else {
                    self.discard()
                }
            }
        }
    }

    func discard() {
        resetScanState()
        phase = .idle
        // back to plain camera preview
        arView.session.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }

    private func resetScanState() {
        scanGeneration += 1
        fusedFrames = 0
        framesIntegrated = 0
        coveragePreview = nil
        distanceToSurface = nil
        movingTooFast = false
        lastPose = nil
        processing.async { [weak self] in
            self?.grid = nil
            self?.lastPreview = 0
        }
    }

    private func buildConfigure() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        // raw (unsmoothed) depth: our own multi-frame averaging replaces ARKit's temporal smoothing
        configuration.frameSemantics = .sceneDepth
        // no scene mesh, environment probes or plane anchors: they cost CPU/GPU and aren't used
        configuration.environmentTexturing = .none
        return configuration
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        trackingState = camera.trackingState
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isCapturing else { return }

        let tooFast = isMovingTooFast(frame)
        if movingTooFast != tooFast { movingTooFast = tooFast }

        // only fuse frames with solid tracking, steady motion, and when the previous frame is done
        guard case .normal = frame.camera.trackingState, !tooFast, !isBusy,
              let snapshot = DepthSnapshot(frame: frame) else { return }

        if frame.timestamp - lastDistanceSample > 0.2 {
            lastDistanceSample = frame.timestamp
            distanceToSurface = snapshot.centreDepth()
        }

        isBusy = true
        let currentPhase = phase
        let generation = scanGeneration
        processing.async { [weak self] in
            guard let self else { return }
            switch currentPhase {
            case .locatingSurface:
                let points = snapshot.sparsePoints(step: 3, range: 0.2...2.0)
                let surface = SurfaceLocator.locate(points: points, camera: snapshot.cameraTransform)
                if let surface { self.grid = HeightmapGrid(frame: surface) }
                DispatchQueue.main.async {
                    self.isBusy = false
                    guard generation == self.scanGeneration else { return }
                    if surface != nil, case .locatingSurface = self.phase { self.phase = .scanning }
                }

            case .scanning:
                let used = self.grid?.integrate(snapshot) ?? 0
                var preview: CGImage?
                if snapshot.timestamp - self.lastPreview > 0.4 {
                    self.lastPreview = snapshot.timestamp
                    preview = self.grid?.previewImage()
                }
                DispatchQueue.main.async {
                    self.isBusy = false
                    guard generation == self.scanGeneration, case .scanning = self.phase else { return }
                    if used > 0 { self.fusedFrames += 1 }
                    if let preview {
                        self.coveragePreview = UIImage(cgImage: preview)
                        self.framesIntegrated = self.fusedFrames
                    }
                }

            default:
                DispatchQueue.main.async { self.isBusy = false }
            }
        }
    }

    private func isMovingTooFast(_ frame: ARFrame) -> Bool {
        defer { lastPose = (frame.timestamp, frame.camera.transform) }
        guard let last = lastPose else { return false }
        let dt = Float(frame.timestamp - last.time)
        guard dt > 0 else { return false }

        let a = last.transform, b = frame.camera.transform
        let speed = simd_distance(SIMD3(a.columns.3.x, a.columns.3.y, a.columns.3.z),
                                  SIMD3(b.columns.3.x, b.columns.3.y, b.columns.3.z)) / dt
        var angle = (simd_quatf(b) * simd_quatf(a).inverse).angle
        if angle > .pi { angle = 2 * .pi - angle }
        return speed > Self.maxSpeed || angle / dt > Self.maxAngularSpeed
    }
}
