//
//  NavigationManager.swift
//  SmartEye
//
//  Created by Amir Ali on 9/11/25.
//

import Foundation
import ARKit
import simd


/// Handles indoor navigation by using ARKit's SLAM (Simultaneous Localization and Mapping)
class NavigationManager: NSObject, ObservableObject, ARSessionDelegate {
    
    /// Shared ARSession for tracking position and mapping
    let arSession:ARSession
    
    /// Keep track of anchor positions in the environment
    @Published var anchors: [ARAnchor] = []
    
    /// Current device position (in world coordinates)
    @Published var currentPosition: SIMD3<Float> = [0,0,0]
    
    init(session: ARSession){
        self.arSession = session
        super.init()
        self.arSession.delegate = self
    }
    
    /// Called by ARKit whenever new frames are processed
    func session(_ session: ARSession, didUpdate frame: ARFrame){
        // Extract current camera position
        let transform = frame.camera.transform
        currentPosition = SIMD3<Float>(transform.columns.3.x,
                                       transform.columns.3.y,
                                       transform.columns.3.z)
    }
    
    /// Add a waypoint anchor at the current device position
    func addWaypoint(){
        let anchor = ARAnchor(name: "waypoint", transform: matrix_identity_float4x4)
        arSession.add(anchor: anchor)
        anchors.append(anchor)
    }
}
