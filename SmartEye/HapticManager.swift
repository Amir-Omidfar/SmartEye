//
//  HapticManager.swift
//  SmartEye
//
//  Created by Amir Ali on 9/11/25.
//

import Foundation
import CoreHaptics

final class HapticManager: NSObject, ObservableObject {
    static let shared = HapticManager()
    private var engine: CHHapticEngine?
    private(set) var available: Bool = false
    
    private override init() {
        super.init()
        prepareEngine()
    }
    
    func prepare() {
        // no-op for external callers: engine is prepared at init
    }
    
    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
                    available = false
                    return
        }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            available = true
        } catch {
            print("Error starting haptic engine:",error)
            available = false
        }
    }
    
    enum Pattern {
        case notice
        case alert
        case urgent
    }
    
    /// Play a short haptic pattern mapping intensity and pattern type
        func playProximity(intensity: Float, pattern: Pattern) {
            guard available, let engine = engine else { return }
            let clampedIntensity = max(0, min(1, intensity))
            let sharpness = clampedIntensity

            var events: [CHHapticEvent] = []
            switch pattern {
            case .notice:
                let e = CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity * 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness * 0.4)
                ], relativeTime: 0)
                events = [e]
            case .alert:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity * 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness * 0.6)
                    ], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity * 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness * 0.5)
                    ], relativeTime: 0.12)
                ]
            case .urgent:
                events = [
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ], relativeTime: 0, duration: 0.3)
                ]
            }

            do {
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                print("Failed to play haptic:", error)
            }
        }
}
