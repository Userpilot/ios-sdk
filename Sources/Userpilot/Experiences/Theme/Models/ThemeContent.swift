//
//  ThemeContent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Represents the configuration and content for experiences base theme.
//

import Foundation
import UIKit

// MARK: - ThemeResponse

internal struct ThemeContent: Codable {
    let id: Int?
    let title: String?
    let themeData: ThemeData?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case themeData = "theme_data"
    }
}

// MARK: - ThemeData

internal struct ThemeData: Codable {
    let carousel: ExperienceTheme?
    let slideOut: ExperienceTheme?
    let survey: SurveyTheme?

    /// Styling for anchored tooltips.
    ///
    /// It styles the card's close button, title, description, action button and
    /// step progress, plus the backdrop. It is not read from `slideOut`: sharing a
    /// branch shares its values, so restyling a slideout would restyle every tooltip.
    ///
    /// Absent data degrades safely rather than rendering nothing: every field
    /// falls through step → global → the computed defaults on `ExperienceTheme`,
    /// which give a black backdrop at 40%. So tooltips render correctly on day
    /// one, before the backend sends a `tooltip` block at all.
    let tooltip: ExperienceTheme?

    /// The mobile theme's base for every Flow step (modal, slideout and tooltip). The key is `flow`,
    /// not `flows`. A theme without it styles each Flow step from that step type's own section.
    let flow: ExperienceTheme?

    private enum CodingKeys: String, CodingKey {
        case carousel
        case slideOut = "slideout"
        case survey
        case tooltip
        case flow
    }

    /// Builds theme data directly, for the merge and for fixtures.
    ///
    /// Declared explicitly so `tooltip` and `flow` can default to `nil`: Swift gives an
    /// optional stored property a default argument only when it is a `var`, and
    /// these are all `let`. Without this, adding a branch would force every
    /// existing call site to pass an argument it does not care about.
    init(
        carousel: ExperienceTheme?,
        slideOut: ExperienceTheme?,
        survey: SurveyTheme?,
        tooltip: ExperienceTheme? = nil,
        flow: ExperienceTheme? = nil
    ) {
        self.carousel = carousel
        self.slideOut = slideOut
        self.survey = survey
        self.tooltip = tooltip
        self.flow = flow
    }

    /// `middle` centres the slideout like `center`.
    var isDialogExperience: Bool {
        slideOut?.general?.contentAlignment == .center || slideOut?.general?.contentAlignment == .middle
    }

    var isDialogSurvey: Bool {
        survey?.general?.position == .center
    }

}

// MARK: - Extension to deserialize a String into a ThemeResponse object

internal extension String {
    /// Converts a JSON string into a `ThemeContent`; a failure is logged through `logger` and returns `nil`.
    func toMobileTheme(logger: Logging? = nil) -> ThemeContent? {
        toObject(logger: logger)
    }
}
