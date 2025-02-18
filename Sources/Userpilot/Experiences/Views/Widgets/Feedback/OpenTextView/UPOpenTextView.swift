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
    /// configures the `titleDescriptionView` with the survey step and theme,
    /// sets the placeholder text for the `placeholderLabel`, and adjusts the font based on the theme settings.
    ///
    /// - Parameters:
    ///   - surveyStep: The current survey step containing the metadata and placeholder text.
    ///   - surveyTheme: The theme to be applied to the view, including font family.
    ///   - isRTL: Boolean indicating if the layout should be right-to-left.
    ///   - viewStateProtocol: A delegate for managing the view's state.
    func setupView(surveyStep: SurveyStep,
                   surveyTheme: SurveyTheme,
                   isListView: Bool,
                   isRTL: Bool,
                   viewStateProtocol: ViewStateDelegate) {
        self.surveyStep = surveyStep
        self.viewStateProtocol = viewStateProtocol

        titleDescriptionView.setupView(
            surveyStep: surveyStep,
            surveyTheme: surveyTheme,
            isListView: isListView,
            isRTL: isRTL)

        configureViews(placeholder: surveyStep.metadata?.placeholder,
                   textColor: surveyTheme.textColor,
                   secondaryTextColor: surveyTheme.textSecondaryColorAlpha80,
                   fontFamily: surveyTheme.fontFamily,
                   isRTL: isRTL)
    }

    /// Configures the view with a follow-up question and placeholder text.
    ///
    /// - Parameters:
    ///   - followUpQuestion: The follow-up question object containing the question text.
    ///   - placeholder: The placeholder text for the text view.
    ///   - npsTheme: The theme settings for the view.
    ///   - isRTL: Boolean indicating if the layout should be right-to-left.
    ///   - viewStateProtocol: A delegate for managing the view's state.
    func setupView(followUpQuestion: FollowUpQuestion?,
                   placeholder: String?,
                   npsTheme: NPSTheme,
                   isRTL: Bool,
                   viewStateProtocol: ViewStateDelegate) {
        guard let followUpQuestion else { return }
        self.viewStateProtocol = viewStateProtocol

        titleDescriptionView.setupView(
            title: followUpQuestion.question,
            subHeader: nil,
            npsTheme: npsTheme,
            isRTL: isRTL)

        configureViews(placeholder: placeholder,
                   textColor: npsTheme.textColor,
                   secondaryTextColor: npsTheme.textSecondaryColorAlpha80,
                   fontFamily: npsTheme.fontFamily,
                   isRTL: isRTL)
    }

    /// Applies the theme styles to the text view, placeholder label, and counter label.
    ///
    /// - Parameters:
    ///   - placeholder: The placeholder text for the text view.
    ///   - textColor: The main text color.
    ///   - secondaryTextColor: The secondary text color for the counter label.
    ///   - fontFamily: The font family to be applied.
    ///   - isRTL: Boolean indicating if the layout should be right-to-left.
    private func configureViews(placeholder: String?,
                                textColor: UIColor,
                                secondaryTextColor: UIColor,
                                fontFamily: String?,
                                isRTL: Bool) {
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = secondaryTextColor
        placeholderLabel.font = UIFont.matching(
            fontName: fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTextSize))

        textView.textColor = textColor
        textView.font = UIFont.matching(
            fontName: fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTextSize))

        counterLabel.textColor = secondaryTextColor
        counterLabel.font = UIFont.matching(
            fontName: fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyHighLowTextSize))

        if isRTL {
            counterLabel.textAlignment = .left
        }
    }

}
