//
//  ContentViewTabDemo2.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 13/01/2026.
//
//  This demo shows how TabBar titles are automatically tracked

import SwiftUI
import Userpilot

struct ContentViewTabDemo2: View {
    var body: some View {
        TabView {
            // Tab 1: Home
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            // Tab 2: Search
            SearchTabView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            // Tab 3: Profile
            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            
            // Tab 4: Settings
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

// MARK: - Tab Views

struct HomeTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Home Tab")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("When you navigate to this tab, the SDK captures:")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                TrackingInfoCard(
                    title: "TabBar Title Captured",
                    items: [
                        "tab_bar_title: 'Home'",
                        "screen_name: 'Home'",
                        "Extracted from: .tabItem Label"
                    ]
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

struct SearchTabView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Search Tab")
                    .font(.title)
                    .fontWeight(.bold)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                TrackingInfoCard(
                    title: "TabBar Title Captured",
                    items: [
                        "tab_bar_title: 'Search'",
                        "navigation_title: 'Search'",
                        "screen_name: 'Search'"
                    ]
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Search")
        }
    }
}

struct ProfileTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)
                    
                    Text("Profile Tab")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("John Doe")
                        .font(.title2)
                    
                    Text("john.doe@example.com")
                        .foregroundColor(.secondary)
                    
                    TrackingInfoCard(
                        title: "TabBar Title Captured",
                        items: [
                            "tab_bar_title: 'Profile'",
                            "navigation_title: 'Profile'",
                            "screen_name: 'Profile'"
                        ]
                    )
                    
                    GroupBox("How It Works") {
                        VStack(alignment: .leading, spacing: 12) {
                            ExplanationStep(
                                number: "1",
                                text: "User taps 'Profile' tab"
                            )
                            
                            ExplanationStep(
                                number: "2",
                                text: "SwiftUI creates UITabBarController"
                            )
                            
                            ExplanationStep(
                                number: "3",
                                text: "viewDidAppear() is swizzled"
                            )
                            
                            ExplanationStep(
                                number: "4",
                                text: "extractTabBarTitle() extracts 'Profile'"
                            )
                            
                            ExplanationStep(
                                number: "5",
                                text: "Screen event sent with tab_bar_title"
                            )
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
}

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink("Edit Profile", destination: EditProfileView())
                    NavigationLink("Change Password", destination: ChangePasswordView())
                }
                
                Section("Preferences") {
                    NavigationLink("Notifications", destination: NotificationsView())
                    NavigationLink("Privacy", destination: PrivacyView())
                }
                
                Section("About") {
                    NavigationLink("Help", destination: HelpView())
                    NavigationLink("Terms of Service", destination: TermsView())
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Settings Sub-Views

struct EditProfileView: View {
    var body: some View {
        VStack {
            Text("Edit Profile")
                .font(.title)
            
            TrackingInfoCard(
                title: "Tracking This Screen",
                items: [
                    "tab_bar_title: 'Settings' (from parent)",
                    "navigation_title: 'Edit Profile'",
                    "screen_name: 'Edit Profile'"
                ]
            )
            .padding()
            
            Text("Notice: Still captures parent TabBar title!")
                .font(.caption)
                .foregroundColor(.orange)
                .padding()
            
            Spacer()
        }
        .navigationTitle("Edit Profile")
    }
}

struct ChangePasswordView: View {
    var body: some View {
        VStack {
            Text("Change Password")
                .font(.title)
            Spacer()
        }
        .navigationTitle("Change Password")
    }
}

struct NotificationsView: View {
    var body: some View {
        VStack {
            Text("Notifications")
                .font(.title)
            Spacer()
        }
        .navigationTitle("Notifications")
    }
}

struct PrivacyView: View {
    var body: some View {
        VStack {
            Text("Privacy")
                .font(.title)
            Spacer()
        }
        .navigationTitle("Privacy")
    }
}

struct HelpView: View {
    var body: some View {
        VStack {
            Text("Help")
                .font(.title)
            Spacer()
        }
        .navigationTitle("Help")
    }
}

struct TermsView: View {
    var body: some View {
        VStack {
            Text("Terms of Service")
                .font(.title)
            Spacer()
        }
        .navigationTitle("Terms of Service")
    }
}

// MARK: - Supporting Views

struct TrackingInfoCard: View {
    let title: String
    let items: [String]
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                }
                
                Divider()
                
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(item)
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                }
            }
        }
    }
}

struct ExplanationStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentViewTabDemo2()
}
