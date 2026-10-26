//
//  SurveyStep+Rating.swift
//  Userpilot SDK
//
//  Created by Userpilot on 26/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps a Likert step to the rating cells the renderer draws, with the established asset mapping.
//

import Foundation

internal extension SurveyStep {
    /// One cell per point of the range, titled from one; icons follow the step's scale type.
    var ratingItems: [UPRatingItem] {
        let range = metadata?.range ?? ThemeHandler.DefaultValues.surveyDefaultLikertViewCount
        let type = metadata?.type ?? .numbers
        return (0..<range).map { index in
            UPRatingItem(title: "\(index + 1)", imageName: ratingIconName(type: type, index: index), type: type)
        }
    }

    private func ratingIconName(type: LikertViewType, index: Int) -> String? {
        switch type {
        case .numbers: return nil
        case .stars: return "userpilot_icon_star"
        case .hearts: return "userpilot_icon_heart"
        // Unsupported ranges past ten get no icon rather than crashing.
        case .emojis: return smileIconNames(range: metadata?.range ?? 10)[safe: index]
        }
    }

    /// The native asset mapping; the ten-point scale runs one to ten, as on Android.
    private func smileIconNames(range: Int) -> [String] {
        // Shorter scales use a spread of the ten faces, from sad to happy.
        switch range {
        case 3:
            return ["userpilot_icon_smile_three", "userpilot_icon_smile_five", "userpilot_icon_smile_nine"]
        case 5:
            return [
                "userpilot_icon_smile_three", "userpilot_icon_smile_five", "userpilot_icon_smile_six",
                "userpilot_icon_smile_nine", "userpilot_icon_smile_ten"
            ]
        case 7:
            return [
                "userpilot_icon_smile_one", "userpilot_icon_smile_three", "userpilot_icon_smile_five",
                "userpilot_icon_smile_six", "userpilot_icon_smile_seven", "userpilot_icon_smile_nine",
                "userpilot_icon_smile_ten"
            ]
        default:
            return ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
                .map { "userpilot_icon_smile_\($0)" }
        }
    }
}
