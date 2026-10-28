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
    /// Text that used the system's default font: inputs, placeholders and rating numbers.
    static let bodySize: CGFloat = 16
    /// Text that used `.footnote`: character counters.
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
    /// Background opacity of a rating cell that is not filled: the theme's secondary color, primary at 20%.
    static let ratingUnfilledOpacity: CGFloat = 0.2
    /// A rating scale keeps one row up to this many cells; more split evenly over two rows.
    static let ratingSingleRowMax = 5
    /// The low and high labels under a rating scale.
    static let scaleLabelSize: CGFloat = 12
    /// Height of the open-text box, and the gap above its character counter.
    static let textAreaHeight: CGFloat = 80
    static let counterSpacing: CGFloat = 4
    /// The smallest touch target: Apple's 44 pt (Android: Material's 48 dp).
    static let touchTargetSize: CGFloat = 44
    /// The close xmark symbol's point size (Android draws a cross of the same size).
    static let closeGlyphSize: CGFloat = 16
    /// Top padding of a header holding the close button. The target already holds the symbol half its spare
    /// room below its top, so the symbol sits `spacing` below the card edge: the same space as below the last
    /// item, as on Android.
    static let closeTopPadding: CGFloat = spacing - (touchTargetSize - closeGlyphSize) / 2
    /// The icon beside a flow list line, and its gap to the text.
    static let iconSize: CGFloat = 38
    static let iconTextSpacing: CGFloat = 8
    /// Cards other than full screen hug their content, up to this share of the space between the bars.
    static let cardMaxHeightFraction: CGFloat = 0.8
}
