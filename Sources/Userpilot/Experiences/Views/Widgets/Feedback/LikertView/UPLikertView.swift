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
    internal var npsTheme: NPSTheme?
    internal var isRTL = false

    // View state delegate for managing view state changes
    internal weak var viewStateProtocol: ViewStateDelegate?

    // View Margin left, right
    internal var margin = CGFloat(0)

    // MARK: - Initializers

    init(margin: CGFloat) {
        self.margin = margin
        super.init(frame: .zero)
        setupView()
        configureCollectionView()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        configureCollectionView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup View

    // Set up the view with the survey step, survey theme, and view state protocol.
    // swiftlint:disable:next function_parameter_count
    func setupView(
        surveyStep: SurveyStep,
        surveyTheme: SurveyTheme,
        isListView: Bool,
        isDialog: Bool,
        isRTL: Bool,
        viewStateProtocol: ViewStateDelegate
    ) {
        self.surveyStep = surveyStep
        self.surveyTheme = surveyTheme
        self.isRTL = isRTL
        self.viewStateProtocol = viewStateProtocol

        // Set up the title and description view
        titleDescriptionView.setupView(
            surveyStep: surveyStep,
            surveyTheme: surveyTheme,
            isListView: isListView,
            isRTL: isRTL)

        // Bind the low and high score labels
        bindLowHeightTexts(
            lowScore: surveyStep.metadata?.lowScore,
            highScore: surveyStep.metadata?.highScore,
            textColor: surveyTheme.textColor,
            fontFamily: surveyTheme.fontFamily)

        // Populate the rating items based on the survey step data
        ratingItems = RatingItem.fillList(surveyStep: surveyStep)

        // Calculate and set the item width based on screen width and number of items
        calculateItemWidth(isDialog: isDialog)

        if isRTL {
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
            lowScoreTextLabel.textAlignment = .right
            highScoreTextLabel.textAlignment = .left
        }

        // Reload the collection view data
        collectionView.reloadData()
    }

    /// Set up the view with the survey step, survey theme, and view state protocol.
    func setupView(
        npsStep: NPSStep,
        npsTheme: NPSTheme,
        isRTL: Bool,
        answer: Int,
        viewStateProtocol: ViewStateDelegate
    ) {
        self.npsTheme = npsTheme
        self.isRTL = isRTL
        self.viewStateProtocol = viewStateProtocol

        // Set up the title and description view
        titleDescriptionView.setupView(title: npsStep.survey.question, subHeader: nil, npsTheme: npsTheme, isRTL: isRTL)

        // Bind the low and high score labels
        bindLowHeightTexts(
            lowScore: npsStep.survey.lowScore,
            highScore: npsStep.survey.highScore,
            textColor: npsTheme.textColor,
            fontFamily: npsTheme.fontFamily)

        // Populate the rating items based on the survey step data
        ratingItems = RatingItem.fillList(answer)

        // Calculate and set the item width based on screen width and number of items
        calculateItemWidth(isDialog: false)

        if isRTL {
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
            lowScoreTextLabel.textAlignment = .right
            highScoreTextLabel.textAlignment = .left
        }

        // Reload the collection view data
        collectionView.reloadData()
    }

    // MARK: - Item Width Calculation

    /// Calculates the width of each item in the Likert scale collection view based on screen width and number of items.
    private func calculateItemWidth(isDialog: Bool) {
        // Handling the case where there are exactly 10 items
        let margin = CGFloat(40 + (isDialog ? 50 : 0))
        if ratingItems.count == 10 || ratingItems.count == 11 {
            let screenWidth = UIScreen.main.bounds.width - margin
            let minItemWidth: CGFloat = 48
            let itemCountPerRow = max(1, Int(screenWidth / minItemWidth))
            if itemCountPerRow < 10 {
                let screenWidth = UIScreen.main.bounds.width - margin - (6 * 8)
                itemWidth = screenWidth / CGFloat(7)
                collectionView.heightAnchor.constraint(equalToConstant: 90).isActive = true
            } else {
                let screenWidth = UIScreen.main.bounds.width - margin
                let totalSpacing = CGFloat(ratingItems.count - 1) * 8
                let availableWidth = screenWidth - totalSpacing
                itemWidth = availableWidth / CGFloat(ratingItems.count)
                collectionView.heightAnchor.constraint(equalToConstant: 40).isActive = true
            }
        } else {
            // Handle case when the number of items is less than 10
            let screenWidth = Int(UIScreen.main.bounds.width) - Int(margin) - (8 * (ratingItems.count - 1))
            itemWidth = CGFloat(screenWidth / ratingItems.count)
            collectionView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
    }

    func collectionViewHeight() -> Int {
        return Int(collectionView.frame.height)
    }
}
