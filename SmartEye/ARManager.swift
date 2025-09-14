
import Foundation
import ARKit
import Combine
import simd

final class ARManager: NSObject, ObservableObject {
    @Published var nearestDistance: Float? = nil
    @Published var isRelocalized: Bool = false

    private let session = ARSession()
    private var lastAnnouncedDistance: Float?
    private var lastFeedbackTime: Date = .distantPast
    private var feedbackInterval: TimeInterval = 1
    private var lastProcessedDistance: Float?
    private var announcementThresholds: [Float] = [1.5, 1.0, 0.5] // meters
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        session.delegate = self
    }

    func startSession() {
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        config.environmentTexturing = .none
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRelocalized = false
        nearestDistance = nil
    }

    func stopSession() {
        session.pause()
        nearestDistance = nil
    }
}

// MARK: - ARSessionDelegate
extension ARManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Sample near-center region depth to find nearest obstacle in front
        if let sceneDepth = frame.sceneDepth?.depthMap {
            if let distance = sampleNearestDistance(depthMap: sceneDepth) {
                DispatchQueue.main.async {
                    self.nearestDistance = distance
                }
                processDistanceForFeedback(distance: distance)
            }
        } else {
            // no scene depth available on device — set nil or a large default
            DispatchQueue.main.async {
                self.nearestDistance = nil
            }
        }

        // detect relocalization (simple heuristic)
        if frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending {
            DispatchQueue.main.async {
                self.isRelocalized = true
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARSession failed:", error.localizedDescription)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("ARSession interrupted")
    }
}

// MARK: - Depth sampling & feedback logic
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

    func processDistanceForFeedback(distance: Float) {
        // simple hysteresis / announcement logic: announce when distance crosses thresholds
        // if closer than smallest threshold, urgent haptic + voice
        // Use HapticManager and VoiceManager to produce output
        let now = Date()
        guard now.timeIntervalSince(lastFeedbackTime) > feedbackInterval else {
            return //too soon, skip
        }
        if let last = lastProcessedDistance, abs(last - distance) < 0.1 {
            return
        }
        lastFeedbackTime = now
        lastProcessedDistance = distance
        
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
/*
import Foundation
import ARKit
import simd

/// Manages ARKit session for obstacle detection
class ARManager: NSObject, ObservableObject, ARSessionDelegate {
    
    let arSession = ARSession()
    
    /// Nearest detected obstacle distance in meters
    @Published var nearestDistance: Float = .infinity
    
    override init() {
        super.init()
        arSession.delegate = self
    }
    
    /// Called when ARKit updates frame
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else { return }
        
        // Access depth map
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        let baseAddress = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap),
                                        to: UnsafeMutablePointer<Float32>.self)
        
        var minDistance: Float = .infinity
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let index = y * width + x
                let distance = baseAddress[index]
                if distance > 0, distance < minDistance {
                    minDistance = distance
                }
            }
        }
        
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        
        DispatchQueue.main.async {
            self.nearestDistance = minDistance
        }
    }
}
*/
