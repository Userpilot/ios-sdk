//
//  UPOpenTextView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A custom view containg UITextView as input view.
//

import UIKit

internal class UPOpenTextView: UIView {

    // MARK: - Properties

    internal let titleDescriptionView = UPTitleDescriptionView()
    internal let textViewContainer = UIView()
    internal let textView = UITextView()
    internal let placeholderLabel = UILabel()
    internal let counterLabel = UILabel()
    internal let maxLength = 500

    internal var surveyStep: SurveyStep?
    internal weak var viewStateProtocol: ViewStateDelegate?

    // View Margin left, right
    internal var margin = CGFloat(0)

    // MARK: - Initializers

    init(margin: CGFloat) {
        self.margin = margin
        super.init(frame: .zero)
        setupView()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Public Methods

    /// Configures the view with a title, description, and placeholder text for the text view.
    ///
    /// This method sets up the various UI elements within the `UPOpenTextView`. It
    ///  configures the `titleDescriptionView` with the survey step and theme,
    /// sets the placeholder text for the `placeholderLabel`, and adjusts the font based on the theme settings.
    ///
    /// - Parameters:
    ///   - surveyStep: The current survey step containing the metadata and placeholder text.
    ///   - surveyTheme: The theme to be applied to the view, including font family.
    ///   - viewStateProtocol: A delegate for managing the view's state.
    func setupView(surveyStep: SurveyStep, surveyTheme: SurveyTheme, viewStateProtocol: ViewStateDelegate) {
        self.surveyStep = surveyStep
        self.viewStateProtocol = viewStateProtocol

        titleDescriptionView.setupView(surveyStep: surveyStep, surveyTheme: surveyTheme)

        placeholderLabel.text = surveyStep.metadata?.placeholder
        placeholderLabel.textColor = surveyTheme.textSecondaryColorAlpha80
        placeholderLabel.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTextSize))

        textView.textColor = surveyTheme.textColor
        textView.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTextSize))

        counterLabel.textColor = surveyTheme.textSecondaryColorAlpha80
        counterLabel.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyHighLowTextSize))
    }
}
