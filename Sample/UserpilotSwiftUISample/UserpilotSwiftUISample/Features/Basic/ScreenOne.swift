//
//  ScreenOne.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI
import Userpilot

struct ScreenOne: View {
    @State private var eventName = ""
    @State private var trackKey1 = ""
    @State private var trackValue1 = ""
    @State private var trackKey2 = ""
    @State private var trackValue2 = ""
    @State private var didTrack = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard

                NavigationLink {
                    ScreenTwo()
                } label: {
                    HStack {
                        Label("Continue to Screen Two", systemImage: "arrow.right.circle.fill")
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
                            colors: [Color.teal, Color.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .teal.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)

                formCard(
                    title: "Custom event",
                    subtitle: "Calls UserpilotManager.track(eventName:properties:).",
                    icon: "bolt.fill"
                ) {
                    TextField("Event name", text: $eventName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Properties (optional)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    trackPropertyRow(key: $trackKey1, value: $trackValue1, label: "Row 1")
                    trackPropertyRow(key: $trackKey2, value: $trackValue2, label: "Row 2")

                    Button(action: sendTrack) {
                        Label("Send event", systemImage: "paperplane.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? [Color.gray.opacity(0.45), Color.gray.opacity(0.3)]
                                        : [Color.orange, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)

                    if didTrack {
                        Text("Track call dispatched.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Screen One")
        .navigationBarTitleDisplayMode(.inline)
        .userpilotScreenName("Screen One")
        .onAppear {
            UserpilotManager.shared.screen("Screen One")
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Screen One")
                .font(.title.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Text("Manual screen \"Screen One\" is reported on appear via UserpilotManager. Auto-capture may suppress manual screen calls when enabled in config.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.teal.opacity(0.22), Color.mint.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.teal.opacity(0.28), lineWidth: 1)
        )
    }

    private func formCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func trackPropertyRow(key: Binding<String>, value: Binding<String>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("source", text: key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Value")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("settings", text: value)
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sendTrack() {
        let name = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        var props: [String: Any] = [:]
        addPair(key: trackKey1, value: trackValue1, into: &props)
        addPair(key: trackKey2, value: trackValue2, into: &props)

        UserpilotManager.shared.track(
            eventName: name,
            properties: props.isEmpty ? nil : props
        )
        didTrack = true
    }

    private func addPair(key: String, value: String, into props: inout [String: Any]) {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        props[k] = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack {
        ScreenOne()
    }
}
