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
    private let cellButton = UIButton(type: .system)

    /// Callback to handle button tap
    var onTap: (() -> Void)?

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

    /// Configures the user interface elements of the cell, including the button.
    private func setupUI() {
        contentView.addSubview(cellButton)

        // Disable autoresizing mask
        cellButton.translatesAutoresizingMaskIntoConstraints = false
        cellButton.isUserInteractionEnabled = true  // Enable interaction for iOS 26 animations
        cellButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        // Disable clipping to allow scale animation to be visible
        contentView.clipsToBounds = false
        self.clipsToBounds = false
        self.layer.masksToBounds = false

        // Auto Layout constraints for the button to fill the content view
        NSLayoutConstraint.activate([
            cellButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            cellButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cellButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cellButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: - Actions

    /// Handler for button tap with haptic feedback
    @objc private func buttonTapped() {
        // Add haptic feedback
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }

        onTap?()
    }

    // MARK: - Cell Binding

    /*
     Binds data from the provided `ratingItem` and `surveyTheme` to the cell's UI elements.
     - Parameter ratingItem: The item representing the individual rating choice in the Likert scale.
     - Parameter surveyTheme: The theme that defines the visual appearance of the cell.
     */
    // swiftlint:disable:next function_body_length
    func bindCell(
        ratingItem: RatingItem,
        surveyTheme: SurveyTheme?,
        npsTheme: NPSTheme?,
        isRTL: Bool
    ) {
        if isRTL {
            self.contentView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }

        // Configure button font
        let font = UIFont.matching(
            fontName: fontFamily(surveyTheme, npsTheme),
            fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize))

        let primaryColor = primaryColor(surveyTheme, npsTheme)
        let secondaryColor = secondaryColor(surveyTheme, npsTheme)
        let selectedColor = contentSelectedColor(surveyTheme, npsTheme)
        let unselectedColor = contentUnselectedColor(surveyTheme, npsTheme)

        if #available(iOS 26.0, *) {
            // iOS 26+: Use prominentGlass for selected, use base colors when unselected
            var config = UIButton.Configuration.prominentGlass()

            if ratingItem.isSelected {
                config.baseBackgroundColor = primaryColor
                config.baseForegroundColor = selectedColor
            } else {
                config.baseBackgroundColor = secondaryColor
                config.baseForegroundColor = unselectedColor
            }

            // Set title or image based on rating item type
            if ratingItem.type == .numbers {
                config.attributedTitle = AttributedString(
                    ratingItem.title,
                    attributes: AttributeContainer([.font: font])
                )
            } else {
                config.image = ratingItem.image
                config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                    pointSize: 22)
            }
            // Use a concrete enum case to avoid ambiguity
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 8, leading: 8, bottom: 8, trailing: 8)
            cellButton.configuration = config

        } else if #available(iOS 15.0, *) {
            // iOS 15–25: Use filled or plain style
            var config: UIButton.Configuration

            if ratingItem.isSelected {
                config = UIButton.Configuration.filled()
                config.baseBackgroundColor = primaryColor
                config.baseForegroundColor = selectedColor
            } else {
                config = UIButton.Configuration.plain()
                config.baseBackgroundColor = secondaryColor
                config.baseForegroundColor = unselectedColor
            }

            // Set title or image based on rating item type
            if ratingItem.type == .numbers {
                // config.title = ratingItem.title
                config.attributedTitle = AttributedString(
                    ratingItem.title,
                    attributes: AttributeContainer([.font: font])
                )
            } else {
                config.image = ratingItem.image
                config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                    pointSize: 22)
            }

            config.background.cornerRadius = 8
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 8, leading: 8, bottom: 8, trailing: 8)
            cellButton.configuration = config

        } else {
            // Fallback for iOS 14 and earlier
            if ratingItem.type == .numbers {
                cellButton.setTitle(ratingItem.title, for: .normal)
                cellButton.setImage(nil, for: .normal)
                cellButton.titleLabel?.font = font
            } else {
                cellButton.setTitle(nil, for: .normal)
                cellButton.setImage(ratingItem.image, for: .normal)
                cellButton.imageView?.contentMode = .scaleAspectFit
            }

            cellButton.setTitleColor(
                ratingItem.isSelected ? selectedColor : unselectedColor,
                for: .normal
            )
            cellButton.tintColor = ratingItem.isSelected ? selectedColor : unselectedColor
            cellButton.backgroundColor = ratingItem.isSelected ? primaryColor : secondaryColor
            cellButton.layer.cornerRadius = 8
            cellButton.layer.masksToBounds = true
        }
    }

    private func fontFamily(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> String? {
        surveyTheme?.fontFamily ?? npsTheme?.fontFamily
    }

    private func primaryColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.primaryColor ?? npsTheme?.primaryColor ?? .black
    }

    private func secondaryColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.secondaryColor ?? npsTheme?.secondaryColor ?? .black.withAlphaComponent(0.2)
    }

    private func contentSelectedColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.primaryColorAsString.invertColor().color ?? npsTheme?.primaryColorAsString
            .invertColor().color ?? .black
    }

    private func contentUnselectedColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.textColor ?? npsTheme?.textColor ?? .black
    }
}
