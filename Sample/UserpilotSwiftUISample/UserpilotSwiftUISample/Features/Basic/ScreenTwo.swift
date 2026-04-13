//
//  ScreenTwo.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI

struct ScreenTwo: View {
    @Environment(\.dismiss) var dismiss
    @State private var showSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Screen Two")
                .font(.largeTitle)
            
            Button("Show Modal Sheet") {
                showSheet = true
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Screen Two")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSheet) {
            ModalSheetView()
        }
    }
}

struct ModalSheetView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Modal Sheet")
                    .font(.title)
                
                Spacer()
                
                Button("Dismiss") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Modal Sheet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        ScreenTwo()
    }
}
