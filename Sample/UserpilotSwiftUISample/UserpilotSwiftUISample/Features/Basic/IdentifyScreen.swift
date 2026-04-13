//
//  IdentifyScreen.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI
import Userpilot

struct IdentifyScreen: View {
    @Environment(\.dismiss) var dismiss
    @State private var textFieldValue: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter text", text: $textFieldValue)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Button("Save") {
                // Save action
                print("Saved: \(textFieldValue)")
                UserpilotManager.shared.identify(userId: textFieldValue)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Identify-titleeee")
        .navigationBarTitleDisplayMode(.inline)
        .userpilotScreenName("Identify Screen")
    }
}

#Preview {
    NavigationStack {
        IdentifyScreen()
    }
}
