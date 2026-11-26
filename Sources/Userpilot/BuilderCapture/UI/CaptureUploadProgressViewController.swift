//
//  CaptureUploadProgressViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Blocking upload progress card styled like a system alert, asking the operator to keep the app open.
//

import UIKit

// MARK: - CaptureUploadProgressViewController

/// Shown while a capture uploads. It has no buttons and cannot be dismissed by the operator; the
/// coordinator removes it when the upload finishes. iOS has no system progress alert, and adding a
/// spinner inside `UIAlertController` changes its private view hierarchy, so this card copies its look.
internal final class CaptureUploadProgressViewController: UIViewController {

    private enum Constants {
        static let cardWidth: CGFloat = 270
        static let cornerRadius: CGFloat = 14
        static let contentInset: CGFloat = 20
        static let spacing: CGFloat = 12
        static let dimAlpha: CGFloat = 0.2
    }

    // MARK: Views

    private lazy var cardView: UIVisualEffectView = {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = Constants.cornerRadius
        card.clipsToBounds = true
        return card
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = CapturePillView.Palette.brand
        indicator.hidesWhenStopped = false
        indicator.startAnimating()
        return indicator
    }()

    private lazy var titleLabel: UILabel = makeLabel(
        text: BuilderCaptureStrings.uploadingTitle,
        textStyle: .headline
    )

    private lazy var messageLabel: UILabel = makeLabel(
        text: BuilderCaptureStrings.uploadingMessage,
        textStyle: .footnote
    )

    // MARK: Initialization

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Builder UI is not a host-app screen; keep screen tracking away from it.
        objc_setAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)

        view.backgroundColor = UIColor.black.withAlphaComponent(Constants.dimAlpha)
        view.accessibilityViewIsModal = true
        buildHierarchy()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    // MARK: Layout

    private func buildHierarchy() {
        let stack = UIStackView(arrangedSubviews: [activityIndicator, titleLabel, messageLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Constants.spacing

        view.addSubview(cardView)
        cardView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: Constants.cardWidth),

            stack.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: Constants.contentInset),
            stack.bottomAnchor.constraint(
                equalTo: cardView.contentView.bottomAnchor, constant: -Constants.contentInset),
            stack.leadingAnchor.constraint(
                equalTo: cardView.contentView.leadingAnchor, constant: Constants.contentInset),
            stack.trailingAnchor.constraint(
                equalTo: cardView.contentView.trailingAnchor, constant: -Constants.contentInset)
        ])
    }

    /// Dynamic Type label, centered like alert text.
    private func makeLabel(text: String, textStyle: UIFont.TextStyle) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: textStyle)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }
}
