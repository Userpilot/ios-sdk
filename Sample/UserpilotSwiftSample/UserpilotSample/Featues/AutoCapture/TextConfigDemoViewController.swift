//
//  TextConfigDemoViewController.swift
//  UserpilotSample
//
//  Created by Userpilot on 17/02/2026.
//
//  [Brief Description]
//  Demo screen for UIKit screen and view autocapture configurations.
//

import UIKit
import Userpilot

// swiftlint:disable all
class TextConfigDemoViewController: DemoBackButtonViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    private let switchControl = UISwitch()
    private let slider = UISlider()

    private let regularLabel = UILabel()
    private let redactedLabel = UILabel()
    private let redactedAccessibilityLabel = UILabel()

    private let regularButton = UIButton(type: .system)
    private let redactedButton = UIButton(type: .system)
    private let ignoredScreenButton = UIButton(type: .system)
    private let customContainerButton = UIButton(type: .system)
    private let stopAutoCaptureButton = UIButton(type: .system)
    private let resumeAutoCaptureButton = UIButton(type: .system)

    private let customTappableView = UIView()
    private let ignoredView = UIView()
    private let ignoreInnerHierarchyContainer = UIView()
    private let ignoreInnerHierarchyButton = UIButton(type: .system)
    private let defaultIgnoredView = DefaultIgnoredTapView()
    private let defaultIgnoreInnerHierarchyContainer = DefaultIgnoreInnerHierarchyContainerView()
    private let defaultIgnoreInnerHierarchyButton = UIButton(type: .system)

    override var userpilotScreenName: String? {
        "UIKit Config Showcase"
    }

    override var userpilotScreenTitle: String? {
        "Autocapture UIKit Configs"
    }

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
            scrollView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: demoBackButtonTopInset
            ),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
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
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    // swiftlint:disable:next function_body_length
    private func addAllDemoElements() {
        addSectionHeader("UIKit Screen + View Config Demo")
        addLabel("""
        This screen now exercises every config exposed by UIKit+ScreenAPIs, UIKit+ViewAPIs, and UIView+ClickAnalytics.
        """)

        addSectionHeader("1. Screen API Overrides")
        addLabel("This controller overrides userpilotScreenName -> \"UIKit Config Showcase\".")
        addLabel("This controller overrides userpilotScreenTitle -> \"Autocapture UIKit Configs\".")

        ignoredScreenButton.setTitle("Open Ignored Screen Demo", for: .normal)
        ignoredScreenButton.addTarget(self, action: #selector(openIgnoredScreenDemo), for: .touchUpInside)
        ignoredScreenButton.applyDemoStyle(backgroundColor: .systemTeal)
        stackView.addArrangedSubview(ignoredScreenButton)

        customContainerButton.setTitle("Open Container Screen Demo", for: .normal)
        customContainerButton.addTarget(
            self,
            action: #selector(openCustomContainerDemo),
            for: .touchUpInside
        )
        customContainerButton.applyDemoStyle(backgroundColor: .systemIndigo)
        stackView.addArrangedSubview(customContainerButton)

        addSectionHeader("2. Text Capture Variants")

        addLabel("Regular Text (fully captured):")
        regularLabel.text = "Account Number: 123-456-7890"
        regularLabel.numberOfLines = 0
        stackView.addArrangedSubview(regularLabel)

        addLabel("Redacted Text via Userpilot.userpilotSetRedactText(_:for:):")
        redactedLabel.text = "Account Number: 123-456-7890"
        Userpilot.userpilotSetRedactText(true, for: redactedLabel)
        redactedLabel.numberOfLines = 0
        stackView.addArrangedSubview(redactedLabel)

        addLabel("Redacted Accessibility Label via Userpilot.userpilotSetRedactAccessibilityLabel(_:for:):")
        redactedAccessibilityLabel.text = "Account Number: 123-456-7890"
        redactedAccessibilityLabel.accessibilityLabel = "Accessibility: Account Number: 123-456-7890"
        Userpilot.userpilotSetRedactAccessibilityLabel(true, for: redactedAccessibilityLabel)
        redactedAccessibilityLabel.numberOfLines = 0
        stackView.addArrangedSubview(redactedAccessibilityLabel)

        addSectionHeader("3. Interactive Elements")

        addLabel("Regular Button (text captured):")
        regularButton.setTitle("Regular Button - Account: 123-456-7890", for: .normal)
        regularButton.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
        regularButton.applyDemoStyle(backgroundColor: .systemBlue)
        stackView.addArrangedSubview(regularButton)

        addLabel("Redacted Button via Userpilot.userpilotSetRedactText(_:for:):")
        redactedButton.setTitle("Redacted Button - Account: 123-456-7890", for: .normal)
        Userpilot.userpilotSetRedactText(true, for: redactedButton)
        redactedButton.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
        redactedButton.applyDemoStyle(backgroundColor: .systemRed)
        stackView.addArrangedSubview(redactedButton)

        addSectionHeader("4. Custom Tappable View")
        addLabel("Tap this plain UIView to test userpilotRecognizeClickAnalytics().")
        setupCustomTappableView()
        stackView.addArrangedSubview(customTappableView)

        addSectionHeader("5. Ignored Interactions")
        addLabel("This view uses userpilotIgnoreInteractions = true, so taps should not create events.")
        setupIgnoredView()
        stackView.addArrangedSubview(ignoredView)

        addSectionHeader("6. Ignore Inner Hierarchy")
        addLabel("""
        Tap the child button below. Analytics should attribute the interaction to the parent container because userpilotIgnoreInnerHierarchy = true is applied to the parent.
        """)
        setupIgnoreInnerHierarchyDemo()
        stackView.addArrangedSubview(ignoreInnerHierarchyContainer)

        addSectionHeader("7. Class Default Helpers")
        addLabel("These two views test class defaults: userpilotIgnoreInteractionsDefault and userpilotIgnoreInnerHierarchyDefault.")
        setupDefaultIgnoredView()
        stackView.addArrangedSubview(defaultIgnoredView)
        setupDefaultIgnoreInnerHierarchyDemo()
        stackView.addArrangedSubview(defaultIgnoreInnerHierarchyContainer)

        addSectionHeader("8. Stop / Resume AutoCapture")
        addLabel("Use these buttons to test the per-instance userpilot.stopAutoCapture() and userpilot.resumeAutoCapture().")
        stopAutoCaptureButton.setTitle("Stop AutoCapture", for: .normal)
        stopAutoCaptureButton.addTarget(
            self,
            action: #selector(onStopAutoCaptureTapped),
            for: .touchUpInside
        )
        stopAutoCaptureButton.applyDemoStyle(backgroundColor: .systemPink)
        stackView.addArrangedSubview(stopAutoCaptureButton)

        resumeAutoCaptureButton.setTitle("Resume AutoCapture", for: .normal)
        resumeAutoCaptureButton.addTarget(
            self,
            action: #selector(onResumeAutoCaptureTapped),
            for: .touchUpInside
        )
        resumeAutoCaptureButton.applyDemoStyle(backgroundColor: .systemGreen)
        stackView.addArrangedSubview(resumeAutoCaptureButton)

        addSectionHeader("9. Control Values")
        addLabel("These controls help verify enableInteractionValueCapture behavior.")

        let switchContainer = createLabeledControl(label: "Feature Enabled", control: switchControl)
        switchControl.addTarget(self, action: #selector(onSwitchChanged(_:)), for: .valueChanged)
        stackView.addArrangedSubview(switchContainer)

        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 75
        slider.addTarget(self, action: #selector(onSliderChanged(_:)), for: .valueChanged)
        stackView.addArrangedSubview(slider)

        addSectionHeader("10. Configuration Notes")
        addLabel("""
        userpilotScreenName -> custom screen name for this controller.
        userpilotScreenTitle -> custom screen title for this controller.
        userpilotIgnoreScreen -> use the ignored screen demo to confirm no screen event is emitted.
        isUserpilotContainerClass -> use the container screen demo to inspect the payload flag.
        Userpilot.userpilotSetRedactText -> text becomes \"****\" in events.
        Userpilot.userpilotSetRedactAccessibilityLabel -> accessibility labels are redacted.
        userpilotIgnoreInteractions -> interaction events are skipped.
        userpilotIgnoreInnerHierarchy -> inner path details collapse to the parent container.
        userpilotIgnoreInteractionsDefault -> all instances of the demo subclass ignore taps.
        userpilotIgnoreInnerHierarchyDefault -> all instances of the demo subclass collapse inner details.
        userpilot.stopAutoCapture / resumeAutoCapture -> pause and resume autocapture for this instance only.
        userpilotRecognizeClickAnalytics() -> makes custom UIViews trackable as taps.
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
            label.centerYAnchor.constraint(equalTo: customTappableView.centerYAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onCustomViewTapped))
        customTappableView.addGestureRecognizer(tapGesture)
        customTappableView.isUserInteractionEnabled = true
        customTappableView.userpilotRecognizeClickAnalytics()
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
            label.centerYAnchor.constraint(equalTo: ignoredView.centerYAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onIgnoredViewTapped))
        ignoredView.addGestureRecognizer(tapGesture)
        ignoredView.isUserInteractionEnabled = true
        ignoredView.userpilotIgnoreInteractions = true
    }

    private func setupIgnoreInnerHierarchyDemo() {
        ignoreInnerHierarchyContainer.backgroundColor = .secondarySystemBackground
        ignoreInnerHierarchyContainer.layer.cornerRadius = 12
        ignoreInnerHierarchyContainer.userpilotIgnoreInnerHierarchy = true
        ignoreInnerHierarchyContainer.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Secure Entry Container"
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Internal labels and button text should be hidden from element path details."
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        ignoreInnerHierarchyButton.setTitle("Tap Child Action", for: .normal)
        ignoreInnerHierarchyButton.addTarget(
            self,
            action: #selector(onIgnoreInnerHierarchyTapped),
            for: .touchUpInside
        )
        ignoreInnerHierarchyButton.applyDemoStyle(backgroundColor: .systemOrange)

        let innerStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            ignoreInnerHierarchyButton
        ])
        innerStack.axis = .vertical
        innerStack.spacing = 12
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        ignoreInnerHierarchyContainer.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: ignoreInnerHierarchyContainer.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: ignoreInnerHierarchyContainer.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: ignoreInnerHierarchyContainer.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: ignoreInnerHierarchyContainer.bottomAnchor, constant: -16)
        ])
    }

    private func setupDefaultIgnoredView() {
        defaultIgnoredView.backgroundColor = .systemGray5
        defaultIgnoredView.layer.cornerRadius = 12
        defaultIgnoredView.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let label = UILabel()
        label.text = "Default Ignore Interactions Subclass"
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false

        defaultIgnoredView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: defaultIgnoredView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: defaultIgnoredView.centerYAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onDefaultIgnoredViewTapped))
        defaultIgnoredView.addGestureRecognizer(tapGesture)
        defaultIgnoredView.isUserInteractionEnabled = true
    }

    private func setupDefaultIgnoreInnerHierarchyDemo() {
        defaultIgnoreInnerHierarchyContainer.backgroundColor = .systemGray6
        defaultIgnoreInnerHierarchyContainer.layer.cornerRadius = 12
        defaultIgnoreInnerHierarchyContainer.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Default Ignore Inner Hierarchy Subclass"
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "This container gets its behavior from the class default helper, not an instance property."
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        defaultIgnoreInnerHierarchyButton.setTitle("Tap Default Child Action", for: .normal)
        defaultIgnoreInnerHierarchyButton.addTarget(
            self,
            action: #selector(onDefaultIgnoreInnerHierarchyTapped),
            for: .touchUpInside
        )
        defaultIgnoreInnerHierarchyButton.applyDemoStyle(backgroundColor: .systemPurple)

        let innerStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            defaultIgnoreInnerHierarchyButton
        ])
        innerStack.axis = .vertical
        innerStack.spacing = 12
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        defaultIgnoreInnerHierarchyContainer.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: defaultIgnoreInnerHierarchyContainer.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: defaultIgnoreInnerHierarchyContainer.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: defaultIgnoreInnerHierarchyContainer.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: defaultIgnoreInnerHierarchyContainer.bottomAnchor, constant: -16)
        ])
    }

    @objc private func onButtonTapped(_ sender: UIButton) {
        let buttonType = sender == regularButton ? "Regular" : "Redacted"
        showAlert(buttonType + " Button", "Button tapped - inspect analytics for text capture behavior.")
    }

    @objc private func onCustomViewTapped() {
        showAlert("Custom View", "Custom tappable view tapped via userpilotRecognizeClickAnalytics().")
    }

    @objc private func onIgnoredViewTapped() {
        showAlert("Ignored View", "This tap should not create analytics events because interactions are ignored.")
    }

    @objc private func onIgnoreInnerHierarchyTapped() {
        showAlert(
            "Ignore Inner Hierarchy",
            "Tap the child button and verify analytics attribute the event to the parent container."
        )
    }

    @objc private func onDefaultIgnoredViewTapped() {
        showAlert(
            "Default Ignore Interactions",
            "This subclass uses override class var userpilotIgnoreInteractionsDefault: Bool { true }."
        )
    }

    @objc private func onDefaultIgnoreInnerHierarchyTapped() {
        showAlert(
            "Default Ignore Inner Hierarchy",
            "This subclass uses override class var userpilotIgnoreInnerHierarchyDefault: Bool { true }."
        )
    }

    @objc private func onStopAutoCaptureTapped() {
        UserpilotManager.shared.stopAutoCapture()
        showAlert("AutoCapture Stopped", "Autocapture is now paused until you tap Resume AutoCapture.")
    }

    @objc private func onResumeAutoCaptureTapped() {
        UserpilotManager.shared.resumeAutoCapture()
        showAlert("AutoCapture Resumed", "Autocapture is active again.")
    }

    @objc private func onSwitchChanged(_ sender: UISwitch) {
        print("Switch value: \(sender.isOn)")
    }

    @objc private func onSliderChanged(_ sender: UISlider) {
        print("Slider value: \(sender.value)")
    }

    @objc private func openIgnoredScreenDemo() {
        let viewController = IgnoredScreenDemoViewController()
        if let navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            present(viewController, animated: true)
        }
    }

    @objc private func openCustomContainerDemo() {
        let viewController = ScreenAPIContainerDemoViewController()
        if let navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            present(viewController, animated: true)
        }
    }

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
            container.heightAnchor.constraint(equalToConstant: 44)
        ])

        return container
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}


private final class ScreenAPIContainerDemoViewController: DemoBackButtonViewController {

    private let childHostView = UIView()
    private let childViewController = ScreenAPIContainerChildViewController()

    override class var isUserpilotContainerClass: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Container Screen Demo"
        view.backgroundColor = .systemBackground
        setupBody()
        embedChild()
    }

    private func setupBody() {
        let titleLabel = UILabel()
        titleLabel.text = "Custom Container Screen"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.text = """
        This controller overrides isUserpilotContainerClass = true.
        Use it to inspect the container flag and the embedded child screen override behavior.
        """
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        childHostView.backgroundColor = .tertiarySystemBackground
        childHostView.layer.cornerRadius = 16
        childHostView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(childHostView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: demoBackButtonTopInset + 20
            ),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            childHostView.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 24),
            childHostView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            childHostView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            childHostView.heightAnchor.constraint(equalToConstant: 220)
        ])
    }

    private func embedChild() {
        addChild(childViewController)
        childViewController.view.translatesAutoresizingMaskIntoConstraints = false
        childHostView.addSubview(childViewController.view)

        NSLayoutConstraint.activate([
            childViewController.view.topAnchor.constraint(equalTo: childHostView.topAnchor),
            childViewController.view.leadingAnchor.constraint(equalTo: childHostView.leadingAnchor),
            childViewController.view.trailingAnchor.constraint(equalTo: childHostView.trailingAnchor),
            childViewController.view.bottomAnchor.constraint(equalTo: childHostView.bottomAnchor)
        ])

        childViewController.didMove(toParent: self)
    }
}

internal final class DefaultIgnoredTapView: UIView {
    override class var userpilotIgnoreInteractionsDefault: Bool { true }
}

internal final class DefaultIgnoreInnerHierarchyContainerView: UIView {
    override class var userpilotIgnoreInnerHierarchyDefault: Bool { true }
}

internal extension UIButton {

    func applyDemoStyle(backgroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        setTitleColor(.white, for: .normal)
        layer.cornerRadius = 8
        heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
}
// swiftlint:enable all
