
import Foundation
import ARKit
import Combine
import simd


/// ARManager: single place to run ARSession (SLAM), expose pose & relocalization,
/// provide map (ARWorldMap) save/load helpers, and throttle mode-1 feedback.

final class ARManager: NSObject, ObservableObject {
    // MARK: - Published state for UI binding
    @Published var nearestDistance: Float? = nil          // from mode 1 depth sampling
    @Published var isRelocalized: Bool = false           // whether ARKit reports mapped/extended
    @Published var currentTransform: simd_float4x4 = matrix_identity_float4x4 // device transform
    @Published var currentPosition: SIMD3<Float> = [0,0,0] // convenience
    
    let arSession = ARSession() //exposed so Views can call run/pause if needed
    
    // MARK: Private internals
    private var lastAnnouncedDistance: Float?
    private var announcementThresholds: [Float] = [1.5, 1.0, 0.5] // meters
    // Throttling controls
    private var lastFeedbackTime: Date = .distantPast
    private var feedbackInterval: TimeInterval = 0.7 // seconds (adjustable)
    private var feedbackDistanceLimit: Float = 0.1   // meters (adjustable)
    private var runDistanceCheck = false             // boolean to use the distance check
    private var lastProcessedDistance: Float?
    
    private var cancellables = Set<AnyCancellable>() // TODO: remove

    override init() {
        super.init()
        arSession.delegate = self
    }

    // MARK: - Session lifecycle
    /// Start SLAM session. Uses scene reconstruction (mesh) when device supports it (LiDAR)
    /// Using scene reconstruction (mesh) gives denser geometry on LiDAR devices. See Apple docs.
    
    func startSession() {
        let config = ARWorldTrackingConfiguration()
        
        // Use scene reconstruction when available (LiDAR devices)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        // Use sceneDepth on devices that support if (it helps obstacle avoidance)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        config.environmentTexturing = .none
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // reset public state
        isRelocalized = false
        nearestDistance = nil
    }

    func stopSession() {
        arSession.pause()
        nearestDistance = nil
    }
    
    // MARK: - World map helpers

        /// Capture ARKit's current ARWorldMap (async) — use this to persist maps.

        func fetchCurrentWorldMap(completion: @escaping (ARWorldMap?) -> Void) {

            arSession.getCurrentWorldMap { worldMap, error in

                if let error = error {

                    print("ARManager: error getting world map:", error.localizedDescription)

                    completion(nil)

                    return

                }

                completion(worldMap)

            }

        }



        /// Save world map to a file URL (archives ARWorldMap). Calls completion on main queue.

        func saveWorldMap(to url: URL, completion: @escaping (Bool, Error?) -> Void) {

            fetchCurrentWorldMap { map in

                guard let map = map else {

                    DispatchQueue.main.async { completion(false, nil) }

                    return

                }

                do {

                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)

                    try data.write(to: url)

                    DispatchQueue.main.async { completion(true, nil) }

                } catch {

                    DispatchQueue.main.async { completion(false, error) }

                }

            }

        }



        /// Load a world map previously archived at URL, and relaunch the session with it as the initial map.

        func loadWorldMap(from url: URL, completion: @escaping (Bool, Error?) -> Void) {

            do {

                let data = try Data(contentsOf: url)

                guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {

                    DispatchQueue.main.async { completion(false, nil) }

                    return

                }



                let config = ARWorldTrackingConfiguration()

                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {

                    config.sceneReconstruction = .mesh

                }

                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {

                    config.frameSemantics.insert(.sceneDepth)

                }

                config.initialWorldMap = worldMap

                arSession.run(config, options: [.resetTracking, .removeExistingAnchors])

                DispatchQueue.main.async { completion(true, nil) }

            } catch {

                DispatchQueue.main.async { completion(false, error) }

            }

        }
}

