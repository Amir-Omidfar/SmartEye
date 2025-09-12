//
//  ContentView.swift
//  SmartEye
//
//  Created by Amir Ali on 9/10/25.
//

import SwiftUI

enum AppMode: String, CaseIterable, Identifiable {
    case obstacle = "Obstacle Avoidance"
    case indoor = "Indoor Navigation"
    case outdoor = "Outdoor Navigation"
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var arManager = ARManager()
    @StateObject private var hapticManager = HapticManager.shared
    @State private var selectedMode: AppMode = .obstacle
    @State private var running = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Navigation Modes")
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)

                // Mode selector — VoiceOver-friendly
                Picker("Mode", selection: $selectedMode) {
                    ForEach(AppMode.allCases) { mode in
                        Text(mode.rawValue)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityLabel("Operating mode")
                .accessibilityHint("Choose obstacle avoidance, indoor navigation (placeholder), or outdoor navigation (placeholder).")
                .padding()

                // Placeholder info for modes 2 & 3
                HStack(spacing: 12) {
                    ModeCard(title: "Mode 1", subtitle: "Obstacle Avoidance", isActive: selectedMode == .obstacle)
                    ModeCard(title: "Mode 2", subtitle: "Indoor Navigation (coming soon)", isActive: selectedMode == .indoor)
                    ModeCard(title: "Mode 3", subtitle: "Outdoor Navigation (coming soon)", isActive: selectedMode == .outdoor)
                }
                .padding(.horizontal)

                Spacer()

                // Large start/stop button
                Button(action: {
                    running.toggle()
                    if running {
                        startMode()
                    } else {
                        stopMode()
                    }
                }) {
                    Text(running ? "Stop" : "Start")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(running ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .accessibilityLabel(running ? "Stop" : "Start")
                .accessibilityHint(running ? "Double tap to stop sensing" : "Double tap to start obstacle avoidance")

                // Status / readouts
                VStack(spacing: 8) {
                    HStack {
                        Text("Mode:")
                        Spacer()
                        Text(selectedMode.rawValue)
                    }
                    HStack {
                        Text("Running:")
                        Spacer()
                        Text(running ? "Yes" : "No")
                    }
                    HStack {
                        Text("Nearest obstacle:")
                        Spacer()
                        if let d = arManager.nearestDistance {
                            Text(String(format: "%.2f m", d))
                                .accessibilityLabel("\(Int(d * 100)) centimeters")
                        } else {
                            Text("—")
                        }
                    }
                    HStack {
                        Text("Relocalized:")
                        Spacer()
                        Text(arManager.isRelocalized ? "Yes" : "No")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Assistive Nav")
            .onDisappear { stopMode() }
        }
    }

    private func startMode() {
        switch selectedMode {
        case .obstacle:
            arManager.startSession()
            hapticManager.prepare() // initialize engine
            VoiceManager.announce("Obstacle avoidance started")
        case .indoor:
            VoiceManager.announce("Indoor navigation is not available yet. Mode 1 is recommended.")
        case .outdoor:
            VoiceManager.announce("Outdoor navigation is not available yet. Mode 1 is recommended.")
        }
    }

    private func stopMode() {
        arManager.stopSession()
        VoiceManager.announce("Stopped")
    }
}

struct ModeCard: View {
    let title: String
    let subtitle: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(isActive ? Color.green.opacity(0.15) : Color(UIColor.systemGray6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
