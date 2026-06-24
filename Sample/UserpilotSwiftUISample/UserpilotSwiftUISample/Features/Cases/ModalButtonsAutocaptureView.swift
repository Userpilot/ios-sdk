//
//  ModalButtonsAutocaptureView.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 22/06/2026.
//

import SwiftUI
import Userpilot

struct ModalButtonsAutocaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var counter = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("This screen is presented as a sheet, not pushed with navigationDestination.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Modal Primary Button") {
                    counter += 1
                }
                .buttonStyle(.borderedProminent)

                Button {
                    counter += 1
                } label: {
                    Text("Modal Custom Styled Button")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button("Dismiss Modal") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Text("Tapped \(counter) times")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Modal Buttons")
            .userpilotScreenName("Modal Buttons")
        }
    }
}
