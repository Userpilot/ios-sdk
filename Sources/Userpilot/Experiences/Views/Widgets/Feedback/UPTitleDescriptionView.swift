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
    func setupView(
        surveyStep: SurveyStep,
        surveyTheme: SurveyTheme,
        isListView: Bool,
        isRTL: Bool
    ) {
        configureLabels(
            title: surveyStep.question,
            showRequiredDot: isListView && surveyStep.isRequired == true,
            subHeader: surveyStep.subheader,
            textColor: surveyTheme.textColor,
            fontFamily: surveyTheme.fontFamily,
            isRTL: isRTL
        )
    }

    /// Sets up the view with data from the provided NPS theme.
    /// - Parameters:
    ///   - title: The main title text.
    ///   - subHeader: The optional subheader text.
    ///   - npsTheme: The theme containing style properties for the text.
    ///   - isRTL: A Boolean indicating whether the layout should be right-to-left.
    func setupView(
        title: String?,
        subHeader: String?,
        npsTheme: NPSTheme,
        isRTL: Bool
    ) {
        configureLabels(
            title: title,
            showRequiredDot: false,
            subHeader: subHeader,
            textColor: npsTheme.textColor,
            fontFamily: npsTheme.fontFamily,
            isRTL: isRTL
        )
    }

    // Configures the labels with the given properties.
    // - Parameters:
    //   - title: The main title text.
    //   - subHeader: The optional subheader text.
    //   - textColor: The text color for both labels.
    //   - fontFamily: The font family to be used.
    //   - isRTL: A Boolean indicating whether the layout should be right-to-left.
    // swiftlint:disable:next function_parameter_count
    private func configureLabels(
        title: String?,
        showRequiredDot: Bool,
        subHeader: String?,
        textColor: UIColor,
        fontFamily: String?,
        isRTL: Bool
    ) {
        if let title, !title.isEmpty {
            let attributedTitle = NSMutableAttributedString(
                string: title,
                attributes: [.foregroundColor: textColor]
            )

            if showRequiredDot {
                let redStar = NSAttributedString(
                    string: " *",
                    attributes: [.foregroundColor: UIColor.red]
                )
                attributedTitle.append(redStar)
            }

            titleLabel.attributedText = attributedTitle
        } else {
            titleLabel.text = title
            titleLabel.textColor = textColor
        }

        titleLabel.font = UIFont.matching(
            fontName: fontFamily, fontWeight: [.traitBold],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize)
        )

        if let subHeader, !subHeader.isEmpty {
            descriptionLabel.text = subHeader
            descriptionLabel.textColor = textColor
            descriptionLabel.font = UIFont.matching(
                fontName: fontFamily, fontWeight: [],
                fontSize: CGFloat(ThemeHandler.DefaultValues.surveyDescriptionTextSize)
            )
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
