//
//  UPTitleDescriptionView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 30/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A custom view that displays a title and a description in a vertical layout.
//

import UIKit

internal class UPTitleDescriptionView: UIView {

    // MARK: - Properties

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    /// Initializes the view from a storyboard or nib.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
    }

    // MARK: - Private Methods

    private func setupViews() {
        backgroundColor = .clear
        titleLabel.numberOfLines = 0
        descriptionLabel.numberOfLines = 0

        addSubview(titleLabel)
        addSubview(descriptionLabel)
    }

    /// Sets up the constraints for the labels using Auto Layout.
    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Activate constraints for the title and description labels
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public Methods

    /// Sets up the view with data from the provided survey step and theme.
    /// - Parameters:
    ///   - surveyStep: The survey step containing question and subheader data.
    ///   - surveyTheme: The theme containing style properties for the text.
    func setupView(surveyStep: SurveyStep, surveyTheme: SurveyTheme, isRTL: Bool) {
        titleLabel.text = surveyStep.question
        titleLabel.textColor = surveyTheme.textColor
        titleLabel.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [.traitBold],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize))

        // Conditionally set description label based on the presence of subheader
        if let subHeader = surveyStep.subheader, !subHeader.isEmpty {
            descriptionLabel.text = surveyStep.subheader
            descriptionLabel.textColor = surveyTheme.textColor
            descriptionLabel.font = UIFont.matching(
                fontName: surveyTheme.fontFamily, fontWeight: [],
                fontSize: CGFloat(ThemeHandler.DefaultValues.surveyDescriptionTextSize))
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.isHidden = true
        }

        if isRTL {
            titleLabel.textAlignment = .right
            descriptionLabel.textAlignment = .right
        }
    }
}