// MARK: - ARSessionDelegate: frame updates, depth sampling, relocalization
extension ARManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 1) update pose
        let transform = frame.camera.transform
        DispatchQueue.main.async {
            self.currentTransform = transform
            self.currentPosition = SIMD3<Float>(transform.columns.3.x,
                                                transform.columns.3.y,
                                                transform.columns.3.z)
        }
        
        // 2) smaple depth if available (Mode 1 logic)
        if let sceneDepth = frame.sceneDepth?.depthMap {
            if let distance = sampleNearestDistance(depthMap: sceneDepth) {
                DispatchQueue.main.async { self.nearestDistance = distance}
                // apply throttling before feeding haptics/voice
                processDistanceForFeedbackIfNeeded(distance: distance)
            }
            else {
                DispatchQueue.main.async { self.nearestDistance = nil}
            }
        } else {
            // no scene depth available on device — set nil or a large default
            DispatchQueue.main.async { self.nearestDistance = nil}
        }

        // 3) relocalization status: set when map is well-formed
        let status = frame.worldMappingStatus
        if status == .mapped || status == .extending {
            DispatchQueue.main.async { self.isRelocalized = true }
        } else{
            DispatchQueue.main.async { self.isRelocalized = false }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARSession failed:", error.localizedDescription)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("ARSession interrupted")
    }
}

// MARK: - Depth sampling & throttled feedback
private extension ARManager {
    func sampleNearestDistance(depthMap: CVPixelBuffer) -> Float? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        // We will sample a centered box region (e.g., 20% of width/height) and take median/lowest valid depth
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let format = CVPixelBufferGetPixelFormatType(depthMap)
        guard format == kCVPixelFormatType_DepthFloat32 else { return nil }

        // region definitions
        let boxW = max(2, Int(Float(width) * 0.2))
        let boxH = max(2, Int(Float(height) * 0.2))
        let startX = (width - boxW) / 2
        let startY = (height - boxH) / 2

        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        var depths: [Float] = []
        for y in startY ..< (startY + boxH) {
            let row = base.advanced(by: y * rowBytes).bindMemory(to: Float32.self, capacity: width)
            for x in startX ..< (startX + boxW) {
                let val = row[x]
                if val.isFinite && val > 0 {
                    depths.append(Float(val))
                }
            }
        }
        if depths.isEmpty { return nil }
        // Use a robust statistic: 10th percentile (to avoid single far outliers)
        depths.sort()
        let idx = max(0, min(depths.count - 1, Int(Double(depths.count) * 0.1)))
        return depths[idx]
    }
    // Throttled feedback: combine time and distance thresholds
    func processDistanceForFeedbackIfNeeded(distance: Float) {
        // simple hysteresis / announcement logic: announce when distance crosses thresholds
        // if closer than smallest threshold, urgent haptic + voice
        // Use HapticManager and VoiceManager to produce output
        // Time gating
        let now = Date()
        if now.timeIntervalSince(lastFeedbackTime) < feedbackInterval  {
            return //still within the rate limit, too soon, skip
        }
        if let last = lastProcessedDistance, abs(last - distance) < feedbackDistanceLimit && runDistanceCheck{
            return
        }
        // Accept this update
        lastFeedbackTime = now
        lastProcessedDistance = distance
        if distance <= 0.0 {return}
        
        // urgency levels
        if distance <= announcementThresholds[2] {
            // closest (< 0.5 m)
            HapticManager.shared.playProximity(intensity: 1.0, pattern: .urgent)
            if shouldAnnounce(distance: distance, level: 2) {
                VoiceManager.announce("Obstacle very close. Stop.")
            }
        } else if distance <= announcementThresholds[1] {
            HapticManager.shared.playProximity(intensity: 0.8, pattern: .alert)
            if shouldAnnounce(distance: distance, level: 1) {
                VoiceManager.announce(String(format: "Obstacle %.1f meters ahead", distance))
            }
        } else if distance <= announcementThresholds[0] {
            HapticManager.shared.playProximity(intensity: 0.4, pattern: .notice)
            if shouldAnnounce(distance: distance, level: 0) {
                VoiceManager.announce(String(format: "Object %.1f meters ahead", distance))
            }
        } else {
            // nothing to do
        }
    }

    func shouldAnnounce(distance: Float, level: Int) -> Bool {
        // Announce when crossing to a closer level; simple throttling to avoid repeated utterances
        // We compare lastAnnouncedDistance to current to decide.
        let last = lastAnnouncedDistance ?? Float.greatestFiniteMagnitude
        let threshold = announcementThresholds[level]
        if last > threshold && distance <= threshold {
            lastAnnouncedDistance = distance
            // schedule a decay so we can announce again later if distance changes significantly
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.lastAnnouncedDistance = nil
            }
            return true
        }
        return false
    }
}
