//
//  ContentView.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI
import UIKit
import ObjectiveC
import Userpilot

struct ContentView: View {
    @State private var showIdentifyScreen = false
    @State private var showScreensFlow = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                
                Button("Identify") {
                    showIdentifyScreen = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Screens") {
                    showScreensFlow = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationDestination(isPresented: $showIdentifyScreen) {
                IdentifyScreen()
            }
            .navigationDestination(isPresented: $showScreensFlow) {
                ScreenOne()
            }
            .userpilotScreenName("HomeScreen")
        }
    }
}

#Preview {
    ContentView()
}
