//
//  UPExperienceLayout.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shared spacing and text sizes for the experience renderer.
//

import CoreGraphics

/// Shared element rhythm; native card margins remain separate from authored content.
/// Android keeps the same values under the same names in `UPExperienceLayout`; change them together.
internal enum UPExperienceLayout {
    /// Between flow elements, and above and below a card's header, body and action.
    static let spacing: CGFloat = 16
    static let buttonHeight: CGFloat = 50
    /// Text that used the system's default font: inputs, chips and placeholders.
    static let bodySize: CGFloat = 16
    /// Text that used `.footnote`: scale labels and character counters.
    static let footnoteSize: CGFloat = 13

    /// Between the questions of a list survey: well above `controlSpacing`, so each title reads with its field.
    static let questionSpacing: CGFloat = 32
    /// Between a question's title and its description.
    static let titleSpacing: CGFloat = 4
    /// Between a question's text and its answer control, whatever the control.
    static let controlSpacing: CGFloat = 8
    /// Between the choice rows.
    static let choiceSpacing: CGFloat = 8
    /// Between a field and what opens under it: the iOS 13 country wheel.
    static let fieldSpacing: CGFloat = 8
    /// Between a rating scale and its low and high labels.
    static let scaleLabelSpacing: CGFloat = 6
    /// Between rating cells, across and down.
    static let ratingSpacing: CGFloat = 8
    /// Background opacity of a rating cell that is not filled.
    static let ratingUnfilledOpacity: Double = 0.1
    /// Height of the open-text box, and the gap above its character counter.
    static let textAreaHeight: CGFloat = 80
    static let counterSpacing: CGFloat = 4
    /// The icon beside a flow list line, and its gap to the text.
    static let iconSize: CGFloat = 38
    static let iconTextSpacing: CGFloat = 8
    /// Cards other than full screen hug their content, up to this share of the space between the bars.
    static let cardMaxHeightFraction: CGFloat = 0.8
}
