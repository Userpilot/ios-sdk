//
//  UPSingleInputView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A custom view that provides a single input field for the user, along with additional
//  elements like country selection, date picker, and more.
//

import UIKit

internal class UPSingleInputView: UIView {

    // MARK: - Properties

    /// The parent view controller
    internal var parentViewController: UIViewController?

    /// Title and description view
    internal let titleDescriptionView = UPTitleDescriptionView()

    /// Text field for input
    internal let textField = UITextField()

    /// Stack view for country-related UI elements
    internal let countryStackView = UIStackView()
    internal let countrySelectorButton = UIButton()
    internal let downArrowButton = UIButton(type: .custom)
    internal let separatorView = UIView()

    /// Button to show a calendar icon
    internal let calendarIconButton = UIButton(type: .custom)

    /// countries popup menu
    internal var countryPickerPopupMenu: CountryPickerPopupMenu?

    // The type of text input
    internal var textType: SingleTextType = .general {
        didSet {
            configureTextField(for: textType)
        }
    }

    /// Survey step containing data for the input view
    internal var surveyStep: SurveyStep?

    /// Theme that defines the styles for the input view
    internal var surveyTheme: SurveyTheme?

    /// Delegate for handling view state changes
    internal weak var viewStateProtocol: ViewStateDelegate?

    /// Survey step containing data for the input view
    internal var isRTL = false

    // View Margin left, right
    internal var margin = CGFloat(0)

    // MARK: - Initializers

    init(margin: CGFloat) {
        self.margin = margin
        super.init(frame: .zero)
        setupView()
    }

    /// Initializes the view with a specified frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    /// Initializes the view from a storyboard or nib.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Public Methods

    /// Sets up the view with the provided survey step, theme, view state delegate, and parent view controller.
    /// - Parameters:
    ///   - surveyStep: The survey step containing data to display.
    ///   - surveyTheme: The theme to apply styles from.
    ///   - viewStateProtocol: The delegate for handling view state changes.
    ///   - parentViewController: The parent view controller managing this view.
    func setupView(
        surveyStep: SurveyStep,
        surveyTheme: SurveyTheme,
        isRTL: Bool,
        viewStateProtocol: ViewStateDelegate,
        parentViewController: UIViewController
    ) {
        self.surveyStep = surveyStep
        self.isRTL = isRTL
        self.viewStateProtocol = viewStateProtocol
        self.parentViewController = parentViewController

        titleDescriptionView.setupView(surveyStep: surveyStep, surveyTheme: surveyTheme, isRTL: isRTL)

        textField.setPlaceholder(text: surveyStep.metadata?.placeholder ?? "",
                                 color: surveyTheme.textSecondaryColorAlpha80)
        textField.textColor = surveyTheme.textColor
        textField.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTextSize))

        textType = surveyStep.metadata?.inputType ?? .general

        if isRTL {
            textField.textAlignment = .right
        }
    }
}
