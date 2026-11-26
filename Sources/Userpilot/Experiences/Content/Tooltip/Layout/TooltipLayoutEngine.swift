//
//  TooltipLayoutEngine.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Decides where a tooltip card goes: which side of the target it sits on, its
//  frame, and how far the pointer has to slide to keep aiming at the target.
//
//  Placement maths live in a pure value type. Nothing here touches UIKit state
//  or reads a live view, so
//  every placement case is decidable from its inputs alone.
//
//  Placement is **two decisions, not one**:
//
//  1. *Which side.* Measure the gap to each safe edge, subtract what the card
//     needs on that axis, and pick a side whose remainder is positive.
//  2. *Where along that side.* Centre on the target, then clamp to the safe
//     edges — and the distance it had to shift is exactly what steers the
//     pointer, so a button near the screen edge gets a card pushed inward with
//     the pointer slid outward to keep pointing at it.
//

import UIKit

// MARK: - Layout Engine

/// Pure placement maths for an anchored tooltip.
internal enum TooltipLayoutEngine {

    // MARK: Constants

    /// Widest a card gets when nothing else constrains it.
    static let defaultMaxWidth: CGFloat = 400

    /// Floor for the card's content height, so a shrunk card stays legible
    /// rather than collapsing to a sliver.
    static let minContentHeight: CGFloat = 46

    /// Height of the bottom-anchored card used until a target resolves.
    static let fallbackHeight: CGFloat = 300

    // MARK: Entry Point

    /// Computes the card's placement.
    static func layout(_ input: TooltipLayoutInput) -> TooltipLayoutOutput {
        let safeBounds = input.containerBounds.inset(by: input.layoutMargins)
        let size = cardSize(for: input, in: safeBounds)
        let spaces = TooltipAvailableSpace(
            targetRect: input.targetRect,
            safeBounds: safeBounds,
            cardSize: size,
            distance: input.distanceFromTarget,
            pointerLength: input.pointerLength,
            borderInsets: input.borderInsets
        )
        let placement = selectPlacement(preferred: input.preferredPlacement, spaces: spaces)

        return frame(
            for: placement,
            input: input,
            safeBounds: safeBounds,
            cardSize: size,
            spaces: spaces
        )
    }

    /// The card's frame before a target has resolved: a bottom-anchored sheet,
    /// centred horizontally.
    ///
    /// This exists because the card is laid out before the first target rect
    /// arrives, and it is precisely why the first placement must be applied
    /// *without* animation — otherwise the card visibly slides up from the
    /// bottom of the screen on every tooltip.
    ///
    /// Assumes `containerBounds` has origin zero on the horizontal axis, which
    /// holds for the only caller (a view passing its own `bounds`).
    static func fallbackFrame(
        containerBounds: CGRect,
        safeAreaInsets: UIEdgeInsets,
        layoutMargins: UIEdgeInsets,
        preferredContentSize: CGSize?,
        borderInsets: UIEdgeInsets
    ) -> CGRect {
        let safeBounds = containerBounds.inset(by: safeAreaInsets)
        let width = containerBounds.width - layoutMargins.left - layoutMargins.right

        var height = max(preferredContentSize?.height ?? fallbackHeight, 1)
        height += borderInsets.top + borderInsets.bottom
        height = min(height, safeBounds.height)

        return CGRect(
            x: (containerBounds.width - width) / 2,
            y: safeBounds.maxY - height,
            width: width,
            height: height
        )
    }

    // MARK: Card Size

    /// The card's size before a side is chosen, capped to the safe area.
    ///
    /// Height already includes the border but **not** the pointer: the pointer
    /// extends whichever axis the chosen side runs along, so it can only be
    /// added once that side is known.
    private static func cardSize(for input: TooltipLayoutInput, in safeBounds: CGRect) -> CGSize {
        let width = ceil(contentWidth(for: input) ?? defaultMaxWidth)
        var height = ceil(max(input.preferredContentSize?.height ?? 0, minContentHeight))
        height += input.borderInsets.top + input.borderInsets.bottom

        return CGSize(
            width: min(width, safeBounds.width),
            height: min(height, safeBounds.height)
        )
    }

