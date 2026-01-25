//
//  ContentViewTabDemo1.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 13/01/2026.
//

import SwiftUI

// MARK: - App Entry Point


// MARK: - Example Views (NO TRACKING CODE NEEDED)

struct ContentViewTabDemo1: View {
    var body: some View {
        TabView {
            // ✅ TabView changes tracked automatically
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            ListExampleView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
            
            NavigationExampleView()
                .tabItem {
                    Label("Nav", systemImage: "map")
                }
        }
    }
}

// MARK: - Home View with NavigationStack

struct HomeView: View {
    @State private var showSheet = false
    @State private var showAlert = false
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationStack {
            // ✅ NavigationStack changes tracked automatically
            ScrollView {
                VStack(spacing: 20) {
                    Text("Home View")
                        .font(.largeTitle)
                    
                    // ✅ Button clicks tracked automatically
                    Button("Show Sheet") {
                        showSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // ✅ NavigationLink tracked automatically
                    NavigationLink("Go to Detail") {
                        DetailView()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Show Alert") {
                        showAlert = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Show Confirmation") {
                        showConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Home")
            // ✅ Sheet presentation tracked automatically
            .sheet(isPresented: $showSheet) {
                SheetView(isPresented: $showSheet)
            }
            // ✅ Alert tracked automatically
            .alert("Alert Title", isPresented: $showAlert) {
                Button("OK") { }
                Button("Cancel", role: .cancel) { }
            }
            // ✅ Confirmation dialog tracked automatically
            .confirmationDialog("Choose Option", isPresented: $showConfirmation) {
                Button("Option 1") { }
                Button("Option 2") { }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

// MARK: - Detail View (NavigationStack)

struct DetailView: View {
    @State private var showPopover = false
    
    var body: some View {
        VStack {
            Text("Detail View")
                .font(.title)
            
            // ✅ Popover tracked automatically
            Button("Show Popover") {
                showPopover = true
            }
            .popover(isPresented: $showPopover) {
                PopoverView()
            }
        }
        .navigationTitle("Detail")
    }
}

// MARK: - Sheet View

struct SheetView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Sheet Content")
                    .font(.title)
                
                Button("Dismiss") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Popover View

struct PopoverView: View {
    var body: some View {
        VStack {
            Text("Popover Content")
                .padding()
        }
        .frame(width: 200, height: 150)
    }
}

// MARK: - List Example View

struct ListExampleView: View {
    @State private var items = (1...20).map { Item(id: $0, name: "Item \($0)") }
    @State private var selection: Int?
    
    var body: some View {
        NavigationView {
            List {
                // SCENARIO 1: ✅ List with Button - Tracked automatically
                Section("With Buttons") {
                    ForEach(items.prefix(5)) { item in
                        Button(action: {
                            print("Button tapped: \(item.name)")
                        }) {
                            HStack {
                                Text(item.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                }
                
                // SCENARIO 2: ✅ List with NavigationLink - Tracked automatically
                Section("With NavigationLink") {
                    ForEach(items[5..<10]) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            Text(item.name)
                        }
                    }
                }
                
                // SCENARIO 3: ✅ List with selection - Tracked automatically via onChange
                Section("With Selection") {
                    ForEach(items[10..<15]) { item in
                        Text(item.name)
                            .tag(item.id)
                    }
                }
                
                // SCENARIO 4: ⚠️ List with .onTapGesture - Needs helper
                Section("With onTapGesture (Manual)") {
                    ForEach(items.suffix(5)) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Image(systemName: "hand.tap")
                        }
                        .onTapGesture {
                            print("Tap gesture: \(item.name)")
                        }
                    }
                }
            }
            .navigationTitle("List Examples")
            // ✅ onChange tracked automatically
            .onChange(of: selection) { oldValue, newValue in
                if let newValue = newValue {
                    print("Selection changed to: \(newValue)")
                }
            }
        }
    }
}

struct ItemDetailView: View {
    let item: Item
    
    var body: some View {
        VStack {
            Text(item.name)
                .font(.largeTitle)
            Text("Item Details")
                .foregroundColor(.gray)
        }
        .navigationTitle(item.name)
    }
}

// MARK: - Navigation Example View (NavigationView)

struct NavigationExampleView: View {
    var body: some View {
        // ✅ NavigationView (legacy) also tracked
        NavigationView {
            List {
                NavigationLink("First Level") {
                    SecondLevelView()
                }
                
                NavigationLink("Another Path") {
                    AnotherPathView()
                }
            }
            .navigationTitle("Navigation")
        }
    }
}

struct SecondLevelView: View {
    var body: some View {
        List {
            NavigationLink("Third Level") {
                ThirdLevelView()
            }
        }
        .navigationTitle("Second Level")
    }
}

struct ThirdLevelView: View {
    var body: some View {
        Text("Third Level Content")
            .navigationTitle("Third Level")
    }
}

struct AnotherPathView: View {
    var body: some View {
        Text("Another Path Content")
            .navigationTitle("Another Path")
    }
}

// MARK: - NavigationSplitView Example (iPad/Mac)

struct SplitViewExample: View {
    @State private var selectedItem: String?
    
    var body: some View {
        // ✅ NavigationSplitView tracked automatically
        NavigationSplitView {
            List(["Item 1", "Item 2", "Item 3"], id: \.self, selection: $selectedItem) { item in
                Text(item)
            }
            .navigationTitle("Sidebar")
        } detail: {
            if let selectedItem = selectedItem {
                Text("Detail for \(selectedItem)")
            } else {
                Text("Select an item")
            }
        }
    }
}

// MARK: - ActionSheet Example (Deprecated but still used)

struct ActionSheetExample: View {
    @State private var showActionSheet = false
    
    var body: some View {
        Button("Show Action Sheet") {
            showActionSheet = true
        }
        // ✅ ActionSheet tracked automatically
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Choose Action"),
                buttons: [
                    .default(Text("Action 1")),
                    .default(Text("Action 2")),
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Complex List with Custom Views

struct ComplexListView: View {
    @State private var products = Product.samples
    
    var body: some View {
        List(products) { product in
            ProductRow(product: product)
                // ✅ For complex custom views with gestures, use this modifier
                .onTapGesture {
                    handleProductTap(product)
                }
        }
    }
    
    private func handleProductTap(_ product: Product) {
        print("Product tapped: \(product.name)")
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack {
            Image(systemName: product.icon)
                .font(.largeTitle)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(product.name)
                    .font(.headline)
                Text(product.price)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Optional: Manual Page ID (for better tracking)

struct ManualPageIdExample: View {
    var body: some View {
        Text("Custom Page")
    }
}

// MARK: - Supporting Models

struct Item: Identifiable {
    let id: Int
    let name: String
}

struct Product: Identifiable {
    let id: UUID = UUID()
    let name: String
    let price: String
    let icon: String
    
    static let samples = [
        Product(name: "iPhone", price: "$999", icon: "iphone"),
        Product(name: "iPad", price: "$599", icon: "ipad"),
        Product(name: "MacBook", price: "$1299", icon: "laptopcomputer"),
        Product(name: "AirPods", price: "$199", icon: "airpodspro"),
        Product(name: "Watch", price: "$399", icon: "applewatch")
    ]
}

// MARK: - Full App Example with All Navigation Types

struct FullExampleApp: View {
    var body: some View {
        TabView {
            // Tab 1: NavigationStack
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            
            // Tab 2: List Examples
            ListExampleView()
                .tabItem { Label("Lists", systemImage: "list.bullet") }
            
            // Tab 3: Split View (iPad)
            SplitViewExample()
                .tabItem { Label("Split", systemImage: "sidebar.left") }
        }
    }
}
