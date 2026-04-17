//
//  ContentViewClickAnalyticsDemo1.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 13/01/2026.
//
//  This file demonstrates click analytics labels with userpilotLabel(_:)

import SwiftUI
import Userpilot

struct ContentViewClickAnalyticsDemo1: View {
    @State private var favoriteCount = 0
    @State private var likeCount = 0
    @State private var selectedCard: String?
    @State private var showAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Click Analytics Examples")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                GroupBox("Start Here: Button Examples") {
                    VStack(spacing: 12) {
                        Button("Confirm Order") {
                            print("Confirm order tapped")
                        }
                        .buttonStyle(.borderedProminent)
                        .userpilotLabel("Confirm Order")
                        
                        Button(action: {
                            print("Standard button tapped")
                        }) {
                            Text("Standard Button")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .userpilotLabel("Standard Button")
                        
                        NavigationLink(destination: Text("Detail View")) {
                            Text("Navigation Link")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .userpilotLabel("Navigation Link")
                    }
                }
                .padding(.horizontal)

                // MARK: - Example 1: VStack with onTapGesture
                GroupBox("Example 1: VStack with Tap Gesture") {
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                        
                        Text("Favorite")
                            .font(.headline)
                        
                        Text("Tapped \(favoriteCount) times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .onTapGesture {
                        favoriteCount += 1
                    }
                    .userpilotLabel("Favorite Tile")
                }
                .padding(.horizontal)
                
                // MARK: - Example 2: HStack Container Button
                GroupBox("Example 2: HStack Container Tap Area") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        
                        Text("Like")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(likeCount)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.pink.opacity(0.1))
                    .cornerRadius(10)
                    .onTapGesture {
                        likeCount += 1
                    }
                    .userpilotLabel("Like Row")
                }
                .padding(.horizontal)
                
                // MARK: - Example 3: ZStack Custom Card
                GroupBox("Example 3: ZStack Custom Cards") {
                    HStack(spacing: 15) {
                        ForEach(["Swift", "SwiftUI", "UIKit"], id: \.self) { tech in
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        selectedCard == tech
                                            ? Color.purple
                                            : Color.purple.opacity(0.3)
                                    )
                                    .shadow(radius: 5)
                                
                                Text(tech)
                                    .font(.headline)
                                    .foregroundColor(
                                        selectedCard == tech
                                            ? .white
                                            : .primary
                                    )
                            }
                            .frame(height: 80)
                            .onTapGesture {
                                selectedCard = tech
                            }
                            .userpilotLabel("Tech Card \(tech)")
                        }
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 4: LazyVStack List Items
                GroupBox("Example 4: List Items with Gestures") {
                    LazyVStack(spacing: 10) {
                        ForEach(1...3, id: \.self) { index in
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text("Item \(index)")
                                        .font(.headline)
                                    Text("Tap to view details")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .onTapGesture {
                                print("Tapped item \(index)")
                                showAlert = true
                            }
                            .userpilotLabel("List Item \(index)")
                        }
                    }
                }
                .padding(.horizontal)
                
                // MARK: - Example 5: Custom Component
                GroupBox("Example 5: Custom Reusable Component") {
                    VStack(spacing: 15) {
                        CustomActionCard(
                            icon: "camera.fill",
                            title: "Take Photo",
                            color: .blue
                        ) {
                            print("Take photo tapped")
                        }
                        
                        CustomActionCard(
                            icon: "photo.fill",
                            title: "Choose from Library",
                            color: .green
                        ) {
                            print("Library tapped")
                        }
                    }
                }
                .padding(.horizontal)
                .userpilotLabel("Example 5: Custom Reusable Component")
                
                // MARK: - Comparison Section
                GroupBox("Comparison: With vs Without Label") {
                    HStack(spacing: 15) {
                        VStack {
                            Text("Without Label")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text("Not Tracked")
                                    .font(.caption2)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .onTapGesture {
                                print("This might not be tracked")
                            }
                            // No Userpilot label
                        }
                        
                        VStack {
                            Text("With Label")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text("Tracked ✓")
                                    .font(.caption2)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .onTapGesture {
                                print("This will be tracked")
                            }
                            .userpilotLabel("Tracked Comparison Tile")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Click Analytics")
        .alert("Item Tapped", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

// MARK: - Custom Reusable Component Example

/// Custom component that uses userpilotLabel(_:)
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
        .onTapGesture(perform: action)
        .userpilotLabel(title)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ContentViewClickAnalyticsDemo1()
    }
}
