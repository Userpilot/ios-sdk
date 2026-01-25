//
//  ContentViewClickAnalyticsDemo2.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 13/01/2026.
//
//  This demo shows EXACTLY how click capture works with and without the API

import SwiftUI
import UIKit
import Userpilot

struct ContentViewClickAnalyticsDemo2: View {
    @State private var capturedClicks: [String] = []
    
    var body: some View {
        let _ = Self._printChanges()
        ScrollView {
            VStack(spacing: 30) {
                Text("Click Capture Flow Demo")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Visual explanation
                ExplanationCard()
                
                // Test scenarios
                GroupBox("Scenario 1: Standard Button") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This button is automatically tracked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                           
                        
                        Button(action: {}) {
                            Text("Standard Button")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        FlowDiagram(steps: [
                            "1. User taps button",
                            "2. UIWindow.sendEvent() intercepts",
                            "3. shouldTrackClick() checks",
                            "4. Is UIControl? ✅ YES",
                            "5. ✅ TRACKED automatically"
                        ])
                        
                    }
                }
                .padding(.horizontal)
//                .accessibilityElement(children: .combine)
//                .accessibilityAddTraits([.isButton])
//                .accessibilityIdentifier("TEST TWO")
                
                GroupBox("Scenario 2: VStack WITHOUT API") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This will NOT be tracked")
                            .font(.caption)
                            .foregroundColor(.red)
                            .accessibilityIdentifier("TEST TWO")
                        
                        VStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Won't Track")
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .onTapGesture {
                            print("Tapped but NOT tracked!")
                        }
                        // ❌ NOT using .userpilotRecognizeClickAnalytics()
                        
                        FlowDiagram(steps: [
                            "1. User taps VStack",
                            "2. UIWindow.sendEvent() intercepts",
                            "3. shouldTrackClick() checks",
                            "4. Is UIControl? ❌ NO",
                            "5. Has .button trait? ❌ NO",
                            "6. ❌ IGNORED - not tracked"
                        ])
                        .accessibilityIdentifier("TEST TWO")
                    }
                }
                .padding(.horizontal)
                .accessibilityIdentifier("TEST TWO")
                
                GroupBox("Scenario 3: VStack WITH API") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This WILL be tracked")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Will Track")
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .onTapGesture {
                            print("Tapped AND tracked!")
                        }
                        
                        FlowDiagram(steps: [
                            "1. User taps VStack",
                            "2. UIWindow.sendEvent() intercepts",
                            "3. shouldTrackClick() checks",
                            "4. Is UIControl? ❌ NO",
                            "5. Has .button trait? ✅ YES",
                            "   (API added this trait!)",
                            "6. ✅ TRACKED successfully"
                        ])
                    }
                }
                .padding(.horizontal)
                
                // Code comparison
                GroupBox("Code Comparison") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Without API (not tracked):")
                            .font(.headline)
                        
                        CodeBlock(code: """
                        VStack {
                            Image(systemName: "star")
                            Text("Favorite")
                        }
                        .onTapGesture { }
                        // ❌ No API call
                        """)
                        
                        Divider()
                        
                        Text("With API (tracked):")
                            .font(.headline)
                        
                        CodeBlock(code: """
                        VStack {
                            Image(systemName: "star")
                            Text("Favorite")
                        }
                        .onTapGesture { }
                        .userpilotRecognizeClickAnalytics()
                        // ✅ API adds .button trait
                        """)
                    }
                }
                .padding(.horizontal)
                
                // What happens under the hood
                GroupBox("What Happens Under the Hood") {
                    VStack(alignment: .leading, spacing: 10) {
                        UnderTheHoodStep(
                            number: "1",
                            title: "API Call",
                            description: ".userpilotRecognizeClickAnalytics()",
                            result: "Adds .button accessibility trait"
                        )
                        
                        UnderTheHoodStep(
                            number: "2",
                            title: "User Taps",
                            description: "Touch event fires",
                            result: "UIWindow.sendEvent() intercepts"
                        )
                        
                        UnderTheHoodStep(
                            number: "3",
                            title: "Filtering",
                            description: "shouldTrackClick(view)",
                            result: "Checks .button trait → found!"
                        )
                        
                        UnderTheHoodStep(
                            number: "4",
                            title: "Metadata Extraction",
                            description: "ScreenNameResolver, ViewTextResolver",
                            result: "Collects screen, text, path, etc."
                        )
                        
                        UnderTheHoodStep(
                            number: "5",
                            title: "Event Sent",
                            description: "NotificationCenter.post()",
                            result: "Analytics receives click event"
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("How It Works2222")
    }
}

// MARK: - Supporting Views

struct ExplanationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("How Click Capture Works")
                    .font(.headline)
            }
            
            Text("The SDK intercepts ALL touches via UIWindow.sendEvent(), but only tracks clicks on 'interesting' views:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 5) {
                CheckItem(text: "UIControl subclasses (buttons, switches)")
                CheckItem(text: "Views with .button accessibility trait")
                CheckItem(text: "Views marked with userpilotRecognizeClickAnalytics()")
                CheckItem(text: "Views with tap gesture recognizers")
            }
            .padding(.leading)
            
            Text("Everything else is IGNORED to avoid noise.")
                .font(.caption)
                .foregroundColor(.orange)
                .italic()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct CheckItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
}

struct FlowDiagram: View {
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    if index < steps.count - 1 {
                        Text("↓")
                            .foregroundColor(.blue)
                            .font(.caption)
                    } else {
                        Image(systemName: step.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(step.contains("✅") ? .green : .red)
                            .font(.caption)
                    }
                    
                    Text(step)
                        .font(.caption2)
                        .foregroundColor(step.contains("✅") ? .green : step.contains("❌") ? .red : .primary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits([.isButton])
        .accessibilityIdentifier("AADSDSDSDSD")
        .onTapGesture {
            print("AAAArtrtrtrt")
        }
    }
}

struct CodeBlock: View {
    let code: String
    
    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

struct UnderTheHoodStep: View {
    let number: String
    let title: String
    let description: String
    let result: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number circle
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("→ \(result)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .italic()
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ContentViewClickAnalyticsDemo2()
    }
}
