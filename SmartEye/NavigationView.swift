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
struct NavigationView: View{
    @StateObject private var navManager = NavigationManager(session: ARSession())
    
    var body: some View {
        VStack(spacing: 20){
            Text("Indoor Navigation Mode")
                .font(.title)
                .padding()
            
            Text("Current Position: \(format(navManager.currentPosition))")
                .font(.headline)
            
            Button(action:{
                navManager.addWaypoint()
            }){
                Text("Add WayPoint")
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Text("Waypoints: \(navManager.anchors.count)")
                .padding(.top,10)
            
            Spacer()
        }
        .onAppear{
            startARSession()
        }
    }
    
    /// Start AR session with world tracking enabled (SLAM)
    private func startARSession(){
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        navManager.arSession.run(config,options: [.resetTracking, ARSession.RunOptions.removeExistingAnchors])
    }
    
    /// Helper to format position vector
    private func format(_ pos: SIMD3<Float>) -> String{
        return String(format: "(%.2f, %.2f, %.2f)", pos.x, pos.y, pos.z)
    }
}
