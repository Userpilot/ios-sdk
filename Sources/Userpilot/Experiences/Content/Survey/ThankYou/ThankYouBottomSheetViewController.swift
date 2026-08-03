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

    /// Breathing room between the thank-you message and the action button.
    ///
    /// This used to `return thankYouView`, so `spaceView` *was* `thankYouView` — and a stack view given
    /// the same view twice keeps one entry, which meant the spacer never existed and the 40 pt constraint
    /// was activated on a view that was thrown away. The gap below the message was the stack's spacing
    /// alone.
    private lazy var spaceView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.heightAnchor.constraint(
            equalToConstant: ThemeHandler.DefaultValues.distanceBetweenSections).isActive = true
        return view
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
        let stackView = UIStackView(arrangedSubviews:
            [buttonDismissContainerView, thankYouView, spaceView, actionButton])
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Properties
    internal let surveyContent: SurveyContent
    internal let surveyTheme: SurveyTheme

    // `glassResolver` is inherited from `BottomSheetViewController`. This controller is built
    // directly by `ExperiencesPublisher` rather than from a view model, so the publisher
    // injects the resolver after construction and before presentation.
    var actionButtonClicked: (String?) -> Void = { _ in }
    var onDismissCompleted: () -> Void = {}

    // MARK: - Initializers

    /// Initializes the `SlideOutBottomSheetViewController` with a given view model.
    ///
    /// - Parameter experienceViewModel: The view model that controls the experience data and behavior.
    init(
        surveyContent: SurveyContent,
        surveyTheme: SurveyTheme
    ) {
        self.surveyContent = surveyContent
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
        setContent(content: contentStackView)
        setupCloseButton()
        bindThankYouView()
        setupGeneralStyle()
    }

    @objc private func buttonDismissClicked() {
        actionButtonClicked(nil)
        dismissThankYouBottomSheet()
    }

    private func dismissThankYouBottomSheet() {
        dismissBottomSheet { [weak self] in
            self?.onDismissCompleted()
        }
    }

}

// MARK: - ViewModel Binding
extension ThankYouBottomSheetViewController {

    /// Binds the view model's data and updates the `slideOutContainerView` accordingly.
    /// This method is responsible for responding to any changes in the view model's state and ensuring the
    /// content displayed in the bottom sheet is kept up-to-date.
    func bindThankYouView() {
        guard let surveyStep = surveyContent.modules.last else { return }
        thankYouView.setupView(surveyStep: surveyStep,
                               surveyTheme: surveyTheme,
                               isRTL: surveyContent.localeCode.isRTL == true)

        // Set up action button with appropriate action and style
        actionButton.setupViews(
            title: surveyStep.buttonLabel ?? "Next",
            theme: surveyTheme
        ) { [weak self] _ in
            self?.actionButtonClicked(
                surveyStep.metadata?.buttonAction == .deepLink ?
                surveyStep.metadata?.iosDeepLink : nil)
            self?.dismissThankYouBottomSheet()
        }
    }

    func setupCloseButton() {
        let buttonDismiss = UPDismissButton()
        buttonDismiss.glassResolver = glassResolver
        buttonDismiss.setupView(theme: surveyTheme)
        buttonDismissContainerView.addSubview(buttonDismiss)
        buttonDismiss.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            buttonDismiss.bottomAnchor.constraint(equalTo: buttonDismissContainerView.bottomAnchor),
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
