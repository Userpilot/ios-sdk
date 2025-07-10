//
//  UPMultipleChoiceView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A custom view for presenting multiple choice questions in a survey.
//

import UIKit

internal class UPMultipleChoiceView: UIView {

    // MARK: - Properties

    internal let titleDescriptionView = UPTitleDescriptionView()
    internal let tableView = UITableView()

    internal var surveyStep: SurveyStep?
    internal var surveyTheme: SurveyTheme?
    internal var isRTL = false
    internal weak var viewStateProtocol: ViewStateDelegate?

    internal var choices = [Choice]()

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

    /// Configures the view with survey data and UI elements.
    ///
    /// This method sets up the view by configuring the title description view, loading choices from
    /// the survey metadata, and updating the table view with the list of choices. If an "Other" option
    /// is enabled in the metadata, it will be added to the choices. The table view's height is dynamically
    /// adjusted based on the number of items.
    ///
    /// - Parameters:
    ///   - surveyStep: The survey step containing question metadata and configurations.
    ///   - surveyTheme: The theme to apply to the survey, including fonts and colors.
    ///   - viewStateProtocol: A delegate for managing the state of the view.
    func setupView(
        surveyStep: SurveyStep,
        surveyTheme: SurveyTheme,
        isListView: Bool,
        isRTL: Bool,
        viewStateProtocol: ViewStateDelegate
    ) {
        self.surveyStep = surveyStep
        self.surveyTheme = surveyTheme
        self.isRTL = isRTL
        self.viewStateProtocol = viewStateProtocol

        // Configure the title description view with survey step and theme.
        titleDescriptionView.setupView(
            surveyStep: surveyStep,
            surveyTheme: surveyTheme,
            isListView: isListView,
            isRTL: isRTL)

        // Load choices from the survey metadata.
        choices.append(contentsOf: surveyStep.metadata?.choices ?? [])

        // Add the "Other" choice if it is enabled in the metadata.
        if surveyStep.metadata?.otherChoice?.enabled == true {
            let otherChoice = Choice(
                id: ThemeHandler.DefaultValues.surveyOtherChoice,
                value: surveyStep.metadata?.otherChoice?.placeholder,
                isSelected: false
            )
            choices.append(otherChoice)
        }

        // Reload the table view without animation.
        UIView.performWithoutAnimation {
            tableView.reloadData()
        }

        // Adjust the table view height based on the content size.
        // let itemCount = self.choices.count
        // let height = self.tableView.contentSize.height ?? CGFloat(55 * itemCount)
        let height = self.tableView.contentSize.height
        self.tableView.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    func choicesCount() -> Int {
        return choices.count
    }
}
