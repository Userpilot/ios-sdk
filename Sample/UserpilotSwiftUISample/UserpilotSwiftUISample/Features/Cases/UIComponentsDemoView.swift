//
//  UIComponentsDemoView.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 17/03/2026.
//

import SwiftUI

// MARK: - UI Components Demo Class

class UIComponentsDemo {
    struct DemoScreen<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title)
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .padding(.bottom, 24)
            }
        }
    }

    struct DemoSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Toggle Components

    struct ToggleDemoView: View {
        @State private var isOn = false
        @State private var isOn2 = true

        var body: some View {
            DemoScreen(title: "Toggle Components") {
                // ✅ Basic Toggle - Tracked automatically
                DemoSection(title: "Basic Toggle") {
                    Toggle("Enable Feature", isOn: $isOn).accessibilityLabel("Test Label")
                }

                // ✅ Toggle with custom style
                DemoSection(title: "Toggle with Switch Style") {
                    Toggle("Notifications", isOn: $isOn2)
                        .toggleStyle(.switch)
                }

                // ✅ Toggle group without nesting List inside ScrollView
                DemoSection(title: "Toggle Group") {
                    VStack(spacing: 12) {
                        Toggle("Enable Feature", isOn: $isOn)
                        Toggle("Notifications", isOn: $isOn2)
                        Toggle("Airplane Mode", isOn: .constant(false))
                    }
                }
            }
            .navigationTitle("Toggle Demo")
        }
    }

    // MARK: - Segment Control Components

    struct SegmentDemoView: View {
        @State private var selectedSegment = 0
        @State private var selectedColor = "Red"
        @State private var selectedSize = "Medium"

        let segments = ["First", "Second", "Third"]
        let colors = ["Red", "Green", "Blue"]
        let sizes = ["Small", "Medium", "Large"]

        var body: some View {
            DemoScreen(title: "Segment Control Components") {
                // ✅ Basic Picker with SegmentedPickerStyle - Tracked automatically
                DemoSection(title: "Basic Segmented Control") {
                    Picker("Options", selection: $selectedSegment) {
                        ForEach(0..<segments.count, id: \.self) { index in
                            Text(segments[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ✅ Segmented Picker with Strings
                DemoSection(title: "Color Selection") {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(colors, id: \.self) { color in
                            Text(color).tag(color)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ✅ Multiple segmented controls
                DemoSection(title: "Size Selection") {
                    Picker("Size", selection: $selectedSize) {
                        ForEach(sizes, id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text("Selected: \(selectedColor) - \(selectedSize)")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Segment Demo")
        }
    }

    // MARK: - Picker Components

    struct PickerDemoView: View {
        @State private var selectedFruit = "Apple"
        @State private var selectedWheelPicker = "Option 1"
        @State private var selectedMenuPicker = "Choose"

        let fruits = ["Apple", "Banana", "Orange", "Grape", "Pineapple"]
        let wheelOptions = ["Option 1", "Option 2", "Option 3", "Option 4", "Option 5"]
        let menuOptions = ["Choose", "Item A", "Item B", "Item C"]

        var body: some View {
            DemoScreen(title: "Picker Components") {
                // ✅ Menu Picker Style - Tracked automatically
                DemoSection(title: "Menu Picker") {
                    Picker("Select", selection: $selectedMenuPicker) {
                        ForEach(menuOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // ✅ Wheel Picker Style - Tracked automatically
                DemoSection(title: "Wheel Picker") {
                    Picker("Fruits", selection: $selectedFruit) {
                        ForEach(fruits, id: \.self) { fruit in
                            Text(fruit).tag(fruit)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }

                // ✅ Inline Picker Style
                DemoSection(title: "Inline Picker") {
                    Picker("Options", selection: $selectedWheelPicker) {
                        ForEach(wheelOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Text("Selected Fruit: \(selectedFruit)")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Picker Demo")
        }
    }

    // MARK: - Slider Components

    struct SliderDemoView: View {
        @State private var sliderValue = 50.0
        @State private var rangeSliderLowerValue: Double = 0
        @State private var rangeSliderUpperValue: Double = 100
        @State private var stepSliderValue = 5.0

        var body: some View {
            DemoScreen(title: "Slider Components") {
                // ✅ Basic Slider - Tracked automatically via onChange
                DemoSection(title: "Basic Slider: \(Int(sliderValue))") {
                    Slider(value: $sliderValue, in: 0...100)
                }

                // ✅ Slider with range
                DemoSection(title: "Range Slider: \(Int(rangeSliderLowerValue)) - \(Int(rangeSliderUpperValue))") {
                    HStack {
                        Text("Min")
                        Slider(value: $rangeSliderLowerValue, in: 0...rangeSliderUpperValue)
                        Text("\(Int(rangeSliderLowerValue))")
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Max")
                        Slider(value: $rangeSliderUpperValue, in: rangeSliderLowerValue...100)
                        Text("\(Int(rangeSliderUpperValue))")
                            .monospacedDigit()
                    }
                }

                // ✅ Slider with step
                DemoSection(title: "Step Slider: \(Int(stepSliderValue))") {
                    Slider(value: $stepSliderValue, in: 0...10, step: 1)
                }

                // ✅ Slider with custom styling
                DemoSection(title: "Custom Styled Slider") {
                    Slider(value: $sliderValue, in: 0...100) {
                        Text("Volume")
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    .tint(.blue)
                }
            }
            .navigationTitle("Slider Demo")
        }
    }

    // MARK: - Stepper Components

    struct StepperDemoView: View {
        @State private var stepperValue = 0
        @State private var quantity = 1
        @State private var price = 9.99

        var body: some View {
            DemoScreen(title: "Stepper Components") {
                // ✅ Basic Stepper - Tracked automatically
                DemoSection(title: "Basic Stepper: \(stepperValue)") {
                    Stepper("Value: \(stepperValue)", value: $stepperValue, in: 0...10)
                }

                // ✅ Stepper with custom increment
                DemoSection(title: "Quantity: \(quantity)") {
                    Stepper("Quantity", value: $quantity, in: 1...99, step: 1)
                }

                // ✅ Stepper with decimal values
                DemoSection(title: "Price: $\(String(format: "%.2f", price))") {
                    Stepper("Price", value: $price, in: 0...100, step: 0.50)
                }

                // ✅ Stepper in HStack
                DemoSection(title: "Stepper in HStack") {
                    HStack {
                        Text("Items:")
                        Spacer()
                        Stepper("", value: $quantity, in: 0...10)
                        Text("\(quantity)")
                    }
                }
            }
            .navigationTitle("Stepper Demo")
        }
    }

    // MARK: - Progress Components

    struct ProgressDemoView: View {
        @State private var progress = 0.5
        @State private var isAnimating = false

        private let progressSteps: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

        var body: some View {
            DemoScreen(title: "Progress Components") {
                // ✅ Progress View - Linear
                DemoSection(title: "Linear Progress") {
                    ProgressView(value: progress) {
                        Text("Loading...")
                    }
                }

                // ✅ Progress View - Circular
                DemoSection(title: "Circular Progress") {
                    ProgressView("Downloading...")
                        .progressViewStyle(.circular)
                }

                // ✅ Indeterminate Progress View
                DemoSection(title: "Indeterminate Progress") {
                    if isAnimating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Tap to start animation")
                            .foregroundColor(.secondary)
                    }
                }

                // ✅ Custom Progress with controls
                DemoSection(title: "Custom Progress: \(Int(progress * 100))%") {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                        ForEach(progressSteps, id: \.self) { step in
                            Button("\(Int(step * 100))%") {
                                progress = step
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Button(isAnimating ? "Stop Animation" : "Start Animation") {
                        isAnimating.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Progress Demo")
        }
    }

    // MARK: - Combined Demo View

    struct CombinedUIComponentsView: View {
        var body: some View {
            TabView {
                ToggleDemoView()
                    .tabItem {
                        Label("Toggles", systemImage: "switch.2")
                    }

                SegmentDemoView()
                    .tabItem {
                        Label("Segments", systemImage: "rectangle.split.3x1")
                    }

                PickerDemoView()
                    .tabItem {
                        Label("Pickers", systemImage: "list.bullet")
                    }

                SliderDemoView()
                    .tabItem {
                        Label("Sliders", systemImage: "slider.horizontal.3")
                    }

                StepperDemoView()
                    .tabItem {
                        Label("Steppers", systemImage: "plusminus")
                    }

                ProgressDemoView()
                    .tabItem {
                        Label("Progress", systemImage: "progress.indicator")
                    }
            }
            .navigationTitle("UI Components Demo")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UIComponentsDemo.CombinedUIComponentsView()
    }
}

