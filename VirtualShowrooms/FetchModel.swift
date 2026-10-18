//
//  FetchModel.swift
//  VirtualShowrooms
//
//  Created by Kelvin J on 5/18/23.
//

import SwiftUI
import SceneKit

class CurrentlyDisplaying: ObservableObject {
    @Published var fileName = ""
}

struct FetchModelView: View {
    @StateObject private var currentlyDisplaying = CurrentlyDisplaying()
    @State private var fileNames: [String] = []
    @State private var fullScreen = false
    
    var body: some View {
        VStack {
            List(self.fileNames, id: \.self) { fileName in
                Button(action: {
                    self.currentlyDisplaying.fileName = fileName
                    self.fullScreen.toggle()
                    
                }) {
                    HStack {
                        Text(fileName)
                        Spacer()
                        Image(systemName: "eye.fill")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive, action: {
                        removeFile(fileName: fileName)
                        withAnimation {
                            fetchFiles()
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .refreshable {
                fetchFiles()
            }
            .fullScreenCover(isPresented: $fullScreen) {
                ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
                    if !self.currentlyDisplaying.fileName.isEmpty {
                        
                        SceneViewWrapper(scene: displayFile(fileName: currentlyDisplaying.fileName))
                    }
                    Button(action: {
                        self.fullScreen = false
                    }) {
                        Text("Back").padding()
                    }
                }
            }
        }.onAppear {
            fetchFiles()
        }
    }
    func fetchFiles() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let folderName = "OBJ_FILES"
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            let filteredURLs = fileURLs.filter { (url) -> Bool in
                return ["obj", "usdz"].contains(url.pathExtension.lowercased())
            }
            
            self.fileNames = filteredURLs.map { $0.lastPathComponent }
        } catch {
            print("Error fetching files: \(error)")
        }
    }
    func displayFile(fileName: String) -> SCNScene {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Failed to access documents directory.")
        }
        
        let folderName = "OBJ_FILES"
        let folderURL = directory.appendingPathComponent(folderName)
        let fileURL = folderURL.appendingPathComponent(fileName)
        let sceneView = try? SCNScene(url: fileURL)
        return sceneView ?? SCNScene()
    }
    func removeFile(fileName: String) {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Failed to access documents directory.")
        }
        
        let folderName = "OBJ_FILES"
        let folderURL = directory.appendingPathComponent(folderName)
        let fileURL = folderURL.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("File removed successfully: \(fileURL)")
        } catch {
            print("Error removing file: \(error)")
        }

        // detailed captures keep their source photos alongside; remove those too
        if fileURL.pathExtension.lowercased() == "usdz" {
            let captureFolder = directory.appendingPathComponent("CAPTURES")
                .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent)
            try? FileManager.default.removeItem(at: captureFolder)
        }

    }
}

// Full-screen export page opened from the hamburger button
struct FilesScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            FetchModelView()
                .navigationTitle("Exports")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}

struct FetchModelView_Previews: PreviewProvider {
    static var previews: some View {
        FetchModelView()
    }
}


struct SceneViewWrapper: UIViewRepresentable {
    let scene: SCNScene?
    func makeUIView(context: Context) -> some UIView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .ambient
        lightNode.light?.color = UIColor.white
        scene?.rootNode.addChildNode(lightNode)
        
        scnView.scene = scene
        scnView.backgroundColor = .clear
        return scnView
    }
    func updateUIView(_ uiView: UIViewType, context: Context) { }
}
