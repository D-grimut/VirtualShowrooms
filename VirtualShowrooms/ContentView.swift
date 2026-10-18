//
//  ContentView.swift
//  VirtualShowrooms
//
//  Created by Kelvin J on 5/17/23.
//

import SwiftUI
import ARKit

enum ScanMode: String, CaseIterable, Identifiable {
    case quick = "Quick"
    case detailed = "Detailed"
    var id: Self { self }
}

struct ContentView: View {
    @StateObject private var scan = ScanController()
    @State private var showFiles = false
    @State private var mode: ScanMode = .quick
    @State private var showAreaCapture = false

    var body: some View {
        ZStack {
            ARViewWrapper(controller: scan)
                .ignoresSafeArea()

            if !scan.showConfirm {
                VStack {
                    HStack {
                        Button(action: { showFiles = true }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(width: 48, height: 48)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Exports")
                        Spacer()
                    }

                    if !scan.isSupported {
                        Text("This device has no LiDAR scanner, so scanning is unavailable.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if scan.isScanning {
                        ScanStatusPill(trackingState: scan.trackingState, distance: scan.distanceToSurface)
                    }

                    Spacer()

                    if AreaCaptureModel.isSupported && !scan.isScanning && !scan.isFinalizing {
                        Picker("Mode", selection: $mode) {
                            ForEach(ScanMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 240)
                        .padding(4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    Button(action: startOrStop) {
                        Text(scan.isFinalizing ? "…" : scan.isScanning ? "Stop" : "Start")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 84, height: 84)
                            .background(Circle().fill(scan.isScanning ? Color.red : Color.accentColor))
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 4)
                    }
                    .disabled(!scan.isSupported || scan.isFinalizing)
                    .opacity(scan.isSupported ? 1 : 0.4)
                }
                .padding()
            }

            if scan.showConfirm {
                ExportConfirmCard(
                    trackingWasLimited: scan.hadLimitedTracking,
                    onExport: { name in scan.export(name: name) },
                    onDelete: { scan.discard() }
                )
            }
        }
        .fullScreenCover(isPresented: $showFiles) {
            FilesScreen()
        }
        .fullScreenCover(isPresented: $showAreaCapture, onDismiss: { scan.resumePreview() }) {
            AreaCaptureFlow()
        }
    }

    private func startOrStop() {
        if scan.isScanning {
            scan.stop()
        } else if mode == .detailed && AreaCaptureModel.isSupported {
            scan.suspendPreview()
            showAreaCapture = true
        } else {
            scan.start()
        }
    }
}

// Live guidance while scanning: tracking problems first, otherwise distance to the surface
private struct ScanStatusPill: View {
    let trackingState: ARCamera.TrackingState
    let distance: Float?

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(color.opacity(0.85)))
    }

    private var trackingMessage: String? {
        switch trackingState {
        case .notAvailable: return "Tracking unavailable"
        case .limited(.excessiveMotion): return "Move slower"
        case .limited(.insufficientFeatures): return "More light or texture needed"
        case .limited(.initializing): return "Starting up…"
        case .limited(.relocalizing): return "Relocalizing…"
        default: return nil
        }
    }

    private var message: String {
        if let trackingMessage { return trackingMessage }
        guard let distance else { return "Point at the surface" }
        let metres = String(format: "%.2f m", distance)
        if distance < 0.3 { return "\(metres) · Move back" }
        if distance <= 1.0 { return "\(metres) · Good" }
        if distance <= 2.0 { return "\(metres) · Closer for detail" }
        return "\(metres) · Move closer"
    }

    private var color: Color {
        if trackingMessage != nil { return .orange }
        guard let distance else { return .gray }
        if distance >= 0.3 && distance <= 1.0 { return .green }
        if distance <= 2.0 { return .orange }
        return .red
    }
}

private struct ExportConfirmCard: View {
    let trackingWasLimited: Bool
    let onExport: (String) -> Void
    let onDelete: () -> Void
    @State private var name = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Save scan?")
                    .font(.headline)

                if trackingWasLimited {
                    Text("Tracking was lost during the scan; accuracy may be reduced.")
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }

                TextField("my_file", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                HStack(spacing: 12) {
                    Button(role: .destructive, action: onDelete) {
                        Text("Delete").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { onExport(name) }) {
                        Text("Export").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
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
