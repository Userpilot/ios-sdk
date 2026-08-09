//
//  StepCollectionViewCell+ScrollEdge.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  How a carousel step lets its content run under the chrome at both edges, which is what Apple's
//  scroll edge effect needs in order to render anything at all: with the content stopping short of
//  the chrome there is nothing passing underneath to fade.
//
//  Split out of `StepCollectionViewCell.swift` to keep that file within the 400-line limit.
//

import UIKit

extension StepCollectionViewCell {

    /// Where the scrolling content stops.
    ///
    /// On iOS 26 with Liquid Glass the content runs all the way to the display's bottom edge and
    /// the action button **floats over it**, which is what Apple's scroll edge effect needs in
    /// order to render at all — with the content stopping above the button there is nothing
    /// passing underneath to fade, and the effect draws nothing (verified during the iOS 26 spike).
    ///
    /// The edge rather than the safe area, per Apple's guidance that content fills the display and
    /// passes behind the chrome while *controls* stay inside the safe area. The home indicator's
    /// inset is added back as content inset by `.always`, so the content still clears the button.
    ///
    /// Otherwise the content stops above the button exactly as before.
    func scrollViewBottomConstraint() -> NSLayoutConstraint {
        guard floatsActionButton else {
            return theScrollView.bottomAnchor.constraint(
                equalTo: actionButton.topAnchor,
                constant: ThemeHandler.DefaultValues.distanceBetweenSections.negative
            )
        }
        return theScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    }

    /// The step's scrolling content, for the view controller's dismiss button to register against:
    /// the button overlays this scroll view's top edge but is not part of this cell.
    var stepScrollView: UIScrollView { theScrollView }

    /// Where the scrolling content starts.
    ///
    /// The mirror of ``scrollViewBottomConstraint()``: with glass the content runs to the display's
    /// top edge and passes *behind* the dismiss button, which is what the top scroll edge effect
    /// needs in order to render. Without it the content starts 65 pt down — 10 pt clear of the
    /// button's bottom — so nothing ever passes underneath and the effect draws nothing.
    ///
    /// The status bar inset is added back as content inset by `.always`, on top of
    /// ``floatingDismissClearance``, so the content still begins where it did.
    func scrollViewTopConstraint() -> NSLayoutConstraint {
        guard floatsActionButton else {
            return theScrollView.topAnchor.constraint(
                equalTo: safeAreaLayoutGuide.topAnchor,
                constant: ThemeHandler.DefaultValues.carouselContentTopMargin)
        }
        return theScrollView.topAnchor.constraint(equalTo: contentView.topAnchor)
    }

    /// The band at the top of the scroll view the dismiss button occupies, and that the content has
    /// to keep clear of. Measured from the safe area, since `.always` adds the safe area itself.
    var floatingDismissClearance: CGFloat {
        guard floatsActionButton else { return 0 }
        return ThemeHandler.DefaultValues.carouselContentTopMargin
    }

    /// Whether the chrome floats over the scrolling content.
    var floatsActionButton: Bool {
        glassResolver?.allowsGlass(for: .chrome) ?? false
    }

    /// The band at the bottom of the scroll view that the floating button occupies, and that the
    /// content therefore has to keep clear of. Zero when the button is not floating, because then
    /// the scroll view stops above it and there is nothing to clear.
    func floatingButtonClearance(theme: ExperienceTheme) -> CGFloat {
        guard floatsActionButton else { return 0 }

        let buttonMargin = theme.isStepsProgressEnabled
            ? ThemeHandler.DefaultValues.buttonBottomMarginWithStepProgress
            : ThemeHandler.DefaultValues.buttonBottomMarginWithoutStepProgress
        return UPButtonView.buttonHeight
            + buttonMargin
            + ThemeHandler.DefaultValues.distanceBetweenSections
    }

    /// Applies the scroll edge effect and gives the content room to clear the floating button.
    ///
    /// Without the inset the last section would sit permanently underneath the button.
    func applyFloatingActionButtonChrome(theme: ExperienceTheme) {
        actionButton.glassResolver = glassResolver
        theScrollView.applyUPBottomScrollEdgeEffect(allowsGlass: floatsActionButton)
        theScrollView.applyUPTopScrollEdgeEffect(allowsGlass: floatsActionButton)

        guard floatsActionButton else {
            theScrollView.contentInset.bottom = 0
            theScrollView.verticalScrollIndicatorInsets.bottom = 0
            theScrollView.contentInset.top = 0
            theScrollView.verticalScrollIndicatorInsets.top = 0
            actionButton.removeUPScrollEdgeContainer()
            return
        }

        // The dismiss button belongs to the view controller, not the cell, so the *container*
        // registration for the top edge is made there — see
        // `CarouselExperienceViewController+CollectionViewExtensions`. This side only has to make
        // the content pass underneath it.
        theScrollView.contentInset.top = floatingDismissClearance
        theScrollView.verticalScrollIndicatorInsets.top = floatingDismissClearance

        // `setupUI` adds `actionButton` before `theScrollView`, so the scroll view sits on top in
        // z-order. That was harmless while the two were adjacent, but now the scroll view extends
        // underneath the button — and would swallow its taps. Raising the button both fixes
        // hit-testing and is required for it to be visible over the content at all.
        contentView.bringSubviewToFront(actionButton)

        let clearance = floatingButtonClearance(theme: theme)
        theScrollView.contentInset.bottom = clearance
        theScrollView.verticalScrollIndicatorInsets.bottom = clearance

        actionButton.registerUPScrollEdgeContainer(
            for: theScrollView,
            edge: .bottom,
            allowsGlass: true
        )
    }
}
