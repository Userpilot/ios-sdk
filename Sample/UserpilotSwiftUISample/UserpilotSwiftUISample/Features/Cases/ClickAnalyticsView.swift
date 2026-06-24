//
//  ClickAnalyticsView.swift
//  UserpilotSwiftUISample
//
//  Click-analytics playground. Exercises every control the Userpilot SDK
//  captures automatically in pure SwiftUI, plus the `.userpilotLabel(_:)`
//  escape hatch for gesture-driven / custom views that have no inherent title.
//
//  What to verify: tap any control below and confirm the captured
//  `mobile_autocapture` event carries the expected `target_text`.
//

import SwiftUI
import Userpilot

struct ClickAnalyticsView: View {
    @State private var counter = 0
    @State private var toggleOn = true
    @State private var menuChoice = "Small"
    @State private var selectedCard: String?
    @State private var showAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro

                // MARK: Auto-captured controls (no extra code needed)

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(
                        "Captured automatically",
                        "Native SwiftUI controls — the SDK resolves the title with no extra code.")

                    GroupBox("Buttons") {
                        VStack(spacing: 12) {
                            Button("Confirm Order") { counter += 1 }
                                .buttonStyle(.borderedProminent)

                            Button("Add to Cart") { counter += 1 }
                                .buttonStyle(.bordered)

                            // Custom-styled button — the SDK reads the label text.
                            Button {
                                counter += 1
                            } label: {
                                Text("Custom Styled Button")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    GroupBox("NavigationLink") {
                        NavigationLink("Open Detail Screen") {
                            Text("Detail Screen")
                                .navigationTitle("Detail")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Toggle (UISwitch under the hood)") {
                        Toggle("Enable Notifications", isOn: $toggleOn)
                    }

                    GroupBox("Menu") {
                        Menu("Choose Size: \(menuChoice)") {
                            Button("Small") { menuChoice = "Small" }
                            Button("Medium") { menuChoice = "Medium" }
                            Button("Large") { menuChoice = "Large" }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Link") {
                        Link("Open userpilot.com", destination: URL(string: "https://userpilot.com")!)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // MARK: Needs .userpilotLabel

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(
                        ".userpilotLabel(_:) — for gesture & custom views",
                        "Containers with .onTapGesture (or fully custom components) have no inherent title, so tag them explicitly.")

                    GroupBox("VStack + .onTapGesture") {
                        VStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.yellow)
                            Text("Favorite")
                                .font(.headline)
                            Text("Tapped \(counter) times")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                        .onTapGesture { counter += 1 }
                        .userpilotLabel("Favorite Tile")
                    }

                    GroupBox("Custom card grid") {
                        HStack(spacing: 12) {
                            ForEach(["Swift", "SwiftUI", "UIKit"], id: \.self) { tech in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedCard == tech ? Color.purple : Color.purple.opacity(0.25))
                                    Text(tech)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(selectedCard == tech ? .white : .primary)
                                }
                                .frame(height: 72)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedCard = tech }
                                .userpilotLabel("Tech Card \(tech)")
                            }
                        }
                    }

                    GroupBox("Reusable component") {
                        VStack(spacing: 12) {
                            CustomActionCard(icon: "camera.fill", title: "Take Photo", color: .blue) {
                                showAlert = true
                            }
                            CustomActionCard(icon: "photo.fill", title: "Choose from Library", color: .green) {
                                showAlert = true
                            }
                        }
                    }
                }

                // MARK: Redact & ignore

                NavigationLink {
                    RedactAndIgnoreTestView()
                } label: {
                    rowLink(
                        icon: "eye.slash.fill",
                        tint: .purple,
                        title: "Redact & ignore playground",
                        subtitle: "userpilotRedactText · userpilotIgnoreInteractions"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Click Analytics")
        .userpilotScreenName("Click Analytics")
        .alert("Captured ✓", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This custom component is captured via .userpilotLabel(title).")
        }
    }

    // MARK: - Building blocks

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Button & click capture", systemImage: "hand.tap.fill")
                .font(.title3.weight(.semibold))
            Text("Native controls are captured automatically. Gesture-driven or custom views need .userpilotLabel(_:) so the event carries a meaningful title.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.orange.opacity(0.18), .pink.opacity(0.12)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func rowLink(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Custom Reusable Component (uses userpilotLabel)

/// Custom component with no inherent title — tagged via `.userpilotLabel(title)`.
struct CustomActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .userpilotLabel(title)
    }
}

#Preview {
    NavigationStack {
        ClickAnalyticsView()
    }
}
