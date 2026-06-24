//
//  UIComponentsView.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 17/03/2026.
//

import SwiftUI

// MARK: - UI Components Class

class ComponentsShowcase {
    struct ComponentScreen<Content: View>: View {
        let title: String
        /// One-line note on the UIKit control these SwiftUI views wrap. These
        /// are captured by the SDK's existing UIKit autocapture path — not the
        /// SwiftUI title resolver.
        var subtitle: String?
        @ViewBuilder let content: Content

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2.weight(.bold))
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .padding(.bottom, 24)
            }
        }
    }

    struct ComponentSection<Content: View>: View {
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

    struct ToggleComponentsView: View {
        @State private var isOn = false
        @State private var isOn2 = true

        var body: some View {
            ComponentScreen(title: "Toggle Components",
                       subtitle: "SwiftUI Toggle → UISwitch under the hood. Captured by the SDK's UIKit path.") {
                // ✅ Basic Toggle - Tracked automatically
                ComponentSection(title: "Basic Toggle") {
                    Toggle("Enable Feature", isOn: $isOn).accessibilityLabel("Test Label")
                }

                // ✅ Toggle with custom style
                ComponentSection(title: "Toggle with Switch Style") {
                    Toggle("Notifications", isOn: $isOn2)
                        .toggleStyle(.switch)
                }

                // ✅ Toggle group without nesting List inside ScrollView
                ComponentSection(title: "Toggle Group") {
                    VStack(spacing: 12) {
                        Toggle("Enable Feature", isOn: $isOn)
                        Toggle("Notifications", isOn: $isOn2)
                        Toggle("Airplane Mode", isOn: .constant(false))
                    }
                }
            }        }
    }

    // MARK: - Segment Control Components

    struct SegmentComponentsView: View {
        @State private var selectedSegment = 0
        @State private var selectedColor = "Red"
        @State private var selectedSize = "Medium"

        let segments = ["First", "Second", "Third"]
        let colors = ["Red", "Green", "Blue"]
        let sizes = ["Small", "Medium", "Large"]

        var body: some View {
            ComponentScreen(title: "Segment Control Components",
                       subtitle: "SwiftUI Picker(.segmented) → UISegmentedControl. Captured by the SDK's UIKit path.") {
                // ✅ Basic Picker with SegmentedPickerStyle - Tracked automatically
                ComponentSection(title: "Basic Segmented Control") {
                    Picker("Options", selection: $selectedSegment) {
                        ForEach(0..<segments.count, id: \.self) { index in
                            Text(segments[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ✅ Segmented Picker with Strings
                ComponentSection(title: "Color Selection") {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(colors, id: \.self) { color in
                            Text(color).tag(color)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ✅ Multiple segmented controls
                ComponentSection(title: "Size Selection") {
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
            }        }
    }

    // MARK: - Picker Components

    struct PickerComponentsView: View {
        @State private var selectedFruit = "Apple"
        @State private var selectedWheelPicker = "Option 1"
        @State private var selectedMenuPicker = "Choose"

        let fruits = ["Apple", "Banana", "Orange", "Grape", "Pineapple"]
        let wheelOptions = ["Option 1", "Option 2", "Option 3", "Option 4", "Option 5"]
        let menuOptions = ["Choose", "Item A", "Item B", "Item C"]

        var body: some View {
            ComponentScreen(title: "Picker Components",
                       subtitle: "SwiftUI Picker → UIPickerView / menu. Captured by the SDK's UIKit path.") {
                // ✅ Menu Picker Style - Tracked automatically
                ComponentSection(title: "Menu Picker") {
                    Picker("Select", selection: $selectedMenuPicker) {
                        ForEach(menuOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // ✅ Wheel Picker Style - Tracked automatically
                ComponentSection(title: "Wheel Picker") {
                    Picker("Fruits", selection: $selectedFruit) {
                        ForEach(fruits, id: \.self) { fruit in
                            Text(fruit).tag(fruit)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }

                // ✅ Inline Picker Style
                ComponentSection(title: "Inline Picker") {
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
            }        }
    }

    // MARK: - Slider Components

    struct SliderComponentsView: View {
        @State private var sliderValue = 50.0
        @State private var rangeSliderLowerValue: Double = 0
        @State private var rangeSliderUpperValue: Double = 100
        @State private var stepSliderValue = 5.0

        var body: some View {
            ComponentScreen(title: "Slider Components",
                       subtitle: "SwiftUI Slider → UISlider. Captured by the SDK's UIKit path.") {
                // ✅ Basic Slider - Tracked automatically via onChange
                ComponentSection(title: "Basic Slider: \(Int(sliderValue))") {
                    Slider(value: $sliderValue, in: 0...100)
                }

                // ✅ Slider with range
                ComponentSection(title: "Range Slider: \(Int(rangeSliderLowerValue)) - \(Int(rangeSliderUpperValue))") {
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
                ComponentSection(title: "Step Slider: \(Int(stepSliderValue))") {
                    Slider(value: $stepSliderValue, in: 0...10, step: 1)
                }

                // ✅ Slider with custom styling
                ComponentSection(title: "Custom Styled Slider") {
                    Slider(value: $sliderValue, in: 0...100) {
                        Text("Volume")
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    .tint(.blue)
                }
            }        }
    }

    // MARK: - Stepper Components

    struct StepperComponentsView: View {
        @State private var stepperValue = 0
        @State private var quantity = 1
        @State private var price = 9.99

        var body: some View {
            ComponentScreen(title: "Stepper Components",
                       subtitle: "SwiftUI Stepper → UIStepper. Captured by the SDK's UIKit path.") {
                // ✅ Basic Stepper - Tracked automatically
                ComponentSection(title: "Basic Stepper: \(stepperValue)") {
                    Stepper("Value: \(stepperValue)", value: $stepperValue, in: 0...10)
                }

                // ✅ Stepper with custom increment
                ComponentSection(title: "Quantity: \(quantity)") {
                    Stepper("Quantity", value: $quantity, in: 1...99, step: 1)
                }

                // ✅ Stepper with decimal values
                ComponentSection(title: "Price: $\(String(format: "%.2f", price))") {
                    Stepper("Price", value: $price, in: 0...100, step: 0.50)
                }

                // ✅ Stepper in HStack
                ComponentSection(title: "Stepper in HStack") {
                    HStack {
                        Text("Items:")
                        Spacer()
                        Stepper("", value: $quantity, in: 0...10)
                        Text("\(quantity)")
                    }
                }
            }        }
    }

    // MARK: - Progress Components

    struct ProgressComponentsView: View {
        @State private var progress = 0.5
        @State private var isAnimating = false

        private let progressSteps: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

        var body: some View {
            ComponentScreen(title: "Progress Components",
                       subtitle: "SwiftUI ProgressView → UIProgressView/UIActivityIndicator (display-only).") {
                // ✅ Progress View - Linear
                ComponentSection(title: "Linear Progress") {
                    ProgressView(value: progress) {
                        Text("Loading...")
                    }
                }

                // ✅ Progress View - Circular
                ComponentSection(title: "Circular Progress") {
                    ProgressView("Downloading...")
                        .progressViewStyle(.circular)
                }

                // ✅ Indeterminate Progress View
                ComponentSection(title: "Indeterminate Progress") {
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
                ComponentSection(title: "Custom Progress: \(Int(progress * 100))%") {
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
            }        }
    }

    // MARK: - Combined Components View

    struct CombinedUIComponentsView: View {
        var body: some View {
            TabView {
                ToggleComponentsView()
                    .tabItem {
                        Label("Toggles", systemImage: "switch.2")
                    }

                SegmentComponentsView()
                    .tabItem {
                        Label("Segments", systemImage: "rectangle.split.3x1")
                    }

                PickerComponentsView()
                    .tabItem {
                        Label("Pickers", systemImage: "list.bullet")
                    }

                SliderComponentsView()
                    .tabItem {
                        Label("Sliders", systemImage: "slider.horizontal.3")
                    }

                StepperComponentsView()
                    .tabItem {
                        Label("Steppers", systemImage: "plusminus")
                    }

                ProgressComponentsView()
                    .tabItem {
                        Label("Progress", systemImage: "progress.indicator")
                    }
            }
            .navigationTitle("UI Components")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ComponentsShowcase.CombinedUIComponentsView()
    }
}
