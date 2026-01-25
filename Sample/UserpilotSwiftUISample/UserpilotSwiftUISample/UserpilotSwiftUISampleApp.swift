//
//  UserpilotSwiftUISampleApp.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI
import Userpilot

@main
struct UserpilotSwiftUISampleApp: App {
    
    init() {
        UserpilotManager.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