    /// The measured content width with the border added back.
    ///
    /// Adding the border back is **load-bearing, not tidiness**. The content
    /// measures itself inside the border, so using its width directly would size
    /// the card to fractionally *less* than the content needs. The content then
    /// re-measures smaller, the card shrinks again, and the loop drives the
    /// width to zero.
    private static func contentWidth(for input: TooltipLayoutInput) -> CGFloat? {
        guard let width = input.preferredContentSize?.width else { return nil }
        return width + input.borderInsets.left + input.borderInsets.right
    }

    // MARK: Stage 1 — Which Side

    /// Picks the side, following a fixed policy:
    ///
    /// 1. The preferred side, but only if it actually fits.
    /// 2. Otherwise the roomier vertical side, if either is viable.
    /// 3. Otherwise the roomier horizontal side, if either is viable.
    /// 4. Otherwise nothing fits: take the roomier vertical side and shrink the
    ///    card's **height** to suit.
    ///
    /// Step 4 excludes the horizontal sides deliberately. Shrinking height
    /// terminates; shrinking width re-wraps the text, which changes the required
    /// height, which re-enters layout — an oscillation with no fixed point. The
    /// horizontal branches *do* shrink width when they are chosen in step 1 or
    /// 3, but those are cases where the width was already known to fit.
    ///
    /// The authored `fallback_placements` list is not consulted: the current layout keeps
    /// the fixed policy, which returns the same answer for the canonical
    /// payload anyway.
    private static func selectPlacement(
        preferred: TooltipPlacement?,
        spaces: TooltipAvailableSpace
    ) -> TooltipPlacement {
        if let preferred, spaces.fits(preferred) {
            return preferred
        }
        if spaces.hasVerticalRoom {
            return spaces.bestVertical
        }
        if spaces.hasHorizontalRoom {
            return spaces.bestHorizontal
        }
        return spaces.bestVertical
    }

    // MARK: Stage 2 — Frame

    /// Builds the frame for the chosen side, then positions it along that side.
    private static func frame(
        for placement: TooltipPlacement,
        input: TooltipLayoutInput,
        safeBounds: CGRect,
        cardSize: CGSize,
        spaces: TooltipAvailableSpace
    ) -> TooltipLayoutOutput {
        var rect = CGRect(origin: .zero, size: cardSize)

        // The pointer extends the card along the axis it points down.
        if placement.isVertical {
            rect.size.height += spaces.pointerLength
        } else {
            rect.size.width += spaces.pointerLength
        }

        applyMainAxis(
            &rect,
            placement: placement,
            input: input,
            safeBounds: safeBounds,
            spaces: spaces
        )

        let offset = applyCrossAxis(&rect, placement: placement, input: input, safeBounds: safeBounds)

        return TooltipLayoutOutput(
            frame: rect,
            placement: placement,
            offsetFromCenter: offset,
            pointerInset: pointerInset(for: placement, length: spaces.pointerLength)
        )
    }

