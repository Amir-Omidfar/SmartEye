//
//  ModeSelectorView.swift
//  SmartEye
//
//  Created by Amir Ali on 9/12/25.
//

import SwiftUI

/// Root view to select navigation modes
struct ModeSelectorView: View {
    @State private var selectedMode: Int? = nil
    
    var body: some View{
        NavigationStack{
            VStack(spacing: 20){
                Text("SmartEye: Assistave Navigation App")
                    .font(.largeTitle)
                    .padding()
                
                NavigationLink(destination: ObstacleAvoidanceView()) {
                                    Text("Mode 1: Obstacle Avoidance")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                }
                
                NavigationLink(destination: NavigationView()) {
                                Text("Mode 2: Indoor Navigation")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                }
                                
                NavigationLink(destination: Text("Outdoor navigation mode coming soon...")) {
                    Text("Mode 3: Outdoor Navigation (Coming Soon)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}
