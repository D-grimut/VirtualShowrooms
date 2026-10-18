//
//  AreaCaptureFlow.swift
//  VirtualShowrooms
//
//  Detailed scanning of a surface patch (pothole, crack, damaged floor) using
//  Object Capture area mode: LiDAR-assisted photogrammetry, much finer than the ARKit mesh.
//

import SwiftUI
import RealityKit

@MainActor
final class AreaCaptureModel: ObservableObject {
    enum Phase {
        case naming
        case capturing
        case processing(Double)
        case done
        case failed(String)
    }

    @Published var phase: Phase = .naming
    @Published var session: ObjectCaptureSession?
    @Published var feedback: Set<ObjectCaptureSession.Feedback> = []

    static var isSupported: Bool {
        ObjectCaptureSession.isSupported && PhotogrammetrySession.isSupported
    }

    private var name = ""
    private var captureFolder: URL?
    private var cancelled = false
    private var tasks: [Task<Void, Never>] = []

    private var imagesFolder: URL? { captureFolder?.appendingPathComponent("Images", isDirectory: true) }
    private var checkpointFolder: URL? { captureFolder?.appendingPathComponent("Checkpoint", isDirectory: true) }

    func begin(name: String) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            phase = .failed("Couldn't access the documents folder.")
            return
        }
        self.name = name.isEmpty ? UUID().uuidString : name

        // photos are kept per capture so they can be reprocessed at full detail on a Mac later
        let folder = documents.appendingPathComponent("CAPTURES", isDirectory: true)
            .appendingPathComponent(self.name, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        captureFolder = folder

        guard let imagesFolder, let checkpointFolder else { return }
        do {
            try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: checkpointFolder, withIntermediateDirectories: true)
        } catch {
            phase = .failed("Couldn't create the capture folder.")
            return
        }

        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = checkpointFolder
        configuration.isOverCaptureEnabled = true

        let session = ObjectCaptureSession()
        self.session = session
        phase = .capturing

        tasks.append(Task { [weak self] in
            for await state in session.stateUpdates {
                self?.handle(state: state)
            }
        })
        tasks.append(Task { [weak self] in
            for await feedback in session.feedbackUpdates {
                self?.feedback = feedback
            }
        })

        session.start(imagesDirectory: imagesFolder, configuration: configuration)
    }

    func finish() {
        session?.finish()
    }

    func cancel() {
        cancelled = true
        session?.cancel()
        tearDownSession()
    }

    private func handle(state: ObjectCaptureSession.CaptureState) {
        switch state {
        case .ready:
            // area mode: skip object detection / bounding box and start capturing straight away
            session?.startCapturing()
        case .completed:
            tearDownSession()
            Task { await reconstruct() }
        case .failed(let error):
            tearDownSession()
            if !cancelled {
                phase = .failed(error.localizedDescription)
            }
        default:
            break
        }
    }

    // only one of ObjectCaptureSession / PhotogrammetrySession may run at a time on device
    private func tearDownSession() {
        tasks.forEach { $0.cancel() }
        tasks = []
        session = nil
        feedback = []
    }

    private func reconstruct() async {
        guard let imagesFolder,
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let exportFolder = documents.appendingPathComponent("OBJ_FILES", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        let outputURL = exportFolder.appendingPathComponent("\(name).usdz")
        try? FileManager.default.removeItem(at: outputURL)

        var configuration = PhotogrammetrySession.Configuration()
        // reconstruct the whole area rather than masking out a single object
        configuration.isObjectMaskingEnabled = false
        configuration.checkpointDirectory = checkpointFolder

        phase = .processing(0)
        do {
            let photogrammetry = try PhotogrammetrySession(input: imagesFolder, configuration: configuration)
            try photogrammetry.process(requests: [.modelFile(url: outputURL)])

            for try await output in photogrammetry.outputs {
                switch output {
                case .requestProgress(_, let fractionComplete):
                    phase = .processing(fractionComplete)
                case .requestComplete(_, _):
                    phase = .done
                case .requestError(_, let error):
                    phase = .failed(error.localizedDescription)
                case .processingCancelled:
                    phase = .failed("Processing was cancelled.")
                default:
                    break
                }
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

struct AreaCaptureFlow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AreaCaptureModel()
    @State private var name = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.phase {
            case .naming:
                namingCard
            case .capturing:
                if let session = model.session {
                    ObjectCaptureView(session: session)
                        .ignoresSafeArea()
                }
                captureControls
            case .processing(let fraction):
                card {
                    Text("Building detailed model…").font(.headline)
                    ProgressView(value: fraction)
                    Text("\(Int(fraction * 100))%").font(.footnote).foregroundColor(.secondary)
                }
            case .done:
                card {
                    Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundColor(.green)
                    Text("Saved to Exports").font(.headline)
                    Text("Raw photos saved for high-detail processing on a Mac.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            case .failed(let message):
                card {
                    Text("Capture failed").font(.headline)
                    Text(message).font(.footnote).multilineTextAlignment(.center)
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
        }
    }

    private var namingCard: some View {
        card {
            Text("Detailed area scan").font(.headline)
            Text("Hold the device 0.3–1 m above the surface and sweep slowly in overlapping rows, like mowing a lawn.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            TextField("my_file", text: $name)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: { model.begin(name: name) }) {
                    Text("Start").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
    }

    private var captureControls: some View {
        VStack {
            if let hint = model.feedback.compactMap(Self.message(for:)).first {
                Text(hint)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top)
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: {
                    model.cancel()
                    dismiss()
                }) {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: { model.finish() }) {
                    Text("Finish").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .padding()
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 16, content: content)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
    }

    private static func message(for feedback: ObjectCaptureSession.Feedback) -> String? {
        switch feedback {
        case .movingTooFast: return "Move slower"
        case .environmentTooDark, .environmentLowLight: return "More light needed"
        case .objectTooClose: return "Move farther away"
        case .objectTooFar: return "Move closer"
        case .outOfFieldOfView: return "Keep the area in view"
        default: return nil
        }
    }
}
