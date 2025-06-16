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
        backgroundColor = .clear
        addSubview(titleDescriptionView)

        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false

        // Activate constraints to position titleDescriptionView within the parent view
        NSLayoutConstraint.activate([
            titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
            titleDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleDescriptionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public Methods

    /// Sets up the view using data from the provided survey step and theme.
    /// - Parameters:
    ///   - surveyStep: The survey step containing question and subheader data.
    ///   - surveyTheme: The theme containing style properties for the text.
    func setupView(surveyStep: SurveyStep, surveyTheme: SurveyTheme, isRTL: Bool) {
        titleDescriptionView.setupView(
            surveyStep: surveyStep,
            surveyTheme: surveyTheme,
            isListView: false,
            isRTL: isRTL)
    }

    /// Sets up the view with the provided completed data and theme.
    ///
    /// - Parameters:
    ///   - completedData: The data containing the header and subheader text.
    ///   - npsTheme: The theme containing style properties such as text color and font.
    ///   - isRTL: A Boolean indicating whether the layout should be right-to-left.
    func setupView(completedData: CompletedData?, npsTheme: NPSTheme, isRTL: Bool) {
        guard let completedData else { return }
        titleDescriptionView.setupView(
            title: completedData.header,
            subHeader: completedData.subheader,
            npsTheme: npsTheme,
            isRTL: isRTL
        )
        // titleDescriptionView.setMargins(bottom = 0.px(context)) // Uncomment if needed
    }
}
