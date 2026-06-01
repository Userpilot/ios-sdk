//
//  SwiftUIAutocaptureConfigTestView.swift
//  UserpilotSwiftUISample
//
//  Hub for exercising SwiftUI autocapture view modifiers from the SDK.
//

import SwiftUI
import Userpilot

/// Screens and samples that map to `Sources/Userpilot/AutoCapture/APIs/SwiftUI`.
struct SwiftUIAutocaptureConfigTestView: View {
    @State private var tapRecognizedCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                introCard

                modifierCard(
                    title: "Screen name",
                    symbol: "rectangle.on.rectangle.angled",
                    tint: .indigo,
                    api: ".userpilotScreenName(_:)",
                    detail: "Sets the resolved screen name for automatic capture via a preference bridge to UIKit. This screen uses .userpilotScreenName(\"SwiftUIAutocaptureConfig\")."
                )

                modifierCard(
                    title: "Manual screen event",
                    symbol: "waveform.path.ecg",
                    tint: .teal,
                    api: ".userpilotScreen(_:)",
                    detail: "Posts a screen event when the modified view appears (calls Userpilot.shared.screen). Use for explicit screen transitions outside automatic naming."
                )

                modifierCard(
                    title: "Click analytics label",
                    symbol: "hand.tap.fill",
                    tint: .orange,
                    api: ".userpilotLabel(_:)",
                    detail: "Adds explicit capture text and view type metadata to gesture-driven or composite views. Try the tile below and verify named events in your analytics pipeline."
                )

                recognizeClickDemo

                NavigationLink {
                    RedactAndIgnoreTestView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "eye.slash.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.purple.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Redact & ignore playground")
                                .font(.headline)
                            Text("userpilotRedactText · userpilotIgnoreInteractions — full interactive examples")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.purple.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("SwiftUI autocapture")
        .navigationBarTitleDisplayMode(.inline)
        .userpilotScreenName("SwiftUIAutocaptureConfig")
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Autocapture modifiers", systemImage: "slider.horizontal.3")
                .font(.title3.weight(.semibold))

            Text(
                "These APIs configure how Userpilot’s SwiftUI layer participates in autocapture: " +
                "screen resolution, manual screen calls, click recognition, text redaction, and ignoring interactions."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.18), Color.cyan.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    private func modifierCard(
        title: String,
        symbol: String,
        tint: Color,
        api: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
            }

            Text(api)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var recognizeClickDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live sample")
                .font(.subheadline.weight(.semibold))

            Text("Taps: \(tapRecognizedCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "sparkles")
                Text("Tap — uses .onTapGesture + .userpilotLabel()")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.85), Color.red.opacity(0.65)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture {
                tapRecognizedCount += 1
            }
            .userpilotLabel("AutocaptureConfigTapTile")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    NavigationStack {
        SwiftUIAutocaptureConfigTestView()
    }
}
