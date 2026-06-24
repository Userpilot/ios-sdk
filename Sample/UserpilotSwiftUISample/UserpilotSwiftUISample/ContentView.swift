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
    @State private var showClickAnalytics = false
    @State private var showClickAnalyticsFullScreen = false
    @State private var showClickAnalyticsStateSwap = false
    @State private var showTabsNavigation = false
    @State private var showUIComponent = false
    @State private var showNestedLazyStacks = false
    @State private var showModalButtons = false

    var body: some View {
        if showClickAnalyticsStateSwap {
            NavigationStack {
                ClickAnalyticsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back") {
                                showClickAnalyticsStateSwap = false
                            }
                        }
                    }
            }
        } else {
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
                        description: "Single click analytics flow with practical label-based examples.",
                        sectionIcon: "hand.tap.fill",
                        sectionTint: .orange
                    ) {
                        sampleRow(
                            title: "Click analytics",
                            subtitle: "Buttons first, then gesture and custom component patterns.",
                            icon: "hand.tap.fill",
                            gradient: [.pink, .orange],
                            action: { showClickAnalytics = true }
                        )
                        sampleRow(
                            title: "Click analytics full screen",
                            subtitle: "Open the same screen with fullScreenCover, not navigationDestination.",
                            icon: "arrow.up.left.and.arrow.down.right",
                            gradient: [.orange, .red],
                            action: { showClickAnalyticsFullScreen = true }
                        )
                        sampleRow(
                            title: "Click analytics state swap",
                            subtitle: "Replace the root content manually without navigationDestination.",
                            icon: "rectangle.2.swap",
                            gradient: [.purple, .orange],
                            action: { showClickAnalyticsStateSwap = true }
                        )
                    }

                    sampleSection(
                        title: "Tabs & navigation",
                        description: "Tab bar + NavigationStack pushes, lists, sheets and alerts — validates screen boundaries and tab-title capture.",
                        sectionIcon: "square.split.2x1.fill",
                        sectionTint: .mint
                    ) {
                        sampleRow(
                            title: "Tabs & navigation",
                            subtitle: "Switch tabs and push screens to exercise autocapture.",
                            icon: "rectangle.split.2x1.fill",
                            gradient: [.mint, .teal],
                            action: { showTabsNavigation = true }
                        )
                    }

                    sampleSection(
                        title: "Components & advanced",
                        description: "UIKit-backed SwiftUI controls, and the accessibility-scan opt-out APIs for the FB21851974 hang pattern.",
                        sectionIcon: "slider.horizontal.3",
                        sectionTint: .purple
                    ) {
                        sampleRow(
                            title: "SwiftUI autocapture config",
                            subtitle: "Screen name, userpilotScreen, click recognition, and link to redact/ignore tests.",
                            icon: "gearshape.2.fill",
                            gradient: [.purple, .indigo],
                            action: { showAutocaptureConfig = true }
                        )
                        sampleRow(
                            title: "UI components",
                            subtitle: "Toggles, sliders, pickers, steppers — SwiftUI controls that are UIKit under the hood.",
                            icon: "rectangle.3.group.fill",
                            gradient: [.indigo, .blue],
                            action: { showUIComponent = true }
                        )
                        sampleRow(
                            title: "Nested lazy stacks",
                            subtitle: "userpilotSkipAccessibilityScan / userpilotScanOnce on the FB21851974 hang pattern.",
                            icon: "square.stack.3d.up.fill",
                            gradient: [.orange, .red],
                            action: { showNestedLazyStacks = true }
                        )
                        sampleRow(
                            title: "Modal buttons",
                            subtitle: "Open buttons in a sheet instead of a NavigationStack destination.",
                            icon: "rectangle.on.rectangle.angled",
                            gradient: [.purple, .pink],
                            action: { showModalButtons = true }
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
            .navigationDestination(isPresented: $showClickAnalytics) {
                ClickAnalyticsView()
            }
            .navigationDestination(isPresented: $showTabsNavigation) {
                TabsNavigationView()
            }
            .navigationDestination(isPresented: $showUIComponent) {
                ComponentsShowcase.CombinedUIComponentsView()
            }
            .navigationDestination(isPresented: $showNestedLazyStacks) {
                NestedLazyStackAutocaptureView()
            }
            .sheet(isPresented: $showModalButtons) {
                ModalButtonsAutocaptureView()
            }
            .fullScreenCover(isPresented: $showClickAnalyticsFullScreen) {
                NavigationStack {
                    ClickAnalyticsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") {
                                    showClickAnalyticsFullScreen = false
                                }
                            }
                        }
                }
            }
            .navigationTitle("Userpilot sample")
            .userpilotScreenName("HomeScreen")
            .onReceive(NotificationCenter.default.publisher(for: UserpilotManager.openScreenOneNotification)) { _ in
                showScreensFlow = true
            }
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits([.isButton])
    }
}

#Preview {
    ContentView()
}
