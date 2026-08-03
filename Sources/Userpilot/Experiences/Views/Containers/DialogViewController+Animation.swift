//
//  DialogViewController+Animation.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Presentation and dismissal animations for the centred dialog, selected by
//  `Config.dialogAnimation(_:)`. Split from `DialogViewController.swift` to keep both files
//  within the 400-line limit.
//
//  Both animations are safe on a Liquid Glass surface. Fading the container removes the
//  material cleanly — verified in the iOS 26 spike. What produced
//  the card-shaped ghost that outlived the dialog was the backdrop mask, whose hole is cut at
//  the dialog's resting frame; it must be dropped before anything animates, which is what
//  `suspendsBackdropMask` does.
//

import Foundation
import UIKit

// MARK: - Animations

extension DialogViewController {

    /// Animates the presentation of the dialog.
    ///
    /// Reduce Motion turns a slide into a fade: movement is the thing the setting asks the SDK to
    /// drop, and a cross-fade in place is the accepted substitute. The completion still runs, so
    /// nothing downstream can tell the difference.
    func animatePresent() {
        let reducesMotion = glassResolver?.reducesSDKMotion ?? false
        switch dialogAnimation {
        case .fade:
            animateFadePresent()
        case .slide:
            if reducesMotion {
                animateFadePresent()
            } else {
                animateSlidePresent()
            }
        }
    }

    /// Fades the dialog in over the backdrop, with no movement at all.
    ///
    /// With a glass surface the *material* animates — `effect` from `nil` to the resolved effect,
    /// which is how UIKit is meant to be asked to materialise a visual effect view — while the
    /// content fades. A solid dialog fades its container's opacity exactly as before.
    private func animateFadePresent() {
        mainContainerView.transform = .identity

        let animatesMaterial = glassBackground?.prepareMaterialForAnimation() ?? false
        if animatesMaterial {
            // The container stays opaque so the material is what appears; its content fades in.
            mainContainerView.alpha = 1
            contentView.alpha = 0
        } else {
            mainContainerView.alpha = 0
        }

        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
            self.dimmedView.alpha = 1.0
            if animatesMaterial {
                self.glassBackground?.materialize()
                self.contentView.alpha = 1
            } else {
                self.mainContainerView.alpha = 1.0
            }
        }, completion: { [weak self] _ in
            // Only cut the backdrop once the dialog has settled and is fully opaque. Cutting it
            // any earlier leaves an undimmed, card-shaped hole visible through the dialog while
            // it is still translucent.
            self?.suspendsBackdropMask = false
            self?.updateBackdropMask()
        })
    }

    /// Presents the dialog by *moving* it rather than fading it.
    ///
    /// Opacity is left alone at 1 throughout; only the transform and the backdrop animate. The
    /// travel is the full distance to the bottom of the screen, because a shorter slide with no
    /// fade would end with the dialog vanishing abruptly at full opacity.
    private func animateSlidePresent() {
        mainContainerView.alpha = 1
        mainContainerView.transform = offscreenTransform

        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut], animations: {
            self.dimmedView.alpha = 1.0
            self.mainContainerView.transform = .identity
        }, completion: { [weak self] _ in
            self?.suspendsBackdropMask = false
            self?.updateBackdropMask()
        })
    }

    /// Dismisses the dialog, reversing whichever animation presented it.
    func dismissDialog(completion: (() -> Void)? = nil) {
        // Drop the mask before anything moves or fades. Left in place, its hole stays cut at the
        // dialog's resting position for the whole dismissal and remains after it — the exact
        // card-shaped ghost reported during development.
        suspendsBackdropMask = true
        updateBackdropMask()

        // Matches whatever `animatePresent()` chose, including its Reduce Motion substitution.
        let slides = dialogAnimation == .slide && !(glassResolver?.reducesSDKMotion ?? false)
        // A fading glass dialog reverses the way it arrived: the material goes back to `nil` rather
        // than the whole hierarchy being alpha-faded. A slide keeps full opacity throughout, so it
        // leaves the material alone.
        let dematerializes = !slides && (glassBackground?.isRenderingGlass ?? false)

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self else { return }
            self.dimmedView.alpha = 0
            if slides {
                self.mainContainerView.transform = self.offscreenTransform
            } else if dematerializes {
                self.glassBackground?.dematerialize()
                self.contentView.alpha = 0
            } else {
                self.mainContainerView.alpha = 0
            }
        }, completion: { [weak self] _ in
            self?.dismiss(animated: false, completion: completion)
        })
    }

    /// Translation that parks the dialog just off the bottom of the screen.
    private var offscreenTransform: CGAffineTransform {
        CGAffineTransform(translationX: 0, y: view.bounds.height - mainContainerView.frame.minY)
    }
}
