import SwiftUI
import ARKit
import AVFoundation

/// SwiftUI view for Mode 1: Obstacle Avoidance
struct ObstacleAvoidanceView: View {
    @StateObject private var arManager = ARManager()
    @StateObject private var hapticManager = HapticManager.shared
    
    
    // Store last spoken distance (to avoid repeating too often)
    @State private var lastSpokenDistance: Int = -1
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Obstacle Avoidance Mode")
                .font(.title.bold())
                .padding(.top, 40)
            Spacer()
            
            if let d = arManager.nearestDistance {
                Text("Nearest Obstacle: \(String(format: "%.2f", d)) m")
                    .font(.system(size: 22, weight: .semibold, design: .rounded)) // ✅ Bigger + nicer
                    .padding()
                    .accessibilityLabel("\(Int(d * 100)) centimeters")
            } else {
                Text("No obstacle detected")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Text("Relocalized:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(arManager.isRelocalized ? "Yes" : "No")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(arManager.isRelocalized ? .green : .red)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            
        }
        .onAppear {
            arManager.startSession()
            hapticManager.prepare() // initialize engine
            VoiceManager.announce("Obstacle Avoidance Mode Started!")
        }
        .onDisappear(){
            arManager.stopSession()
            VoiceManager.announce("Obstacle Avoidance Mode Stopped!")
        }
        }
    }
    
    
    

