//
//  ContentView.swift
//  VirtualShowrooms
//
//  Created by Kelvin J on 5/17/23.
//

import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var scan = ScanController()
    @State private var showFiles = false

    var body: some View {
        ZStack {
            ARViewWrapper(controller: scan)
                .ignoresSafeArea()

            switch scan.phase {
            case .idle, .locatingSurface, .scanning:
                captureOverlay
            case .analyzing:
                ProgressView("Measuring…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            case .result(let result):
                ResultCard(
                    measurement: result.measurement,
                    onSave: { name in scan.save(name: name) },
                    onDiscard: { scan.discard() }
                )
            case .failed(let message):
                MessageCard(title: "Scan failed", message: message, onDismiss: { scan.discard() })
            }
        }
        .fullScreenCover(isPresented: $showFiles) {
            FilesScreen()
        }
    }

    private var captureOverlay: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                if !scan.isCapturing {
                    Button(action: { showFiles = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Exports")
                }
                Spacer()
                if case .scanning = scan.phase, let preview = scan.coveragePreview {
                    CoverageMap(image: preview, frames: scan.framesIntegrated)
                }
            }

            if !scan.isSupported {
                hint("This device has no LiDAR scanner, so scanning is unavailable.")
            }

            switch scan.phase {
            case .locatingSurface:
                hint("Finding the road surface… point at the pothole with some road around it, about 0.5 m away.")
            case .scanning:
                ScanStatusPill(trackingState: scan.trackingState,
                               movingTooFast: scan.movingTooFast,
                               distance: scan.distanceToSurface)
            default:
                EmptyView()
            }

            Spacer()

            if case .scanning = scan.phase {
                hint("Sweep slowly over the whole pothole and 30 cm of road around it. Tilt to see each wall. Fill every grey area on the map.")
            } else if case .idle = scan.phase, scan.isSupported {
                hint("Stand over the pothole and tap Start.")
            }

            Button(action: { scan.isCapturing ? scan.stop() : scan.start() }) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(scan.isCapturing ? Color.red : Color.accentColor))
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 4)
            }
            .disabled(!scan.isSupported)
            .opacity(scan.isSupported ? 1 : 0.4)
        }
        .padding()
    }

    private var buttonTitle: String {
        switch scan.phase {
        case .scanning: return "Finish"
        case .locatingSurface: return "Cancel"
        default: return "Start"
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Top-down map of what has been scanned: grey = missing, green = road, yellow→red = deeper
private struct CoverageMap: View {
    let image: UIImage
    let frames: Int

    var body: some View {
        VStack(spacing: 4) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("\(frames) frames")
                .font(.caption2.monospacedDigit())
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Live guidance while scanning: tracking/motion problems first, otherwise distance to the surface
private struct ScanStatusPill: View {
    let trackingState: ARCamera.TrackingState
    let movingTooFast: Bool
    let distance: Float?

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(color.opacity(0.85)))
    }

    private var problem: String? {
        switch trackingState {
        case .notAvailable: return "Tracking unavailable"
        case .limited(.excessiveMotion): return "Move slower"
        case .limited(.insufficientFeatures): return "More light or texture needed"
        case .limited(.initializing): return "Starting up…"
        case .limited(.relocalizing): return "Relocalizing…"
        default: return movingTooFast ? "Move slower" : nil
        }
    }

    private var message: String {
        if let problem { return problem }
        guard let distance else { return "Point at the surface" }
        let metres = String(format: "%.2f m", distance)
        if distance < 0.3 { return "\(metres) · Move back" }
        if distance <= 0.8 { return "\(metres) · Good" }
        return "\(metres) · Move closer"
    }

    private var color: Color {
        if problem != nil { return .orange }
        guard let distance else { return .gray }
        return (0.3...0.8).contains(distance) ? .green : .orange
    }
}

private struct ResultCard: View {
    let measurement: PotholeMeasurement
    let onSave: (String) -> Void
    let onDiscard: () -> Void
    @State private var name = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    Text("Pothole measured")
                        .font(.headline)

                    VStack(spacing: 2) {
                        Text(String(format: "%.2f L", measurement.volumeLitres))
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        Text("volume")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        row("Max depth", String(format: "%.0f mm", measurement.maxDepthMm))
                        row("Mean depth", String(format: "%.0f mm", measurement.meanDepthMm))
                        row("Size", String(format: "%.0f × %.0f mm", measurement.lengthMm, measurement.widthMm))
                        row("Area", String(format: "%.0f cm²", measurement.areaSquareMetres * 10_000))
                        row("Scanned directly", String(format: "%.0f%%", measurement.coveragePercent))
                        row("Road roughness", String(format: "±%.1f mm (%@)", measurement.referenceRmsMm, measurement.referenceSurface))
                    }
                    .font(.subheadline)

                    if !measurement.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(measurement.warnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    TextField("pothole name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    HStack(spacing: 12) {
                        Button(role: .destructive, action: onDiscard) {
                            Text("Discard").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: { onSave(name) }) {
                            Text("Save").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.large)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundColor(.secondary)
            Text(value).monospacedDigit()
        }
    }
}

private struct MessageCard: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(title).font(.headline)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("OK", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
