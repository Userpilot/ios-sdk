//
//  LikertCollectionViewCell.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.

//  This file contains the implementation of the `LikertCollectionViewCell` class,
//  which represents an individual cell in the Likert scale collection view.
//  Each cell can display either a label or an image, depending on the type of the rating item it represents,
//  and visually reflects whether it is selected using the provided survey theme.

import UIKit

// MARK: - LikertCollectionViewCell

/// A custom collection view cell used to display items in a Likert scale, either with a label or an image.
internal class LikertCollectionViewCell: UICollectionViewCell {
    private let contentLabel = UILabel()
    private let contentImageView = UIImageView()

    // MARK: - Initialization

    /// Initializes the collection view cell and sets up the UI.
    /// - Parameter frame: The frame for the collection view cell.
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    /// Required initializer that is not implemented, as the cell is created programmatically.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    /// Configures the user interface elements of the cell, including the label and image view.
    private func setupUI() {
        contentView.addSubview(contentLabel)
        contentView.addSubview(contentImageView)

        // Disable autoresizing mask and set content mode for image view
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentImageView.translatesAutoresizingMaskIntoConstraints = false
        contentImageView.contentMode = .scaleAspectFit

        // Set corner radius for the content view and enable clipping
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        // Auto Layout constraints for the label and image view
        NSLayoutConstraint.activate([
            contentImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentImageView.widthAnchor.constraint(equalToConstant: 22),
            contentImageView.heightAnchor.constraint(equalToConstant: 22),

            contentLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    // MARK: - Cell Binding

    /// Binds data from the provided `ratingItem` and `surveyTheme` to the cell's UI elements.
    /// - Parameter ratingItem: The item representing the individual rating choice in the Likert scale.
    /// - Parameter surveyTheme: The theme that defines the visual appearance of the cell.
    func bindCell(ratingItem: RatingItem, surveyTheme: SurveyTheme) {
        // Show/hide the content label based on the rating item type
        contentLabel.isHidden = ratingItem.type != .numbers
        contentLabel.text = ratingItem.title
        contentLabel.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize))

        // Show/hide the content image based on the rating item type
        contentImageView.isHidden = ratingItem.type == .numbers
        contentImageView.image = ratingItem.image

        // Update background and text colors based on selection state
        contentView.backgroundColor = ratingItem.isSelected ?
            surveyTheme.primaryColor : surveyTheme.secondaryColor

        contentImageView.tintColor = ratingItem.isSelected ?
            surveyTheme.primaryColorAsString.invertColor().color :
            surveyTheme.backgroundColorAsString.invertColor().color

        contentLabel.textColor = ratingItem.isSelected ?
            surveyTheme.primaryColorAsString.invertColor().color :
            surveyTheme.backgroundColorAsString.invertColor().color
    }
}
