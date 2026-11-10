//
//  UPExperienceStyle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 10/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The theme of what is on screen, resolved once: the values every widget draws with.
//

import UIKit

/// The theme of what is on screen, resolved once from its flow, survey or NPS theme, so every widget draws with the
/// same values and no default color leaks into customer content. The SwiftUI environment carries it
/// (`\.experienceStyle`); Android resolves the same fields under the same names (`LocalExperienceStyle`).
internal struct UPExperienceStyle {
    var background: UIColor = .white
    var text: UIColor = .black
    var title: UIColor = .black
    var primary: UIColor = .black
    var buttonText: UIColor = .white
    var buttonRadius: CGFloat = 0
    var border: UIColor = .clear
    var borderWidth: CGFloat = 0
    var fontName: String?
    var progress = false
    var dots = false
    /// The bar and the dots reached so far.
    var progressColor: UIColor = .black
    /// Dots not reached yet, drawn at `UPExperienceLayout.progressInactiveOpacity`.
    var inactiveProgressColor: UIColor = .black
    var cardRadius: CGFloat = 24

    /// Placeholder text in every input: the text color at 80%, as in the previous release.
    var placeholder: UIColor { text.withAlphaComponent(UPExperienceLayout.placeholderOpacity) }
    /// Field borders and unchosen marks: the text color at 20%.
    var secondaryText: UIColor { text.withAlphaComponent(UPExperienceLayout.secondaryTextOpacity) }
}

extension ExperienceTheme {
    /// A flow (carousel page or slideout): its button colors, and progress in the authored color or the
    /// background's opposite, dots not reached yet faded.
    var experienceStyle: UPExperienceStyle {
        let progress = isStepsProgressColorManual ? stepsProgressColor : backgroundColorAsString.invertColor().color
        return UPExperienceStyle(
            background: backgroundColor, text: textColor, title: titleTextColor, primary: buttonBackgroundColor,
            buttonText: buttonTextColor, buttonRadius: buttonBorderRadius, border: buttonBorderColor,
            borderWidth: buttonBorderWidth, fontName: fontFamily, progress: isStepsProgressEnabled, dots: true,
            progressColor: progress, inactiveProgressColor: progress)
    }
}

extension SurveyTheme {
    /// A survey or its thank-you: buttons in the primary color with its black or white opposite as text.
    var experienceStyle: UPExperienceStyle {
        UPExperienceStyle(
            background: backgroundColor, text: textColor, title: textColor, primary: primaryColor,
            buttonText: primaryColorAsString.invertColor().color, buttonRadius: 12, fontName: fontFamily,
            progress: isStepsProgressEnabled, dots: isStepsProgressBallType, progressColor: stepsProgressColor,
            inactiveProgressColor: isStepsProgressColorManual
                ? stepsProgressColor : backgroundColorAsString.invertColor().color,
            cardRadius: borderRadius)
    }
}

extension NPSTheme {
    /// An NPS: like a survey, with progress in the authored color or the primary, as both previous releases drew
    /// the NPS bar.
    var experienceStyle: UPExperienceStyle {
        UPExperienceStyle(
            background: backgroundColor, text: textColor, title: textColor, primary: primaryColor,
            buttonText: primaryColorAsString.invertColor().color, buttonRadius: 12, fontName: fontFamily,
            progress: isStepsProgressEnabled, dots: isStepsProgressBallType,
            progressColor: isStepsProgressColorManual ? stepsProgressColor : primaryColor,
            inactiveProgressColor: isStepsProgressColorManual
                ? stepsProgressColor : backgroundColorAsString.invertColor().color,
            cardRadius: borderRadius)
    }
}
