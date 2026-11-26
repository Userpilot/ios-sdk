//
//  ThemeViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 07/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises theme selection, clearing and manual experience triggering through the public SDK APIs.
//

import UIKit

final class ThemeViewController: BaseViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let themeNameField = UITextField()
    private let experienceIdField = UITextField()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Theme"
        setupUI()
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("theme")
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        addLabel(
            "Stay online and identify a user before triggering an experience. " +
            "Use a flow or survey to verify theme changes; NPS keeps its own theme."
        )
        addThemeSection()
        addExperienceSection()
        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Ready. Apply a theme or trigger an experience."
        stackView.addArrangedSubview(statusLabel)
    }

    private func addThemeSection() {
        addLabel("Theme", style: .headline)
        addLabel(
            "Apply an exact mobile theme title from Userpilot. It affects the next experience; " +
            "an already displayed experience stays unchanged. Clear restores each experience's own theme."
        )
        addField(themeNameField, title: "Theme name")
        addButton("Apply theme", action: #selector(applyTheme))
        addButton("Clear theme", action: #selector(clearTheme))
    }

    private func addExperienceSection() {
        addLabel("Experience", style: .headline)
        addLabel(
            "Dismiss any active experience, then trigger the same ID after applying or clearing a theme to compare."
        )
        addField(experienceIdField, title: "Experience ID")
        addButton("Trigger experience", action: #selector(triggerExperience))
    }

    private func addLabel(_ text: String, style: UIFont.TextStyle = .subheadline) {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    private func addField(_ field: UITextField, title: String) {
        field.placeholder = title
        field.accessibilityLabel = title
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.delegate = self
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stackView.addArrangedSubview(field)
    }

    private func addButton(_ title: String, action: Selector) {
        let button = UIButton(type: .system)
        button.applyLiquidGlassStyle(.regular, title: title, unifiedHeight: false)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stackView.addArrangedSubview(button)
    }

    @objc private func applyTheme() {
        let name = themeNameField.text ?? ""
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusLabel.text = "Enter a theme name first."
            return
        }
        view.endEditing(true)
        UserpilotManager.shared.theme(name)
        statusLabel.text = "theme(\"\(name)\") requested. Trigger an experience to verify its appearance."
    }

    @objc private func clearTheme() {
        view.endEditing(true)
        UserpilotManager.shared.clearTheme()
        statusLabel.text = "clearTheme() requested. The next experience uses its own theme."
    }

    @objc private func triggerExperience() {
        let experienceId = (experienceIdField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !experienceId.isEmpty else {
            statusLabel.text = "Enter an experience ID first."
            return
        }
        view.endEditing(true)
        UserpilotManager.shared.triggerExperience(experienceId: experienceId)
        statusLabel.text =
            "triggerExperience(\"\(experienceId)\") requested. Check the displayed experience and SDK logs."
    }

    /// Keep both fields and actions reachable while editing, including on iOS 13 and small screens.
    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardFrame = view.convert(frame, from: nil)
        let overlap = scrollView.frame.intersection(keyboardFrame)
        scrollView.contentInset.bottom = overlap.isNull ? 0 : overlap.height
        scrollView.verticalScrollIndicatorInsets.bottom = scrollView.contentInset.bottom
    }
}

extension ThemeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
