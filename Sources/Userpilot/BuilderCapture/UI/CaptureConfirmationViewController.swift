//
//  CaptureConfirmationViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Presents the captured screen and reports one dismissed confirmation outcome.
//

import UIKit

// MARK: - CaptureConfirmationViewController

/// Confirmation sheet for one pending capture.
internal final class CaptureConfirmationViewController: UIViewController {

    // MARK: Nested Types

    /// What the operator chose.
    enum Outcome {

        /// Save this capture under the given name.
        case save(screenName: String)

        /// Discard and take another screenshot.
        case retry

        /// Leave the capture, keep capture mode active.
        case cancel
    }

    private enum Constants {
        static let contentSpacing: CGFloat = 16
        static let contentInset: CGFloat = 20
        static let previewHeight: CGFloat = 320
        static let fieldHeight: CGFloat = 44
        static let buttonHeight: CGFloat = 44
        static let cornerRadius: CGFloat = 8
        static let titleFontSize: CGFloat = 20
        static let bodyFontSize: CGFloat = 14
        static let fieldFontSize: CGFloat = 16
        static let borderWidth: CGFloat = 1
    }

    // MARK: Properties

    private let annotatedScreenshot: UIImage
    private let targetableElementCount: Int
    private let suggestedScreenName: String
    private let completion: (Outcome) -> Void

    /// Guards against reporting twice — the sheet can be dismissed by a button
    /// *and* by a swipe, and a double report would save a capture and then
    /// immediately retry it.
    private var hasReported = false

    // MARK: Views

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = Constants.contentSpacing
        return stack
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = BuilderCaptureStrings.confirmationTitle
        label.font = .systemFont(ofSize: Constants.titleFontSize, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView(image: annotatedScreenshot)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = Constants.borderWidth
        imageView.layer.borderColor = UIColor.separator.cgColor
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = BuilderCaptureStrings.previewAccessibilityLabel
        return imageView
    }()

    private lazy var elementCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Constants.bodyFontSize)
        label.numberOfLines = 0
        return label
    }()

    private lazy var screenNameField: UITextField = {
        let field = UITextField()
        field.text = CaptureDocument.cappedName(suggestedScreenName)
        field.placeholder = BuilderCaptureStrings.screenNamePlaceholder
        field.font = .systemFont(ofSize: Constants.fieldFontSize)
        field.borderStyle = .none
        field.layer.borderWidth = Constants.borderWidth
        field.layer.borderColor = UIColor.separator.cgColor
        field.layer.cornerRadius = Constants.cornerRadius
        field.autocorrectionType = .no
        field.tintColor = CapturePillView.Palette.brand
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .done
        field.delegate = self
        // Inset the text off the border.
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        field.leftViewMode = .always
        return field
    }()

    private lazy var retryButton: UIButton = makeButton(
        title: BuilderCaptureStrings.retry, isPrimary: false, action: #selector(retryTapped))

    private lazy var saveButton: UIButton = makeButton(
        title: BuilderCaptureStrings.save, isPrimary: true, action: #selector(saveTapped))

    // MARK: Initialization

    /// Presents the annotated preview and reports the operator's choice once after dismissal.
    init(
        annotatedScreenshot: UIImage,
        targetableElementCount: Int,
        suggestedScreenName: String,
        completion: @escaping (Outcome) -> Void
    ) {
        self.annotatedScreenshot = annotatedScreenshot
        self.targetableElementCount = targetableElementCount
        self.suggestedScreenName = suggestedScreenName
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keeps the SDK's screen tracking from treating this sheet as a host-app
        // screen, which would overwrite the very screen name being captured.
        objc_setAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey,
            true,
            .OBJC_ASSOCIATION_RETAIN
        )

        view.backgroundColor = .systemBackground
        buildHierarchy()
        applyElementCountState()
        observeKeyboard()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Covers an interactive swipe-to-dismiss, which never routes through a
        // button. Capture mode stays active so the operator can try again.
        report(.cancel)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Keyboard

    /// Insets the scroll view so the keyboard cannot cover the editable name.
    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardFrameWillChange(_ notification: Notification) {
        guard let frame = notification
            .userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        // Convert into this view's space: the notification frame is in screen
        // coordinates, and the sheet does not fill the screen.
        let overlap = view.bounds.maxY - view.convert(frame.cgRectValue, from: nil).minY
        scrollView.contentInset.bottom = max(0, overlap)
        scrollView.verticalScrollIndicatorInsets.bottom = max(0, overlap)
    }

    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: Layout

    private func buildHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        let buttonRow = UIStackView(arrangedSubviews: [retryButton, saveButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = Constants.contentSpacing
        buttonRow.distribution = .fillEqually

        [titleLabel, previewImageView, elementCountLabel, screenNameField, buttonRow]
            .forEach(contentStack.addArrangedSubview)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: Constants.contentInset),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -Constants.contentInset),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                constant: Constants.contentInset),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor,
                constant: -Constants.contentInset),
            // Pin the width to the scroll view's frame so the stack lays out
            // vertically only; without this the content has no defined width.
            contentStack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -Constants.contentInset * 2),

            previewImageView.heightAnchor.constraint(equalToConstant: Constants.previewHeight),
            screenNameField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            retryButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight)
        ])
    }

    /// Builds a Retry or Save button.
    private func makeButton(title: String, isPrimary: Bool, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: Constants.fieldFontSize, weight: .medium)
        button.layer.cornerRadius = Constants.cornerRadius
        button.addTarget(self, action: action, for: .touchUpInside)

        let brand = CapturePillView.Palette.brand
        if isPrimary {
            button.backgroundColor = brand
            button.setTitleColor(.white, for: .normal)
        } else {
            button.setTitleColor(brand, for: .normal)
            button.layer.borderWidth = Constants.borderWidth
            button.layer.borderColor = brand.cgColor
        }

        return button
    }

    /// Warns when no elements are targetable while still allowing local screenshot saving.
    private func applyElementCountState() {
        if targetableElementCount > 0 {
            elementCountLabel.text = String(
                format: BuilderCaptureStrings.targetableSummaryFormat, targetableElementCount)
            elementCountLabel.textColor = .secondaryLabel
        } else {
            elementCountLabel.text = BuilderCaptureStrings.noTargetsWarning
            elementCountLabel.textColor = .systemOrange
        }
    }

    // MARK: Actions

    @objc private func retryTapped() {
        dismissReporting(.retry)
    }

    @objc private func saveTapped() {
        let typed = screenNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Fall back to the tracker's name rather than saving an unnamed capture:
        // the suggestion is already the string runtime targeting matches on.
        let name = (typed?.isEmpty == false ? typed : nil) ?? suggestedScreenName
        dismissReporting(.save(screenName: name))
    }

    private func dismissReporting(_ outcome: Outcome) {
        guard !hasReported else { return }
        hasReported = true
        let completion = completion
        dismiss(animated: true) { completion(outcome) }
    }

    /// Reports the outcome, at most once.
    private func report(_ outcome: Outcome) {
        guard !hasReported else { return }
        hasReported = true
        completion(outcome)
    }
}

// MARK: - UITextFieldDelegate

extension CaptureConfirmationViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    /// Caps the name at `maxNameLength` code points, the `display_name` limit; a longer paste is cut.
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text, let range = Range(range, in: text) else { return true }
        let updated = text.replacingCharacters(in: range, with: string)
        guard updated.unicodeScalars.count > CaptureDocument.maxNameLength else { return true }
        textField.text = CaptureDocument.cappedName(updated)
        return false
    }
}
