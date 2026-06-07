//
//  ScreenTwo.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI
import Userpilot

struct ScreenTwo: View {
    @State private var showSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard

                Button {
                    showSheet = true
                } label: {
                    HStack {
                        Label("Present modal sheet", systemImage: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .purple.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Screen Two")
        .navigationBarTitleDisplayMode(.inline)
        .userpilotScreenName("Screen Two")
        .onAppear {
            UserpilotManager.shared.screen("Screen Two")
        }
        .sheet(isPresented: $showSheet) {
            ModalSheetView()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Screen Two")
                .font(.title.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Text("End of the basic flow. Manual screen \"Screen Two\" is sent on appear. Open the sheet to see a stacked presentation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.indigo.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.purple.opacity(0.28), lineWidth: 1)
        )
    }
}

struct ModalSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Modal sheet", systemImage: "rectangle.on.rectangle")
                        .font(.title2.weight(.semibold))
                    Text("Sheets are useful for testing how autocapture behaves over presented content.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("Dismiss", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Modal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview("Screen Two") {
    NavigationStack {
        ScreenTwo()
    }
}

#Preview("Modal") {
    ModalSheetView()
}
