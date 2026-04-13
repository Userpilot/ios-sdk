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
    @State private var showRedactIgnoreTest = false
    @State private var showClickAnalyticsDemo1 = false
    @State private var showClickAnalyticsDemo2 = false
    @State private var showTabDemo1 = false
    @State private var showTabDemo2 = false
    @State private var showUIComponent = false

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
                
                Button("Redact & Ignore Test") {
                    showRedactIgnoreTest = true
                }
                .buttonStyle(.borderedProminent)

                Button("Click Analytics Demo 1") {
                    showClickAnalyticsDemo1 = true
                }
                .buttonStyle(.borderedProminent)

                Button("Click Analytics Demo 2") {
                    showClickAnalyticsDemo2 = true
                }
                .buttonStyle(.borderedProminent)

                Button("Tab Demo 1") {
                    showTabDemo1 = true
                }
                .buttonStyle(.borderedProminent)

                Button("Tab Demo 2") {
                    showTabDemo2 = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("UI components") {
                    showUIComponent = true
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
            .navigationDestination(isPresented: $showRedactIgnoreTest) {
                RedactAndIgnoreTestView()
            }
            .navigationDestination(isPresented: $showClickAnalyticsDemo1) {
                ContentViewClickAnalyticsDemo1()
            }
            .navigationDestination(isPresented: $showClickAnalyticsDemo2) {
                ContentViewClickAnalyticsDemo2()
            }
            .navigationDestination(isPresented: $showTabDemo1) {
                ContentViewTabDemo1()
            }
            .navigationDestination(isPresented: $showTabDemo2) {
                ContentViewTabDemo2()
            }
            .navigationDestination(isPresented: $showUIComponent) {
                UIComponentsDemo.CombinedUIComponentsView()
            }
            .navigationTitle("Test Title here")
            .userpilotScreenName("HomeScreen")
        }
    }
}

#Preview {
    ContentView()
}
