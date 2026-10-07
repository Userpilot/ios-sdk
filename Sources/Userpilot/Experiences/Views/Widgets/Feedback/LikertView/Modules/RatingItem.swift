//
//  RatingItem.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  This file contains the `RatingItem` struct, which represents an individual item in the Likert scale,
//  along with utility functions for generating a list of rating items and fetching associated icons
//  based on metadata provided in a survey step.
//

import Foundation
import UIKit

// MARK: - RatingItem

/// One Likert scale item with its title, image and selection state.
internal struct RatingItem {
    var type: LikertViewType
    var title: String
    var image: UIImage?
    var isSelected: Bool

    // MARK: - Static Methods

    /// Fills a list of `RatingItem` based on the provided survey step metadata.
    /// - Parameter surveyStep: The survey step containing metadata about the Likert scale.
    /// - Returns: An array of `RatingItem` objects.
    static func fillList(surveyStep: SurveyStep) -> [RatingItem] {
        let range = surveyStep.metadata?.range ?? ThemeHandler.DefaultValues.surveyDefaultLikertViewCount
        return (0..<range).map { index in
            RatingItem(
                type: surveyStep.metadata?.type ?? .numbers,
                title: "\(index + 1)",
                image: getIcon(metadata: surveyStep.metadata, index: index),
                isSelected: false
            )
        }
    }

    static func fillList(_ answer: Int) -> [RatingItem] {
        let range = ThemeHandler.DefaultValues.npsDefaultLikertViewCount
        return (0..<range).map { index in
            RatingItem(
                type: .numbers,
                title: "\(index)",
                image: nil,
                isSelected: index < answer
            )
        }
    }

    // MARK: - Private Methods

    /// Fetches the appropriate icon for a given index and metadata type.
    /// - Parameter metadata: The metadata that provides the type of Likert scale (numbers, stars, hearts, etc.).
    /// - Parameter index: The index of the item in the Likert scale.
    /// - Returns: A `UIImage` representing the icon for the given index and metadata type.
    private static func getIcon(
        metadata: Metadata?,
        index: Int
    ) -> UIImage? {
        guard let metadataType = metadata?.type else { return UIImage() }

        if metadataType == .numbers {
            return UIImage() // Default empty image for number type.
        }

        switch metadataType {
        case .stars:
            return UIImage.userpilotImage(named: "userpilot_icon_star")
        case .hearts:
            return UIImage.userpilotImage(named: "userpilot_icon_heart")
        default:
            return getSmileIcon(for: index, availableRange: metadata?.range ?? 10)
        }
    }

    /// Returns the appropriate smiley icon for a given index and available range.
    /// - Parameter index: The index of the item in the Likert scale.
    /// - Parameter availableRange: The total number of items in the scale (e.g., 3, 5, 7, 10).
    /// - Returns: A `UIImage` representing the smiley icon for the given index.
    private static func getSmileIcon(
        for index: Int,
        availableRange: Int
    ) -> UIImage? {
        // Preserve the native asset mapping, including the legacy ten-point scale ordering.
        let names: [String]
        switch availableRange {
        case 3:
            names = ["userpilot_icon_smile_three", "userpilot_icon_smile_five", "userpilot_icon_smile_nine"]
        case 5:
            names = [
                "userpilot_icon_smile_three", "userpilot_icon_smile_five", "userpilot_icon_smile_six",
                "userpilot_icon_smile_nine", "userpilot_icon_smile_ten"
            ]
        case 7:
            names = [
                "userpilot_icon_smile_one", "userpilot_icon_smile_three", "userpilot_icon_smile_five",
                "userpilot_icon_smile_six", "userpilot_icon_smile_seven", "userpilot_icon_smile_nine",
                "userpilot_icon_smile_ten"
            ]
        default:
            names = [
                "userpilot_icon_smile_one", "userpilot_icon_smile_two", "userpilot_icon_smile_three",
                "userpilot_icon_smile_four", "icon_smile_five", "userpilot_icon_smile_six",
                "userpilot_icon_smile_seven", "userpilot_icon_smile_ten", "userpilot_icon_smile_eight",
                "userpilot_icon_smile_ten"
            ]
        }
        guard let name = names[safe: index] else { return UIImage() }
        return UIImage.userpilotImage(named: name)
    }
}
