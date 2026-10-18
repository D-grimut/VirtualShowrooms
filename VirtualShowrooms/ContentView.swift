//
//  ContentView.swift
//  VirtualShowrooms
//
//  Created by Kelvin J on 5/17/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var scan = ScanController()
    @State private var showFiles = false

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

                    Spacer()

                    Button(action: {
                        scan.isScanning ? scan.stop() : scan.start()
                    }) {
                        Text(scan.isScanning ? "Stop" : "Start")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 84, height: 84)
                            .background(Circle().fill(scan.isScanning ? Color.red : Color.accentColor))
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(radius: 4)
                    }
                    .disabled(!scan.isSupported)
                    .opacity(scan.isSupported ? 1 : 0.4)
                }
                .padding()
            }

            if scan.showConfirm {
                ExportConfirmCard(
                    onExport: { name in scan.export(name: name) },
                    onDelete: { scan.discard() }
                )
            }
        }
        .fullScreenCover(isPresented: $showFiles) {
            FilesScreen()
        }
    }
}

private struct ExportConfirmCard: View {
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
