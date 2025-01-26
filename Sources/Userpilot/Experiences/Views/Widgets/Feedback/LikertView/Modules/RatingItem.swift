//
//  RatingItem.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  This file contains the `RatingItem` struct, which represents an individual item in the Likert scale,
//  along with utility functions for generating a list of rating items and fetching associated icons
//  based on metadata provided in a survey step.
//

import Foundation
import UIKit

// swiftlint:disable all

// MARK: - RatingItem

/// A struct representing an individual item in the Likert scale (a survey item with a title, image, and selection state).
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

    // MARK: - Private Methods

    /// Fetches the appropriate icon for a given index and metadata type.
    /// - Parameter metadata: The metadata that provides the type of Likert scale (numbers, stars, hearts, etc.).
    /// - Parameter index: The index of the item in the Likert scale.
    /// - Returns: A `UIImage` representing the icon for the given index and metadata type.
    private static func getIcon(metadata: Metadata?, index: Int) -> UIImage? {
        guard let metadataType = metadata?.type else { return UIImage() }

        if metadataType == .numbers {
            return UIImage() // Default empty image for number type.
        }

        switch metadataType {
        case .stars:
            return UIImage.userpilotImage(named: "icon_star")
        case .hearts:
            return UIImage.userpilotImage(named: "icon_heart")
        default:
            // Return icons based on the range of items (3, 5, 7, etc.).
            switch metadata?.range {
            case 3:
                return getSmileIcon(for: index, availableRange: 3)
            case 5:
                return getSmileIcon(for: index, availableRange: 5)
            case 7:
                return getSmileIcon(for: index, availableRange: 7)
            default:
                return getSmileIcon(for: index, availableRange: 10)
            }
        }
    }

    /// Returns the appropriate smiley icon for a given index and available range.
    /// - Parameter index: The index of the item in the Likert scale.
    /// - Parameter availableRange: The total number of items in the scale (e.g., 3, 5, 7, 10).
    /// - Returns: A `UIImage` representing the smiley icon for the given index.
    private static func getSmileIcon(for index: Int, availableRange: Int) -> UIImage? {
        switch availableRange {
        case 3:
            switch index {
            case 0: return UIImage.userpilotImage(named: "icon_smile_three")
            case 1: return UIImage.userpilotImage(named: "icon_smile_five")
            case 2: return UIImage.userpilotImage(named: "icon_smile_nine")
            default: return UIImage()
            }
        case 5:
            switch index {
            case 0: return UIImage.userpilotImage(named: "icon_smile_three")
            case 1: return UIImage.userpilotImage(named: "icon_smile_five")
            case 2: return UIImage.userpilotImage(named:  "icon_smile_six")
            case 3: return UIImage.userpilotImage(named: "icon_smile_nine")
            case 4: return UIImage.userpilotImage(named: "icon_smile_ten")
            default: return UIImage()
            }
        case 7:
            switch index {
            case 0: return UIImage.userpilotImage(named: "icon_smile_one")
            case 1: return UIImage.userpilotImage(named: "icon_smile_three")
            case 2: return UIImage.userpilotImage(named: "icon_smile_five")
            case 3: return UIImage.userpilotImage(named: "icon_smile_six")
            case 4: return UIImage.userpilotImage(named: "icon_smile_seven")
            case 5: return UIImage.userpilotImage(named: "icon_smile_nine")
            case 6: return UIImage.userpilotImage(named: "icon_smile_ten")
            default: return UIImage()
            }
        default:
            // Default case for 10 smiley icons.
            return getSmileIcon(for: index, availableRange: 10)
        }
    }
}

// swiftlint:enable all
