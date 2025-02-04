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

    private func setupViewHierarchy() {
        addSubview(titleDescriptionView)

        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false

        // Activate constraints to position titleDescriptionView within the parent view
        NSLayoutConstraint.activate([
            titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
            titleDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleDescriptionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public Methods

    /// Sets up the view using data from the provided survey step and theme.
    /// - Parameters:
    ///   - surveyStep: The survey step containing question and subheader data.
    ///   - surveyTheme: The theme containing style properties for the text.
    func setupView(surveyStep: SurveyStep, surveyTheme: SurveyTheme, isRTL: Bool) {
        titleDescriptionView.setupView(surveyStep: surveyStep, surveyTheme: surveyTheme, isRTL: isRTL)
    }
}