    /// Positions the card along the axis it was placed on, shrinking it if the
    /// side cannot hold it.
    ///
    /// The `min` / `max` against the safe bounds handle a target that is itself
    /// off-screen, and they guard opposite directions: `min` catches a target
    /// scrolled past the **far** edge (below, or trailing), `max` one past the
    /// **near** edge (above, or leading). Without them an off-screen target
    /// drags the card off-screen with it instead of pinning it to the edge.
    private static func applyMainAxis(
        _ rect: inout CGRect,
        placement: TooltipPlacement,
        input: TooltipLayoutInput,
        safeBounds: CGRect,
        spaces: TooltipAvailableSpace
    ) {
        let target = input.targetRect
        let distance = input.distanceFromTarget
        let available = spaces.space(for: placement)

        // Floor for a card that had to shrink, so it never collapses below
        // legible content plus its own chrome.
        let minimumExtent = minContentHeight + spaces.borderHeight + spaces.pointerLength

        switch placement {
        case .top:
            if rect.height <= available {
                rect.origin.y = min(target.minY - distance, safeBounds.maxY) - rect.height
            } else {
                rect.size.height = max(available, minimumExtent)
                rect.origin.y = safeBounds.minY
            }

        case .bottom:
            if rect.height <= available {
                rect.origin.y = max(target.maxY + distance, safeBounds.minY)
            } else {
                rect.size.height = max(available, minimumExtent)
                rect.origin.y = safeBounds.maxY - rect.height
            }

        // The two horizontal shrink branches below are unreachable today:
        // `selectPlacement` only returns `.left` / `.right` when their excess is
        // positive, which already means the card fits. They are kept so the
        // implementations stay complete — but note
        // that `minimumExtent` is a *height* floor built from vertical border
        // insets, so it is dimensionally wrong if a future policy ever does
        // reach them. That confusion is inherited, not introduced here.
        case .left:
            if rect.width <= available {
                rect.origin.x = min(target.minX - distance, safeBounds.maxX) - rect.width
            } else {
                rect.size.width = max(available, minimumExtent)
                rect.origin.x = safeBounds.minX
            }

        case .right:
            if rect.width <= available {
                rect.origin.x = max(target.maxX + distance, safeBounds.minX)
            } else {
                rect.size.width = max(available, minimumExtent)
                rect.origin.x = safeBounds.maxX - rect.width
            }
        }
    }

    /// Centres the card on the target across the placement axis, then clamps it
    /// into the safe bounds.
    ///
    /// - Returns: how far the card had to move to stay inside — the single value
    ///   that steers the pointer. Zero means the card is centred on the target
    ///   and the pointer sits in the middle of its edge.
    private static func applyCrossAxis(
        _ rect: inout CGRect,
        placement: TooltipPlacement,
        input: TooltipLayoutInput,
        safeBounds: CGRect
    ) -> CGFloat {
        let target = input.targetRect

        if placement.isVertical {
            let preferredOriginX = target.midX - rect.width / 2
            // `max` guards against an inverted clamp range, which would trap.
            //
            // Not from a card wider than the safe bounds — `cardSize` already
            // caps that. It is floating-point rounding at the *equality*
            // boundary: the common case is a card capped to exactly
            // `safeBounds.width`, and `safeBounds.maxX - safeBounds.width` is
            // then `(x + l) + (w - l - r) - (w - l - r)`, which in IEEE 754 need
            // not come back to `x + l`. With a non-dyadic `screen_edge_margin`
            // it lands an ulp below `safeBounds.minX` and `ClosedRange` traps.
            // There is no guard here otherwise; integral margins on integral
            // bounds are exact.
            let upperBound = max(safeBounds.minX, safeBounds.maxX - rect.width)
            rect.origin.x = preferredOriginX.clamped(to: safeBounds.minX...upperBound)
            return preferredOriginX - rect.origin.x
        }

        let preferredOriginY = target.midY - rect.height / 2
        let upperBound = max(safeBounds.minY, safeBounds.maxY - rect.height)
        rect.origin.y = preferredOriginY.clamped(to: safeBounds.minY...upperBound)
        return preferredOriginY - rect.origin.y
    }

    /// Reserves layout space for the pointer on the edge facing the target, so
    /// the pointer occupies layout rather than overhanging the content.
    private static func pointerInset(
        for placement: TooltipPlacement,
        length: CGFloat
    ) -> UIEdgeInsets {
        switch placement {
        case .top: return UIEdgeInsets(top: 0, left: 0, bottom: length, right: 0)
        case .bottom: return UIEdgeInsets(top: length, left: 0, bottom: 0, right: 0)
        case .left: return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: length)
        case .right: return UIEdgeInsets(top: 0, left: length, bottom: 0, right: 0)
        }
    }
}
