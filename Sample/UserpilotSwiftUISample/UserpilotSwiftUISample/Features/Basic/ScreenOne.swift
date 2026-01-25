//
//  ScreenOne.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI

struct ScreenOne: View {
    @Environment(\.dismiss) var dismiss
    @State private var showScreenTwo = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Screen One")
                .font(.largeTitle)
                .accessibilityLabel("TEST YESSS")
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits([.isButton])
            
            Button("Next") {
                showScreenTwo = true
            }
            .accessibilityLabel("TEST HEREEEEEE")
            .accessibilityIdentifier("AAAAA twowowow")
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Screen One")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showScreenTwo) {
            ScreenTwo()
        }
    }
}

#Preview {
    NavigationStack {
        ScreenOne()
    }
}
