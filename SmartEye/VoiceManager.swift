//
//  VoiceManager.swift
//  SmartEye
//
//  Created by Amir Ali on 9/11/25.
//

import Foundation
import UIKit
import AVFoundation

struct VoiceManager {
    static func announce(_ text: String) {
        // Use UIAccessibility announcement so VoiceOver plays it if active
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }
}
