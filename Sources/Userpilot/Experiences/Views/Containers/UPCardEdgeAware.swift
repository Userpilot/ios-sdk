//
//  UPCardEdgeAware.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  How a content view learns where the card's edge is, for the one element that has to touch it.
//

import UIKit

/// Where a card's edge sits, relative to the padded content area inside it.
///
/// Content views are laid out inside `contentView`, which is inset from the card by
/// ``UPCardMetrics``. That is right for everything except a full-bleed element — the step progress
/// bar — which is supposed to sit *on* the card's top border, edge to edge, rather than inside its
/// padding.
///
/// The card's rounded corners take care of themselves: a card with `clipsToBounds` clips its
/// subviews to the rounded shape, so a bar spanning the full width is trimmed along the corner arc
/// rather than poking out of it. Measured in
/// Measured during the iOS 26 spike, where the bar's leading edge moves
/// inward row by row as it follows the curve. So all the card has to publish is where its padding
/// is; the element escapes that and the shape does the rest.
internal struct UPCardEdge: Equatable {

    /// Distance from the content area's top edge to the card's top edge.
    let contentTopInset: CGFloat

    /// Distance from the content area's side edges to the card's side edges.
    let contentHorizontalInset: CGFloat

    /// Offset a top-anchored element needs, relative to the content area, to sit on the card's
    /// top border. Negative: it has to escape upward, out of the padding.
    var topOffset: CGFloat { -contentTopInset }

    /// Leading offset that takes a full-bleed element out to the card's side edge. Negative for the
    /// same reason as ``topOffset`` — it escapes the padding. Apply it negated on the trailing side.
    var horizontalInset: CGFloat { -contentHorizontalInset }
}

/// A view drawn as an experience card, publishing the radius a control inside it should match.
///
/// Apple's concentricity guidance is about *nested* shapes: an inner corner shares its centre with
/// the outer one, so the gap between the two curves stays constant all the way round. That makes the
/// inner radius `outerRadius − gap`, and the gap is something only the control can know — it depends
/// on where the control actually sits. So the card publishes its own radius and the control measures
/// the rest.
///
/// `nil` means "not a card a control should match": glass is off, so the theme's corner radius is
/// the customer's to decide and nothing here overrides it. That is what keeps full-screen
/// experiences — which have no card at all — on their configured radius.
internal protocol UPCardShaped: AnyObject {

    /// The radius the card is currently drawn with, nearest the controls that sit in it.
    ///
    /// A bottom sheet's top and bottom radii differ; this is the **bottom** one, because that is the
    /// corner an action button sits beside.
    var upCardCornerRadius: CGFloat? { get }
}

/// The card view behind a bottom sheet's and a centre dialog's content.
internal final class UPCardView: UIView, UPCardShaped {

    var upCardCornerRadius: CGFloat?
}

extension UIView {

    /// The nearest ancestor card and the radius it publishes, walking outward from this view.
    ///
    /// Chain-walking rather than being told: a control sits several containers below the card
    /// (`card → contentView → container view → stack → button`), and threading the shape through
    /// every one of them is how it ends up missing from whichever container nobody remembered. The
    /// view comes back with the radius because measuring the gap needs both.
    var upNearestCard: (view: UIView, cornerRadius: CGFloat)? {
        var candidate: UIView? = self
        while let view = candidate {
            if let radius = (view as? UPCardShaped)?.upCardCornerRadius {
                return (view, radius)
            }
            candidate = view.superview
        }
        return nil
    }
}

/// A content view holding an element that must sit on the card's border rather than inside its
/// padding.
///
/// Only the two views with a top progress bar conform. Anything that does not — the carousel and
/// slide-out content — is unaffected, and a conforming view that is never told about a card keeps
/// whatever layout it was built with.
internal protocol UPCardEdgeAware: AnyObject {

    /// Called by the containing card whenever its geometry is decided or changes.
    func applyCardEdge(_ edge: UPCardEdge?)
}
