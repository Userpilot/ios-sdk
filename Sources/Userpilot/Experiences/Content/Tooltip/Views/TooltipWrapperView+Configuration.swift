//
//  TooltipWrapperView+Configuration.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Applies a tooltip step's theme and `presentation` block to the view.
//
//  Receives resolved content and theme inputs; interaction callbacks stay with
//  the controller that owns their terminal paths.
//

import UIKit

// MARK: - Configuration

internal extension TooltipWrapperView {

    /// Applies everything the renderer needs from the payload and the theme.
    ///
    /// No card border is applied: `ExperienceTheme` has no card-border field —
    /// its `button.borderColor` is the *button's* — so there is nothing correct
    /// to draw one from. `applyBorder(color:width:)` exists and is correct, but
    /// wiring it needs a theme field *and* insetting the card's frame by
    /// `contentWrapperView.layoutMargins`; without that second half the layout
    /// engine's border guard inverts from a collapse-preventer into a growth
    /// driver.
    ///
    /// A positive `dimFadeDuration` blends the dim from the previous step's,
    /// for a Flow overlay that stays on screen between steps.
    func configure(presentation: StepPresentation?, theme: ExperienceTheme, dimFadeDuration: TimeInterval = 0) {
        let previousDim = backdropView.backgroundColor
        applyStyle(theme: theme)
        fadeDim(from: previousDim, duration: dimFadeDuration)

        preferredPlacement = presentation.preferredPlacement
        distanceFromTarget = Constants.Theme.tooltipGap
        pointerSize = presentation.pointerSize

        let margin = Constants.Theme.tooltipEdgeMargin
        layoutMargins = UIEdgeInsets(
            top: margin, left: margin, bottom: margin, right: margin)

        backdropView.keyholeSpread = Constants.Theme.tooltipHighlightPadding
        backdropView.keyholeCornerRadius = Constants.Theme.tooltipHighlightCornerRadius
    }

    /// Restores the previous dim and animates to the one `applyStyle` just set, linearly like the glide.
    private func fadeDim(from previous: UIColor?, duration: TimeInterval) {
        guard duration > 0, let dim = backdropView.backgroundColor, dim != previous else { return }
        backdropView.backgroundColor = previous
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveLinear, .beginFromCurrentState],
            animations: { [weak self] in self?.backdropView.backgroundColor = dim }
        )
    }
}
