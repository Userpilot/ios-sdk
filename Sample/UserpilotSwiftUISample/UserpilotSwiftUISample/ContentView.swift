//
//  ContentView.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import SwiftUI
import Userpilot

struct ContentView: View {
    @State private var showIdentifyScreen = false
    @State private var showScreensFlow = false
    @State private var showAutocaptureConfig = false
    @State private var showClickAnalyticsDemo1 = false
    @State private var showClickAnalyticsDemo2 = false
    @State private var showTabDemo1 = false
    @State private var showTabDemo2 = false
    @State private var showUIComponent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    sampleSection(
                        title: "User & screens",
                        description: "Identify the current user and walk through a multi-step navigation flow for automatic screen tracking.",
                        sectionIcon: "person.crop.circle.badge.checkmark",
                        sectionTint: .indigo
                    ) {
                        sampleRow(
                            title: "Identify",
                            subtitle: "Set user traits and verify identification events.",
                            icon: "person.text.rectangle",
                            gradient: [.indigo, .blue],
                            action: { showIdentifyScreen = true }
                        )
                        sampleRow(
                            title: "Screens",
                            subtitle: "Push ScreenOne → ScreenTwo to exercise screen capture.",
                            icon: "rectangle.stack",
                            gradient: [.blue, .cyan],
                            action: { showScreensFlow = true }
                        )
                    }

                    sampleSection(
                        title: "Click analytics",
                        description: "Demos for gesture-heavy SwiftUI and accessibility-driven click capture.",
                        sectionIcon: "hand.tap.fill",
                        sectionTint: .orange
                    ) {
                        sampleRow(
                            title: "Click analytics demo 1",
                            subtitle: "First set of patterns for recognized vs unrecognized taps.",
                            icon: "1.circle.fill",
                            gradient: [.orange, .yellow],
                            action: { showClickAnalyticsDemo1 = true }
                        )
                        sampleRow(
                            title: "Click analytics demo 2",
                            subtitle: "Additional layouts and edge cases for click analytics.",
                            icon: "2.circle.fill",
                            gradient: [.pink, .orange],
                            action: { showClickAnalyticsDemo2 = true }
                        )
                    }

                    sampleSection(
                        title: "Tabs & structure",
                        description: "Tab-based navigation samples to validate hierarchy and screen boundaries.",
                        sectionIcon: "square.split.2x1.fill",
                        sectionTint: .mint
                    ) {
                        sampleRow(
                            title: "Tab demo 1",
                            subtitle: "Primary tab bar scenario for autocapture.",
                            icon: "rectangle.split.2x1.fill",
                            gradient: [.mint, .teal],
                            action: { showTabDemo1 = true }
                        )
                        sampleRow(
                            title: "Tab demo 2",
                            subtitle: "Alternate tab configuration and nested content.",
                            icon: "square.grid.2x2.fill",
                            gradient: [.teal, .green],
                            action: { showTabDemo2 = true }
                        )
                    }

                    sampleSection(
                        title: "SwiftUI autocapture & UI",
                        description: "Tweak SwiftUI modifiers for screens, clicks, redaction, and ignored views — plus bundled UI component demos.",
                        sectionIcon: "slider.horizontal.3",
                        sectionTint: .purple
                    ) {
                        sampleRow(
                            title: "SwiftUI autocapture config",
                            subtitle: "Screen name, trackScreen, click recognition, and link to redact/ignore tests.",
                            icon: "gearshape.2.fill",
                            gradient: [.purple, .indigo],
                            action: { showAutocaptureConfig = true }
                        )
                        sampleRow(
                            title: "UI components",
                            subtitle: "Combined controls and layouts used across the sample app.",
                            icon: "rectangle.3.group.fill",
                            gradient: [.indigo, .blue],
                            action: { showUIComponent = true }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(isPresented: $showIdentifyScreen) {
                IdentifyScreen()
            }
            .navigationDestination(isPresented: $showScreensFlow) {
                ScreenOne()
            }
            .navigationDestination(isPresented: $showAutocaptureConfig) {
                SwiftUIAutocaptureConfigTestView()
            }
            .navigationDestination(isPresented: $showClickAnalyticsDemo1) {
                ContentViewClickAnalyticsDemo1()
            }
            .navigationDestination(isPresented: $showClickAnalyticsDemo2) {
                ContentViewClickAnalyticsDemo2()
            }
            .navigationDestination(isPresented: $showTabDemo1) {
                ContentViewTabDemo1()
            }
            .navigationDestination(isPresented: $showTabDemo2) {
                ContentViewTabDemo2()
            }
            .navigationDestination(isPresented: $showUIComponent) {
                UIComponentsDemo.CombinedUIComponentsView()
            }
            .navigationTitle("Userpilot sample")
            .userpilotScreenName("HomeScreen")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "app.badge.checkmark.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .blue.opacity(0.85))

                VStack(alignment: .leading, spacing: 4) {
                    Text("SwiftUI sample")
                        .font(.title2.weight(.bold))
                    Text("Pick a section below to try Userpilot SDK features end to end.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("This home screen is tagged with .userpilotScreenName(\"HomeScreen\") for automatic screen naming.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.22), Color.purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func sampleSection<Content: View>(
        title: String,
        description: String,
        sectionIcon: String,
        sectionTint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: sectionIcon)
                    .font(.title3)
                    .foregroundStyle(sectionTint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                content()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(sectionTint.opacity(0.2), lineWidth: 1)
        )
    }

    private func sampleRow(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: gradient.first?.opacity(0.35) ?? .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
