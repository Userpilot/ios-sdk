//
//  RedactAndIgnoreTestView.swift
//  UserpilotSwiftUISample
//
//  Created by Userpilot on 15/03/2026.
//
//  This file demonstrates the userpilotRedactText() and userpilotIgnoreInteractions() APIs
//

import SwiftUI
import Userpilot

struct RedactAndIgnoreTestView: View {
    @State private var password = ""
    @State private var balance = "$12,345.67"
    @State private var accountNumber = "****-1234"
    @State private var debugMode = false
    @State private var showAlert = false
    @State private var tapCount = 0
    @State private var selectedTransaction: String?
    
    // Sample data
    let transactions = [
        "$150.00",
        "$2,500.00",
        "$89.99",
        "$1,200.00"
    ]
    
    let adminActions = [
        "Clear Cache",
        "Reset Settings",
        "Export Logs",
        "Delete All Data"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Redact & Ignore Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // MARK: - Example 1: Redact Text in Sensitive Data
                GroupBox("Example 1: Redact Sensitive Text") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("These values will be redacted (****) in analytics:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Balance display with redaction
                        HStack {
                            Text("Balance:")
                                .font(.headline)
                            Spacer()
                            Text(balance)
                                .font(.headline)
                                .foregroundStyle(.green)
                                .userpilotRedactText(true)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Account number with redaction
                        HStack {
                            Text("Account:")
                                .font(.headline)
                            Spacer()
                            Text(accountNumber)
                                .font(.headline)
                                .foregroundStyle(.blue)
                                .userpilotRedactText(true)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Password field
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .userpilotRedactText(true)
                        
                        Text("☝️ All text above is redacted in captured events")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 2: Redact Transaction List
                GroupBox("Example 2: Redact Items in List") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Transaction values will be redacted:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        List(transactions, id: \.self) { transaction in
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.red)
                                
                                Text(transaction)
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                    .userpilotRedactText(true)
                                
                                Spacer()
                                
                                if selectedTransaction == transaction {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                        }
                        .frame(height: 200)
                        .listStyle(.plain)
                        
                        Text("☝️ Transaction amounts are redacted but interactions are tracked")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 3: Ignore Interactions - Debug Button
                GroupBox("Example 3: Ignore Button Interactions") {
                    VStack(spacing: 15) {
                        Text("This button won't be tracked:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            tapCount += 1
                            showAlert = true
                        }) {
                            HStack {
                                Image(systemName: "ladybug.fill")
                                Text("Debug Button (Tapped \(tapCount) times)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .userpilotIgnoreInteractions(true)
                        
                        Text("☝️ No interaction events captured for this button")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 4: Ignore Entire Section
                GroupBox("Example 4: Ignore Admin Controls Section") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("All interactions in this section are ignored:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 10) {
                            Toggle("Debug Mode", isOn: $debugMode)
                            
                            ForEach(adminActions, id: \.self) { action in
                                Button(action: {
                                    print("\(action) tapped")
                                }) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(action)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .userpilotIgnoreInteractions(true)
                        
                        Text("☝️ No interactions tracked in admin section")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 5: Combined - Redact + Ignore
                GroupBox("Example 5: Combined Redaction + Ignore") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("This section has both redacted text AND ignored interactions:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Secret Code:")
                                    .font(.headline)
                                Spacer()
                                Text("ABC-123-XYZ")
                                    .font(.headline)
                                    .foregroundStyle(.purple)
                                    .userpilotRedactText(true)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button(action: {
                                print("Secret action")
                            }) {
                                Text("Execute Secret Action")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .userpilotIgnoreInteractions(true)
                        
                        Text("☝️ Text is redacted AND interactions are not tracked")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 6: Comparison - Normal vs Redacted
                GroupBox("Example 6: Comparison") {
                    HStack(spacing: 15) {
                        // Normal tracking
                        VStack {
                            Text("Normal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "eye")
                                    .font(.title)
                                    .foregroundColor(.green)
                                
                                Text("$999.99")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                
                                Text("Tracked ✓")
                                    .font(.caption2)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Redacted tracking
                        VStack {
                            Text("Redacted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "eye.slash")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                
                                Text("$999.99")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .userpilotRedactText(true)
                                
                                Text("Shows ****")
                                    .font(.caption2)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Ignored interactions
                        VStack {
                            Text("Ignored")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "hand.raised.slash")
                                    .font(.title)
                                    .foregroundColor(.red)
                                
                                Button(action: {}) {
                                    Text("Click Me")
                                        .font(.caption)
                                }
                                .userpilotIgnoreInteractions(true)
                                
                                Text("Not tracked")
                                    .font(.caption2)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 7: Redact in List with Ignore
                GroupBox("Example 7: List with Mixed Behavior") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Some items redacted, some ignored:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        List {
                            Section("Sensitive Data (Redacted)") {
                                HStack {
                                    Text("SSN:")
                                    Spacer()
                                    Text("***-**-1234")
                                        .userpilotRedactText(true)
                                }
                                
                                HStack {
                                    Text("Card:")
                                    Spacer()
                                    Text("**** **** **** 5678")
                                        .userpilotRedactText(true)
                                }
                            }
                            
                            Section("Debug Tools (Ignored)") {
                                Button("Clear Cache") {}
                                    .userpilotIgnoreInteractions(true)
                                
                                Button("Export Data") {}
                                    .userpilotIgnoreInteractions(true)
                            }
                            
                            Section("Normal Tracking") {
                                Button("Send Feedback") {}
                                Button("Rate App") {}
                            }
                        }
                        .frame(height: 400)
                        .listStyle(.insetGrouped)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Redact & Ignore")
        .alert("Debug Action", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This alert was triggered by an ignored button!")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RedactAndIgnoreTestView()
    }
}
