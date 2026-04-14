//
//  IdentifyScreen.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI
import Userpilot

struct IdentifyScreen: View {
    @State private var userId: String = ""
    @State private var propertyKey1 = ""
    @State private var propertyValue1 = ""
    @State private var propertyKey2 = ""
    @State private var propertyValue2 = ""
    @State private var didSave = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerCard

                formCard(title: "User ID", subtitle: "Required to identify this device session.", icon: "person.fill") {
                    TextField("e.g. user_48291", text: $userId)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                formCard(
                    title: "User properties",
                    subtitle: "Optional. Up to two key–value pairs sent with identify().",
                    icon: "list.bullet.rectangle"
                ) {
                    propertyRow(key: $propertyKey1, value: $propertyValue1, rowLabel: "Property 1")
                    propertyRow(key: $propertyKey2, value: $propertyValue2, rowLabel: "Property 2")
                }

                Button(action: saveIdentify) {
                    Label("Save & identify", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? [Color.gray.opacity(0.5), Color.gray.opacity(0.35)]
                                    : [Color.indigo, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .indigo.opacity(userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 0.35), radius: 10, y: 4)
                }
                .disabled(userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)

                if didSave {
                    Label("Identify sent to Userpilot.", systemImage: "paperplane.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Identify")
        .navigationBarTitleDisplayMode(.inline)
        .userpilotScreenName("Identify Screen")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Identify user", systemImage: "person.crop.circle.badge.plus")
                .font(.title3.weight(.semibold))
            Text("Sets the active user in the SDK. Properties are merged into the user profile when keys are non-empty.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.2), Color.blue.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.indigo.opacity(0.25), lineWidth: 1)
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
                    .foregroundStyle(.indigo)
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
    }

    private func propertyRow(key: Binding<String>, value: Binding<String>, rowLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rowLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("plan", text: key)
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
                    TextField("pro", text: value)
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func saveIdentify() {
        let trimmedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }

        var props: [String: Any] = [:]
        addPair(key: propertyKey1, value: propertyValue1, into: &props)
        addPair(key: propertyKey2, value: propertyValue2, into: &props)

        UserpilotManager.shared.identify(
            userId: trimmedId,
            properties: props.isEmpty ? nil : props
        )
        didSave = true
    }

    private func addPair(key: String, value: String, into props: inout [String: Any]) {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        props[k] = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack {
        IdentifyScreen()
    }
}
