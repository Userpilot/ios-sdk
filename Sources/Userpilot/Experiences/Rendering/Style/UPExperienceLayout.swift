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
    /// Between the card's sides and its content.
    static let contentMargin: CGFloat = 20
    /// Between flow elements, and above and below a card's header, body and action.
    static let spacing: CGFloat = 16
    /// The smallest height of an action button, as in the previous release.
    static let buttonHeight: CGFloat = 50
    /// The space around an action button's title.
    static let buttonPadding: CGFloat = 12
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
    /// Between the choice rows, and a choice row's smallest height.
    static let choiceSpacing: CGFloat = 8
    static let choiceMinHeight: CGFloat = 48
    /// Corner radius of choice rows and single-line inputs.
    static let fieldCornerRadius: CGFloat = 8
    /// Between a field and what opens under it: the iOS 13 country wheel.
    static let fieldSpacing: CGFloat = 8
    /// Between a rating scale and its low and high labels.
    static let scaleLabelSpacing: CGFloat = 6
    /// Between rating cells, across and down.
    static let ratingSpacing: CGFloat = 8
    /// Background opacity of a rating cell that is not filled: the theme's secondary color, primary at 20%.
    static let ratingUnfilledOpacity: CGFloat = 0.2
    /// Step progress: dots and their gap, the bar's thickness, and the opacity of dots not reached yet.
    static let dotSize: CGFloat = 6
    static let dotSpacing: CGFloat = 6
    static let progressBarHeight: CGFloat = 5
    static let progressInactiveOpacity: CGFloat = 0.2
    /// Placeholder text, and field borders and unchosen marks: the text color at these opacities.
    static let placeholderOpacity: CGFloat = 0.8
    static let secondaryTextOpacity: CGFloat = 0.2
    /// A rating scale keeps one row up to this many cells; more split evenly over two rows.
    static let ratingSingleRowMax = 5
    /// The low and high labels under a rating scale.
    static let scaleLabelSize: CGFloat = 12
    /// Height of the open-text box, and the gap above its character counter.
    static let textAreaHeight: CGFloat = 80
    static let counterSpacing: CGFloat = 4
    /// The box around a single-line input: its padding and smallest height.
    static let inputPadding: CGFloat = 12
    static let inputMinHeight: CGFloat = 50
    /// The smallest touch target: Apple's 44 pt (Android: Material's 48 dp).
    static let touchTargetSize: CGFloat = 44
    /// The close xmark symbol's point size. It draws about 13 pt across, the size Android draws its cross (Android
    /// keeps that drawn size under this name).
    static let closeGlyphSize: CGFloat = 16
    /// The room the target leaves around the close symbol on each side. The target reaches this far into the
    /// side margin, so the symbol's trailing edge lines up with the content edge below it.
    static let closeTargetInset: CGFloat = (touchTargetSize - closeGlyphSize) / 2
    /// Top padding of a full-screen header holding the close button: the symbol sits `spacing` below the edge.
    static let closeTopPadding: CGFloat = spacing - closeTargetInset
    /// Dialogs and sheets keep more room at their edges: the close symbol sits this far below the top (where
    /// Android draws its cross) and the action this far above the bottom.
    static let cardEdgeSpacing: CGFloat = 24
    /// The icon beside a flow list line, and its gap to the text.
    static let iconSize: CGFloat = 38
    static let iconTextSpacing: CGFloat = 8
    /// A centre dialog's width: this share of the safe area's width (less in landscape), up to `dialogMaxWidth`.
    static let dialogWidthFraction: CGFloat = 0.9
    static let dialogLandscapeWidthFraction: CGFloat = 0.7
    static let dialogMaxWidth: CGFloat = 600
    /// Cards other than full screen hug their content, up to this share of the space between the bars.
    static let cardMaxHeightFraction: CGFloat = 0.8
}
