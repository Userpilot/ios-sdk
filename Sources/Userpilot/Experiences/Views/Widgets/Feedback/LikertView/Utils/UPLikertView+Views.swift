//
//  UPLikertView+ViewsExt.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This extension contains methods for setting up the view hierarchy, configuring the collection view,
//  and binding the low/high score text labels in the Likert scale view. It also handles UI layout
//  and setting of constraints using Auto Layout.
//

import UIKit

internal extension UPLikertView {

    // MARK: - Setup View Hierarchy

    /// Sets up the view hierarchy by adding subviews and applying constraints.
    func setupView() {
        backgroundColor = .clear
        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        // Stack view for the low and high score text labels
        let bottomRowStackView = UIStackView(arrangedSubviews: [lowScoreTextLabel, highScoreTextLabel])
        bottomRowStackView.axis = .horizontal
        bottomRowStackView.spacing = 8
        bottomRowStackView.alignment = .center
        bottomRowStackView.distribution = .fillProportionally
        bottomRowStackView.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews to the main view
        addSubview(titleDescriptionView)
        addSubview(collectionView)
        addSubview(bottomRowStackView)

        // Apply Auto Layout constraints
        NSLayoutConstraint.activate([
            titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
            titleDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            titleDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: margin.negative),

            collectionView.topAnchor.constraint(equalTo: titleDescriptionView.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: margin.negative),

            bottomRowStackView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 6),
            bottomRowStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            bottomRowStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: margin.negative),
            bottomRowStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Configure Collection View

    /// Registers the collection view cell and sets its data source and delegate.
    func configureCollectionView() {
        collectionView.register(LikertCollectionViewCell.self,
        forCellWithReuseIdentifier: LikertCollectionViewCell.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
    }

    // MARK: - Bind Low and High Score Texts

    /// Binds the low and high score texts to their respective labels based on the survey step and theme.
    func bindLowHeightTexts(
        lowScore: String?,
        highScore: String?,
        textColor: UIColor,
        fontFamily: String?
    ) {
        // Set low score text and properties
        lowScoreTextLabel.text = lowScore
        lowScoreTextLabel.textColor = textColor
        lowScoreTextLabel.font = UIFont.matching(
            fontName: fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyHighLowTextSize))

        // Set high score text and properties
        highScoreTextLabel.text = highScore
        highScoreTextLabel.textColor = textColor
        highScoreTextLabel.font = UIFont.matching(
            fontName: fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyHighLowTextSize))
    }
}
