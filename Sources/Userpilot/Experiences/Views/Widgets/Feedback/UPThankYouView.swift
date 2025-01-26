//
//  UPThankYouView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 30/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A custom view that displays a "Thank You" message, incorporating a `UPTitleDescriptionView`
//  for the title and description.
//

import UIKit

internal class UPThankYouView: UIView {

    // MARK: - Properties

    private let titleDescriptionView = UPTitleDescriptionView()
    private let actionButton = UIButton(type: .custom)
    var actionButtonClicked: (String?) -> Void = { _ in }
    private var surveyStep: SurveyStep?

    // MARK: - Initializers

    /// Initializes the view with a specified frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViewHierarchy()
    }

    /// Initializes the view from a storyboard or nib.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViewHierarchy()
    }

    // MARK: - Private Methods

    /// Sets up the view hierarchy by adding the `titleDescriptionView` and `actionButton` to the `UPThankYouView`.
    private func setupViewHierarchy() {
        addSubview(titleDescriptionView)
        addSubview(actionButton)

        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        // Activate constraints to position titleDescriptionView within the parent view
        NSLayoutConstraint.activate([
            titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
            titleDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])

        // Activate constraints to position actionButton below titleDescriptionView
        NSLayoutConstraint.activate([
            actionButton.topAnchor.constraint(equalTo: titleDescriptionView.bottomAnchor, constant: 24),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            actionButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            actionButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Public Methods

    /// Sets up the view using data from the provided survey step and theme.
    /// - Parameters:
    ///   - surveyStep: The survey step containing question and subheader data.
    ///   - surveyTheme: The theme containing style properties for the text.
    func setupView(surveyStep: SurveyStep, surveyTheme: SurveyTheme) {
        self.surveyStep = surveyStep
        titleDescriptionView.setupView(surveyStep: surveyStep, surveyTheme: surveyTheme)
        setupButton(surveyStep: surveyStep, surveyTheme: surveyTheme)
    }

    func setupView() {
        titleDescriptionView.setupView()
    }

    // MARK: - Public Button Setup

    /// Setup button properties, title, and actions.
    func setupButton(surveyStep: SurveyStep, surveyTheme: SurveyTheme) {
        actionButton.titleLabel?.font = UIFont.matching(fontName: surveyTheme.fontFamily,
                                           fontWeight: [.traitBold],
                                           fontSize: 16)
        actionButton.setTitle(surveyStep.buttonLabel, for: .normal)
        actionButton.backgroundColor = surveyTheme.primaryColor
        actionButton.setTitleColor(surveyTheme.primaryColorAsString.invertColor().color, for: .normal)
        actionButton.layer.cornerRadius = 12
        actionButton.addTarget(self, action: #selector(onActionButtonClicked), for: .touchUpInside)
    }

    @objc func onActionButtonClicked() {
        actionButtonClicked(surveyStep?.metadata?.iosDeepLink)
    }
}
