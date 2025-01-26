//
//  UPLikertView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This custom view represents a Likert scale used in surveys, where users can rate a statement.
//  It includes dynamic item width calculation based on the screen width and the number of items,
//  and supports various configuration for displaying rating items, as well as low and high score labels.
//

import UIKit

internal class UPLikertView: UIView {

    // MARK: - UI Components

    // The title and description view for the survey
    internal let titleDescriptionView = UPTitleDescriptionView()

    // Collection view to display the rating items
    internal let collectionView: UICollectionView = {
        let layout = CenteredCollectionViewLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 8

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        return collectionView
    }()

    // Label displaying the low score text (e.g. "Strongly Disagree")
    internal let lowScoreTextLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.textColor = UIColor.gray43
        return textLabel
    }()

    // Label displaying the high score text (e.g. "Strongly Agree")
    internal let highScoreTextLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.textColor = UIColor.gray43
        textLabel.textAlignment = .right
        return textLabel
    }()

    // List of rating items (the options users can select)
    internal var ratingItems: [RatingItem] = []

    // Width of each rating item
    internal var itemWidth: CGFloat = 40

    // Survey step and theme data passed for configuration
    internal var surveyStep: SurveyStep?
    internal var surveyTheme: SurveyTheme?

    // View state delegate for managing view state changes
    internal weak var viewStateProtocol: ViewStateDelegate?

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViewHierarchy()
        configureCollectionView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup View

    /// Set up the view with the survey step, survey theme, and view state protocol.
    func setupView(surveyStep: SurveyStep, surveyTheme: SurveyTheme, viewStateProtocol: ViewStateDelegate) {
        self.surveyStep = surveyStep
        self.surveyTheme = surveyTheme
        self.viewStateProtocol = viewStateProtocol

        // Set up the title and description view
        titleDescriptionView.setupView(surveyStep: surveyStep, surveyTheme: surveyTheme)

        // Bind the low and high score labels
        bindLowHeightTexts()

        // Populate the rating items based on the survey step data
        ratingItems = RatingItem.fillList(surveyStep: surveyStep)

        // Calculate and set the item width based on screen width and number of items
        calculateItemWidth()

        // Reload the collection view data
        collectionView.reloadData()
    }

    // MARK: - Item Width Calculation

    /// Calculates the width of each item in the Likert scale collection view based on screen width and number of items.
    private func calculateItemWidth() {
        // Handling the case where there are exactly 10 items
        if ratingItems.count == 10 {
            let screenWidth = UIScreen.main.bounds.width - 40
            let minItemWidth: CGFloat = 48
            let itemCountPerRow = max(1, Int(screenWidth / minItemWidth))
            if itemCountPerRow < 10 {
                let screenWidth = UIScreen.main.bounds.width - 40 - (6 * 8)
                itemWidth = screenWidth / CGFloat(7)
                collectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
            } else {
                let screenWidth = UIScreen.main.bounds.width - 40
                let totalSpacing = CGFloat(ratingItems.count - 1) * 8
                let availableWidth = screenWidth - totalSpacing
                itemWidth = availableWidth / CGFloat(ratingItems.count)
            }
        } else {
            // Handle case when the number of items is less than 10
            let screenWidth = Int(UIScreen.main.bounds.width) - 40 - (8 * ratingItems.count)
            itemWidth = CGFloat(screenWidth / ratingItems.count)
        }
    }
}
