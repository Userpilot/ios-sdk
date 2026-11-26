//
//  TooltipWrapperView+Appearance.swift
//  Userpilot SDK
//
//  Created by Userpilot on 25/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  How a tooltip appears and goes away. The card fades in while growing from
//  80% over 250 ms and fades out over 100 ms; the dim fades over 300 ms both
//  ways. Reduce Motion collapses every duration to zero.
//
//  The scale is a Core Animation animation, never `transform`: `applyFrame`
//  assigns `shadowWrappingView.frame` on every layout pass, and a frame set on
//  a transformed view is undefined, so a layout during the reveal would leave
//  the card the wrong size.
//

import UIKit

internal extension TooltipWrapperView {

    private enum AppearanceValues {
        static let cardRevealDuration: TimeInterval = 0.25
        static let cardDismissDuration: TimeInterval = 0.1
        static let dimDuration: TimeInterval = 0.3
        static let revealStartScale: CGFloat = 0.8
        static let revealScaleKey = "userpilotTooltipReveal"
    }

    /// Fades the dim in, and the card in while it grows to full size.
    func animateReveal() {
        let cardDuration = appearanceDuration(AppearanceValues.cardRevealDuration)
        backdropView.alpha = 0
        shadowWrappingView.alpha = 0

        if cardDuration > 0 {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = AppearanceValues.revealStartScale
            scale.toValue = 1
            scale.duration = cardDuration
            scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shadowWrappingView.layer.add(scale, forKey: AppearanceValues.revealScaleKey)
        }

        UIView.animate(
            withDuration: cardDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: { [weak self] in self?.shadowWrappingView.alpha = 1 }
        )
        UIView.animate(
            withDuration: appearanceDuration(AppearanceValues.dimDuration),
            delay: 0,
            options: [.curveLinear, .beginFromCurrentState],
            animations: { [weak self] in self?.backdropView.alpha = 1 }
        )
    }

    /// Fades the card and the slower dim out, then calls `completion` once, when the dim is gone.
    func animateDismiss(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: appearanceDuration(AppearanceValues.cardDismissDuration),
            delay: 0,
            options: [.curveLinear, .beginFromCurrentState],
            animations: { [weak self] in self?.shadowWrappingView.alpha = 0 }
        )
        UIView.animate(
            withDuration: appearanceDuration(AppearanceValues.dimDuration),
            delay: 0,
            options: [.curveLinear, .beginFromCurrentState],
            animations: { [weak self] in self?.backdropView.alpha = 0 },
            completion: { _ in completion() }
        )
    }

    private func appearanceDuration(_ duration: TimeInterval) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0 : duration
    }
}
