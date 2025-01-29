//
//  ThankYouBottomSheetViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A view to show Thank you message.
//

import UIKit

internal class ThankYouBottomSheetViewController: BottomSheetViewController {

    // MARK: - UI Components

    /// A container for the dismiss button, with a fixed height.
    private lazy var buttonDismissContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize).isActive = true
        return view
    }()

    /// The container view that holds the main content of the slide-out experience.
    /// This view dynamically binds to the content provided by the view model.
    private lazy var thankYouView: UPThankYouView = {
        let thankYouView = UPThankYouView()
        thankYouView.translatesAutoresizingMaskIntoConstraints = false
        return thankYouView
    }()

    /// The action button at the bottom of the view.
    private lazy var actionButton: UPButtonView = {
        let button = UPButtonView()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: UPButtonView.buttonHeight).isActive = true
        return button
    }()

    /// A vertical stack view to manage the arrangement of UI elements (dismiss button, content, action button).
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [buttonDismissContainerView, thankYouView, actionButton])
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Properties
    internal let surveyStep: SurveyStep
    internal let surveyTheme: SurveyTheme
    var actionButtonClicked: (String?) -> Void = { _ in }

    // MARK: - Initializers

    /// Initializes the `SlideOutBottomSheetViewController` with a given view model.
    ///
    /// - Parameter experienceViewModel: The view model that controls the experience data and behavior.
    init(surveyStep: SurveyStep, surveyTheme: SurveyTheme) {
        self.surveyStep = surveyStep
        self.surveyTheme = surveyTheme
        super.init(nibName: nil, bundle: nil)
    }

    /// This initializer should not be used and will throw a fatal error if called.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    /// Sets up the content view and binds the view model once the view is loaded.
    override func viewDidLoad() {
        super.viewDidLoad()
        setContent(contentStackView)
        setupCloseButton()
        bindThankYouView()
    }

    @objc private func buttonDismissClicked() {
        dismiss(animated: true)
    }
}

// MARK: - ViewModel Binding
internal extension ThankYouBottomSheetViewController {

    /// Binds the view model's data and updates the `slideOutContainerView` accordingly.
    /// This method is responsible for responding to any changes in the view model's state and ensuring the
    /// content displayed in the bottom sheet is kept up-to-date.
    func bindThankYouView() {
        thankYouView.setupView(surveyStep: surveyStep, surveyTheme: surveyTheme)
//        thankYouView.actionButtonClicked = {[weak self] deeplink in
//            self?.actionButtonClicked(deeplink)
//            self?.dismiss(animated: true)
//        }

        // Set up action button with appropriate action and style
        actionButton.setupViews(
            title: surveyStep.buttonLabel ?? "Next",
            theme: surveyTheme
        ) { [weak self] _ in
            self?.actionButtonClicked(self?.surveyStep.metadata?.iosDeepLink)
            self?.dismiss(animated: true)
        }
    }

    func setupCloseButton() {
        let buttonDismiss = UPDismissButton()
        buttonDismiss.setupView(theme: surveyTheme)
        buttonDismissContainerView.addSubview(buttonDismiss)
        buttonDismiss.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            buttonDismiss.topAnchor.constraint(equalTo: buttonDismissContainerView.topAnchor),
            buttonDismiss.trailingAnchor.constraint(
                equalTo: buttonDismissContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.dismissButtonMargin),
            buttonDismiss.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),
            buttonDismiss.widthAnchor.constraint(equalToConstant: UPDismissButton.buttonSize)
        ])

        buttonDismiss.addTarget(self, action: #selector(buttonDismissClicked), for: .touchUpInside)
    }
    /// Configures the general appearance and behavior of the slide-out experience,
    /// including the background color and step progress.
    func setupGeneralStyle() {
        // Set the background color of the bottom sheet based on the theme provided by the view model.
        setBackgroundColor(surveyTheme)
    }
}
