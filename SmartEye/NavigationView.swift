//
//  NavigationView.swift
//  SmartEye
//
//  Created by Amir Ali on 9/12/25.
//

import SwiftUI
import ARKit
import Foundation

/// SwiftUI view for indoor navigation mode
struct NavigationView: View {
    @StateObject private var arManager = ARManager()
    
    // file URL where we'll store the world map
    private var worldMapURL: URL {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return doc.appendingPathComponent("smartEye_worldmap.arexperience")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Indoor Navigation Mode")
                .font(.title.bold())
                .padding(.top, 20)
            
            Spacer()
            
            // Big centered obstacle & pose info
            if let d = arManager.nearestDistance {
                Text(String(format: "Nearest Obstacle: %.2f m", d))
                    .font(.system(size: 22, weight:  .semibold, design: .rounded))
                    .accessibilityLabel("\(Int(d*100)) cm")
                    .padding()
            } else{
                Text("Nearest Obstacle: -")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            //Pose (debug-friendly)
            VStack(spacing:6) {
                Text("Pose (x, y, z): ")
                    .font(.subheadline.weight(.semibold))
                Text(formatPosition(arManager.currentPosition))
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.top,8)
            
            Spacer()
            
            // Save/Load map controls
            HStack(spacing: 12) {
                Button(action: saveMap){
                    Label("Save Map", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Save the scanned map for future relocalization")
                
                Button(action: loadMap){
                    Label("Load Map", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint( "Load a previously saved map")
            }
            .padding(.horizontal)
            
            // Relocalization indicator
            HStack{
                Text("Relocalized: ")
                Spacer()
                Text(arManager.isRelocalized ? "Yes": "No")
                    .foregroundStyle(arManager.isRelocalized ? .green: .red)
            }
            .padding()
        }
        .onAppear{
            arManager.startSession()
        }
        .onDisappear(){
            arManager.stopSession()
        }
    }
    
    // MARK: - Actions
    private func saveMap() {
        VoiceManager.announce("Saving map")
        arManager.saveWorldMap(to: worldMapURL) { success, error in
            if success {
                VoiceManager.announce("Map saved successfully")
            } else {
                VoiceManager.announce("Failed to save map")
                print("save error:", error ?? "unknown")
            }
        }
    }
    
    private func loadMap() {
        VoiceManager.announce("Loading map")
        arManager.loadWorldMap(from: worldMapURL){ success, error in
            if success {
                VoiceManager.announce("Map loaded; relocalizing")
            } else{
                VoiceManager.announce("Failed to load map")
                print("load error", error ?? "unknown")
            }
        }
    }
    
    private func formatPosition(_ pos: SIMD3<Float>) -> String {
        String( format: "(%.2f, %.2f, %.2f)", pos.x, pos.y, pos.z)
    }
}
