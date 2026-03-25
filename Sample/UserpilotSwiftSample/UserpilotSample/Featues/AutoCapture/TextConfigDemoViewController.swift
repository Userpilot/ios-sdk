//
//  TextConfigDemoViewController.swift
//  UserpilotSample
//
//  Created by Userpilot on 17/02/2026.
//
//  [Brief Description]
//  Demo screen for UIKit text capture configurations and privacy settings
//

import UIKit

class TextConfigDemoViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    // Controls for demonstration
    private let switchControl = UISwitch()
    private let slider = UISlider()

    // Labels with different privacy settings
    private let regularLabel = UILabel()
    private let redactedLabel = UILabel()
    private let redactedAccessibilityLabel = UILabel()

    // Buttons with different privacy settings
    private let regularButton = UIButton(type: .system)
    private let redactedButton = UIButton(type: .system)

    // Custom tappable view
    private let customTappableView = UIView()

    // Ignored interactions view
    private let ignoredView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Text Config Demo"
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        setupScrollView()
        setupStackView()
        addAllDemoElements()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    private func addAllDemoElements() {
        // Header
        addSectionHeader("Text Capture & Privacy Demo")
        addLabel("This screen demonstrates different text capture configurations and privacy settings.")

        // Text Capture Variants
        addSectionHeader("1. Text Capture Variants")

        addLabel("Regular Text (fully captured):")
        regularLabel.text = "Account Number: 123-456-7890"
        regularLabel.numberOfLines = 0
        stackView.addArrangedSubview(regularLabel)

        addLabel("Redacted Text (shows ****):")
        redactedLabel.text = "Account Number: 123-456-7890"
        redactedLabel.userpilotRedactText = true  // Apply redaction
        redactedLabel.numberOfLines = 0
        stackView.addArrangedSubview(redactedLabel)

        addLabel("Redacted Accessibility Label:")
        redactedAccessibilityLabel.text = "Account Number: 123-456-7890"
        redactedAccessibilityLabel.userpilotRedactAccessibilityLabel = true  // Apply accessibility redaction
        redactedAccessibilityLabel.numberOfLines = 0
        stackView.addArrangedSubview(redactedAccessibilityLabel)

        // Interactive Elements
        addSectionHeader("2. Interactive Elements")

        addLabel("Regular Button (text captured):")
        regularButton.setTitle("Regular Button - Account: 123-456-7890", for: .normal)
        regularButton.backgroundColor = .systemBlue
        regularButton.setTitleColor(.white, for: .normal)
        regularButton.layer.cornerRadius = 8
        regularButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        regularButton.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(regularButton)

        addLabel("Redacted Button (text hidden):")
        redactedButton.setTitle("Redacted Button - Account: 123-456-7890", for: .normal)
        redactedButton.userpilotRedactText = true  // Redact button text
        redactedButton.backgroundColor = .systemRed
        redactedButton.setTitleColor(.white, for: .normal)
        redactedButton.layer.cornerRadius = 8
        redactedButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        redactedButton.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(redactedButton)

        // Custom Tappable View
        addSectionHeader("3. Custom Tappable View")
        addLabel("Custom UIView with tap gesture (needs userpilotRecognizeClickAnalytics):")
        setupCustomTappableView()
        stackView.addArrangedSubview(customTappableView)

        // Ignored Interactions
        addSectionHeader("4. Ignored Interactions")
        addLabel("This view ignores all interactions (userpilotIgnoreInteractions = true):")
        setupIgnoredView()
        stackView.addArrangedSubview(ignoredView)

        // Control Values
        addSectionHeader("5. Control Values (enableInteractionValueCapture)")
        addLabel("Switch (captures on/off state):")
        let switchContainer = createLabeledControl(label: "Feature Enabled", control: switchControl)
        switchControl.addTarget(self, action: #selector(onSwitchChanged(_:)), for: .valueChanged)
        stackView.addArrangedSubview(switchContainer)

        addLabel("Slider (captures numeric value):")
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 75
        slider.addTarget(self, action: #selector(onSliderChanged(_:)), for: .valueChanged)
        stackView.addArrangedSubview(slider)

        // Configuration Notes
        addSectionHeader("6. Configuration Notes")
        addLabel("""
        • userpilotRedactText = true → Text becomes "****" in events
        • userpilotRedactAccessibilityLabel = true → Accessibility labels redacted
        • userpilotRecognizeClickAnalytics() → Makes custom views tappable
        • userpilotIgnoreInteractions = true → No interaction events captured
        • enableInteractionValueCapture = true → Captures control values
        """)
    }

    private func setupCustomTappableView() {
        customTappableView.backgroundColor = .systemGreen
        customTappableView.layer.cornerRadius = 8
        customTappableView.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let label = UILabel()
        label.text = "Tap Me! (Custom View)"
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        customTappableView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: customTappableView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: customTappableView.centerYAnchor),
        ])

        // Add tap gesture and make it recognizable for analytics
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onCustomViewTapped))
        customTappableView.addGestureRecognizer(tapGesture)
        customTappableView.isUserInteractionEnabled = true
        customTappableView.userpilotRecognizeClickAnalytics()  // Enable click analytics
    }

    private func setupIgnoredView() {
        ignoredView.backgroundColor = .systemGray
        ignoredView.layer.cornerRadius = 8
        ignoredView.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let label = UILabel()
        label.text = "Interactions Ignored (No Events)"
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        ignoredView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: ignoredView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: ignoredView.centerYAnchor),
        ])

        // Add tap gesture but ignore interactions
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onIgnoredViewTapped))
        ignoredView.addGestureRecognizer(tapGesture)
        ignoredView.isUserInteractionEnabled = true
        ignoredView.userpilotIgnoreInteractions = true  // Ignore all interactions
    }

    // MARK: - Actions

    @objc private func onButtonTapped(_ sender: UIButton) {
        let buttonType = sender == regularButton ? "Regular" : "Redacted"
        showAlert("\(buttonType) Button", "Button tapped - check analytics for text capture behavior")
    }

    @objc private func onCustomViewTapped() {
        showAlert("Custom View", "Custom tappable view tapped - enabled via userpilotRecognizeClickAnalytics()")
    }

    @objc private func onIgnoredViewTapped() {
        showAlert("Ignored View", "This shouldn't generate analytics events due to userpilotIgnoreInteractions = true")
    }

    @objc private func onSwitchChanged(_ sender: UISwitch) {
        print("Switch value: \(sender.isOn)")
    }

    @objc private func onSliderChanged(_ sender: UISlider) {
        print("Slider value: \(sender.value)")
    }

    // MARK: - Helper Methods

    private func addSectionHeader(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 16)
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    private func addLabel(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    private func createLabeledControl(label text: String, control: UIView) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(control)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 44),
        ])

        return container
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}