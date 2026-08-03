//
//  UIScrollView+UPScrollEdge.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Scroll edge effects — the iOS 26 treatment that keeps content legible where it meets
//  chrome, by fading and blurring it at the scroll view's edge.
//
//  Apple's guidance: "Optimize for legibility when content scrolls beneath controls. Scroll
//  views offer a scroll edge effect that helps maintain sufficient legibility and contrast
//  for controls by obscuring content that scrolls beneath them."
//
//  Everything here is written to be **reversible and idempotent**: the same call with
//  `allowsGlass: false` undoes what `true` applied, and repeating a call changes nothing.
//  Both matter because these are applied to reused carousel cells and to surfaces that can
//  resolve from glass to solid while presented.
//

import UIKit

internal extension UIScrollView {

    /// Applies — or removes — the soft scroll edge effect on the bottom edge.
    ///
    /// `soft` gives a variable blur plus a gradient scrim derived from the content beneath,
    /// which is the system default and what bars use. `hard` would look closer to the
    /// pre-iOS 26 material, which is not what we want here.
    ///
    /// - Parameter allowsGlass: The resolver's verdict. `false` hides the effect again, so a
    ///   surface that turns solid — or a cell reused by a step that is not glass — does not keep
    ///   a fade it is no longer entitled to.
    func applyUPBottomScrollEdgeEffect(allowsGlass: Bool) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            bottomEdgeEffect.style = allowsGlass ? .soft : .hard
            bottomEdgeEffect.isHidden = !allowsGlass
        }
        #endif
    }

    /// Applies — or removes — the soft scroll edge effect on the top edge, for content that
    /// scrolls up under a header or a dismiss button.
    ///
    /// - Parameter allowsGlass: The resolver's verdict; see
    ///   ``applyUPBottomScrollEdgeEffect(allowsGlass:)``.
    func applyUPTopScrollEdgeEffect(allowsGlass: Bool) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            topEdgeEffect.style = allowsGlass ? .soft : .hard
            topEdgeEffect.isHidden = !allowsGlass
        }
        #endif
    }
}

internal extension UIView {

    /// Registers this view as a container that overlays an edge of `scrollView`, so the
    /// system applies a scroll edge effect behind it.
    ///
    /// Use for a floating CTA that content scrolls beneath. Does nothing unless the content
    /// actually passes under this view — if the layout keeps them adjacent rather than
    /// overlapping there is nothing to obscure.
    ///
    /// The interaction is **owned**: one per view, updated in place when the scroll view or the
    /// edge changes, and removed when `allowsGlass` is `false`. It used to be constructed fresh on
    /// every call and never stored, so a carousel cell accumulated one interaction per bind, each
    /// holding a reference to a scroll view from a step that had already been recycled.
    ///
    /// - Parameters:
    ///   - scrollView: The scroll view whose content passes beneath this view.
    ///   - edge: Which edge of the scroll view this view overlays.
    ///   - allowsGlass: The resolver's verdict; the interaction is removed when `false`.
    /// - Returns: `true` when an interaction is installed on this view afterwards.
    @discardableResult
    func registerUPScrollEdgeContainer(
        for scrollView: UIScrollView,
        edge: UIRectEdge,
        allowsGlass: Bool
    ) -> Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            guard allowsGlass else {
                removeUPScrollEdgeContainer()
                return false
            }

            if let existing = upScrollEdgeInteraction {
                // Same view, new content: point it at the current scroll view rather than stacking
                // another interaction on top.
                existing.scrollView = scrollView
                existing.edge = edge
                return true
            }

            let interaction = UIScrollEdgeElementContainerInteraction()
            interaction.scrollView = scrollView
            interaction.edge = edge
            addInteraction(interaction)
            upScrollEdgeInteraction = interaction
            return true
        }
        #endif
        return false
    }

    /// Removes the scroll edge container interaction this view owns, if any, and drops its
    /// reference to the scroll view.
    func removeUPScrollEdgeContainer() {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            guard let interaction = upScrollEdgeInteraction else { return }
            interaction.scrollView = nil
            removeInteraction(interaction)
            upScrollEdgeInteraction = nil
        }
        #endif
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
private extension UIView {

    /// The interaction this view owns, if one has been installed.
    ///
    /// Held as an associated object rather than a stored property because this is an extension on
    /// `UIView`, and the alternative — searching `interactions` by type on every call — would find
    /// interactions the SDK does not own.
    var upScrollEdgeInteraction: UIScrollEdgeElementContainerInteraction? {
        get {
            objc_getAssociatedObject(self, &UPScrollEdgeKeys.interaction)
                as? UIScrollEdgeElementContainerInteraction
        }
        set {
            objc_setAssociatedObject(
                self,
                &UPScrollEdgeKeys.interaction,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private enum UPScrollEdgeKeys {
    static var interaction: UInt8 = 0
}
#endif
