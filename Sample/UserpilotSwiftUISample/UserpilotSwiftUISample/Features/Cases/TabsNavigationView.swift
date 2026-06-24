//
//  TabsNavigationView.swift
//  UserpilotSwiftUISample
//
//  Tabs & navigation flow. Validates that the SDK captures:
//    - tab-bar selection (tab title) when switching tabs,
//    - screen transitions across NavigationStack pushes,
//    - button / NavigationLink / list-row taps inside tabs,
//    - sheets, alerts and confirmation dialogs.
//
//  (Merged from the former tab samples into a single screen.)
//

import SwiftUI
import Userpilot

struct TabsNavigationView: View {
    var body: some View {
        TabView {
            TabHomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            TabBrowseView()
                .tabItem { Label("Browse", systemImage: "list.bullet") }

            TabSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

// MARK: - Home tab (buttons, sheet, alert, confirmation)

private struct TabHomeView: View {
    @State private var showSheet = false
    @State private var showAlert = false
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Switch tabs and push screens — each transition is captured automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top)

                    Button("Show Sheet") { showSheet = true }
                        .buttonStyle(.borderedProminent)

                    NavigationLink("Go to Detail") { TabDetailView() }
                        .buttonStyle(.bordered)

                    Button("Show Alert") { showAlert = true }
                        .buttonStyle(.bordered)

                    Button("Show Confirmation") { showConfirmation = true }
                        .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Home")
            .sheet(isPresented: $showSheet) { TabSheetView(isPresented: $showSheet) }
            .alert("Alert Title", isPresented: $showAlert) {
                Button("OK") { }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Choose Option", isPresented: $showConfirmation) {
                Button("Option 1") { }
                Button("Option 2") { }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

private struct TabDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Detail Screen").font(.title)
            NavigationLink("Go Deeper") {
                Text("Third Level").navigationTitle("Third Level")
            }
            .buttonStyle(.bordered)
        }
        .navigationTitle("Detail")
    }
}

private struct TabSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Sheet Content").font(.title)
                Button("Dismiss") { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - Browse tab (list with buttons + navigation links)

private struct TabBrowseView: View {
    private let items = (1...8).map { "Item \($0)" }

    var body: some View {
        NavigationStack {
            List {
                Section("Buttons") {
                    ForEach(items.prefix(4), id: \.self) { name in
                        Button {
                            // captured: target_text == name
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                Image(systemName: "cart")
                            }
                        }
                    }
                }

                Section("Navigation links") {
                    ForEach(items.suffix(4), id: \.self) { name in
                        NavigationLink(name) {
                            Text(name).font(.largeTitle).navigationTitle(name)
                        }
                    }
                }
            }
            .navigationTitle("Browse")
        }
    }
}

// MARK: - Settings tab (nested navigation)

private struct TabSettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink("Edit Profile") { settingsDetail("Edit Profile") }
                    NavigationLink("Change Password") { settingsDetail("Change Password") }
                }
                Section("Preferences") {
                    NavigationLink("Notifications") { settingsDetail("Notifications") }
                    NavigationLink("Privacy") { settingsDetail("Privacy") }
                }
                Section("About") {
                    NavigationLink("Help") { settingsDetail("Help") }
                    NavigationLink("Terms of Service") { settingsDetail("Terms of Service") }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func settingsDetail(_ title: String) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.title)
            Text("Each push is captured as a screen transition; the tab title rides along.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle(title)
    }
}

// MARK: - Preview

#Preview {
    TabsNavigationView()
}
