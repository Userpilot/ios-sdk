//
//  TooltipWrapperView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Hosts a tooltip: the keyhole backdrop, and the card positioned against its
//  target. Owns everything visual that is not the card's own content — the
//  shape mask, the border, the shadow, and the reposition animation.
//
//  Placement maths live in `TooltipLayoutEngine` so they can be reasoned about
//  on their own.
//
//  The animation split here is the part most likely to be "simplified" by
//  mistake, so it is worth stating plainly:
//
//  * **The frame animates.** Only `shadowWrappingView.frame`, at 300 ms linear,
//    and only after the first placement.
//  * **The mask, border and shadow paths never animate.** They are recomputed
//    synchronously in `layoutSubviews`. Animating them alongside the frame is
//    exactly what produces a pointer that rubber-bands away from its target and
//    snaps back.
//  * **The first placement is instant.** The card is laid out before any target
//    rect exists, at a bottom-anchored fallback position, so animating the first
//    real placement would make every tooltip visibly fly up from the bottom of
//    the screen.
//

import UIKit

// MARK: - TooltipWrapperView

/// Root view of a tooltip presentation.
internal final class TooltipWrapperView: UIView {

    // MARK: Nested Types

    private enum LayoutValues {
        /// Reposition duration and curve.
        static let repositionDuration: TimeInterval = 0.3
        /// Corner radius of the card. Follows the precedent set by the existing
        /// containers, which hardcode their radius rather than theming it.
        static let cornerRadius = Constants.Theme.tooltipCornerRadius
    }

    // MARK: Subviews

    /// Dim plus keyhole. Sits behind everything.
    let backdropView = UPTooltipBackdropView()

    /// Carries the drop shadow. Separate from `contentWrapperView` because a
    /// shadow needs an unclipped layer while the card itself must clip to its
    /// tooltip shape — one view cannot do both.
    ///
    /// Passthrough, and that is not optional: it wraps the masked card, so if it
    /// claimed hits itself, every tap the card's mask correctly rejected — a
    /// rounded corner, the strip beside the pointer — would die here instead of
    /// reaching the backdrop. The mask would produce dead zones rather than
    /// passthrough.
    let shadowWrappingView = TooltipPassthroughView()

    /// Clipped to the tooltip outline. Holds the card.
    let contentWrapperView = TooltipMaskedView()

    /// The card's content.
    let cardView = UPTooltipCardView()

    // MARK: Placement Inputs

    /// Target rect in this view's space. `nil` until the selector resolves.
    var targetRect: CGRect? {
        didSet {
            guard targetRect != oldValue else { return }
            positionContent(animated: hasPositionedOnce)
        }
    }

    /// Author's preferred side.
    var preferredPlacement: TooltipPlacement?

    /// Gap between target and card.
    var distanceFromTarget: CGFloat = 0

    /// Pointer size, or `nil` for no pointer — which also removes its reserved
    /// layout space and collapses the outline to a plain rounded rect.
    var pointerSize: CGSize?

    /// Size the card's content asked for.
    private var preferredContentSize: CGSize?

    // MARK: Placement Results

    /// The side actually chosen. `nil` before the first real placement.
    private(set) var resolvedPlacement: TooltipPlacement?

    /// How far the card was shifted off centre, which steers the pointer.
    private var offsetFromCenter: CGFloat = 0

    /// Whether a real target has been placed yet. Gates the first-placement
    /// instant rule. Cleared by a parked Flow overlay, which returns in place.
    var hasPositionedOnce = false

    // MARK: Layers

    private let maskLayer = CAShapeLayer()

    private let borderLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.lineWidth = 0
        return layer
    }()

    // MARK: Initialization

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        buildHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildHierarchy() {
        addSubview(backdropView)
        addSubview(shadowWrappingView)
        shadowWrappingView.addSubview(contentWrapperView)
        contentWrapperView.addSubview(cardView)

        // Belt and braces for the hotspot. Laying the card out against the
        // spread keyhole normally keeps them apart, but the layout engine's
        // shrink-to-fit branch pins an oversized card to the safe edge and *can*
        // still cover the target. Without this, a tooltip whose only exit is the
        // target tap would be inescapable.
        contentWrapperView.hotspotRectProvider = { [weak self] in
            guard let self, self.backdropView.onTargetTapped != nil,
                  let hotspot = self.backdropView.hotspotRect else { return nil }
            return self.backdropView.convert(hotspot, to: self.contentWrapperView)
        }

        // The card clips to the tooltip outline, so it must not also clip to its
        // own bounds — the pointer lives outside them.
        contentWrapperView.clipsToBounds = false
        contentWrapperView.layer.mask = maskLayer
        contentWrapperView.layer.addSublayer(borderLayer)

        cardView.onPreferredContentSizeChanged = { [weak self] size in
            self?.updatePreferredContentSize(size)
        }

        // Content first, the target hotspot second. The backdrop is `subviews[0]`,
        // so by default VoiceOver would announce the hotspot *before* reading
        // the tooltip's own title and body.
        accessibilityElements = [shadowWrappingView, backdropView]
    }

    // MARK: Styling

    /// Applies the merged theme's card styling.
    func applyStyle(theme: ExperienceTheme) {
        contentWrapperView.backgroundColor = theme.backgroundColor
        cardView.backgroundColor = theme.backgroundColor

        // Cleared rather than hidden. A hidden view is skipped by hit testing,
        // which would silently kill the target hotspot — for a step with no close
        // button and no action button, its only exit.
        backdropView.backgroundColor = theme.backdropEnabled
            ? theme.backdropColor.withAlphaComponent(theme.backdropOpacity)
            : .clear

        shadowWrappingView.layer.shadowColor = UIColor.black.cgColor
        shadowWrappingView.layer.shadowOpacity = 0.15
        shadowWrappingView.layer.shadowRadius = 12
        shadowWrappingView.layer.shadowOffset = CGSize(width: 0, height: 4)
    }

    /// Applies a border, drawn on the shared outline.
    ///
    /// The stroke is set to **twice** the requested width and drawn on the same
    /// path as the mask; the mask then trims the outer half. That is cheaper and
    /// exactly aligned, where computing a second inset path would have to
    /// re-derive the pointer geometry and could not be guaranteed to match.
    func applyBorder(color: UIColor?, width: CGFloat?) {
        guard let color, let width, width > 0 else {
            borderLayer.lineWidth = 0
            contentWrapperView.layoutMargins = .zero
            return
        }

        borderLayer.strokeColor = color.cgColor
        borderLayer.lineWidth = width * 2
        contentWrapperView.layoutMargins = UIEdgeInsets(
            top: width, left: width, bottom: width, right: width)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        backdropView.frame = bounds
        positionContent(animated: false)
    }

    /// Recomputes the outline and everything drawn from it.
    ///
    /// Never animated, and the `CATransaction` is what enforces that. `maskLayer`
    /// and `borderLayer` are standalone `CAShapeLayer`s, so assigning their
    /// `path` inside an active `UIView.animate` transaction would inherit that
    /// block's duration and curve — and an animated mask path alongside an
    /// animated frame is exactly the rubber-banding pointer this file's header
    /// warns about.
    private func rebuildShape() {
        let bounds = contentWrapperView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let inset = cardView.pointerInset
        // Never let the corner radius exceed half of either usable dimension, or
        // the corner arcs overlap and the outline folds in on itself.
        let radius = min(
            LayoutValues.cornerRadius,
            (bounds.height - inset.top - inset.bottom) / 2,
            (bounds.width - inset.left - inset.right) / 2
        )

        let path = outlinePath(in: bounds, cornerRadius: max(radius, 0))
        maskLayer.path = path
        borderLayer.path = path
        shadowWrappingView.layer.shadowPath = path
    }

    /// The card outline: rounded box plus pointer, or a plain rounded rect when
    /// there is no pointer or no placement yet.
    private func outlinePath(in bounds: CGRect, cornerRadius: CGFloat) -> CGPath {
        guard let pointerSize, let placement = resolvedPlacement else {
            return UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        }

        // The box is the card minus the strip the pointer occupies.
        let inset = cardView.pointerInset
        let mainRect = bounds.inset(by: inset)

        let edge = TooltipPointerShape.Edge(placement: placement)
        let sideLength = placement.isVertical ? mainRect.width : mainRect.height

        // Clamp the pointer's base so it can never be wider than the flat part of
        // the edge between the two corner arcs.
        let constrained = CGSize(
            width: min(pointerSize.width, max(sideLength - cornerRadius * 2, 0)),
            height: pointerSize.height
        )

        let pointer = TooltipPointerShape(
            edge: edge,
            size: constrained,
            // Square tip: the payload carries no pointer corner radius, so there
            // is nothing to round it from. `TooltipPointerShape` keeps the field
            // because the path code needs it; feeding it a real value is additive
            // if a radius is ever added to the contract.
            cornerRadius: 0,
            offset: offsetFromCenter
        )

        return CGPath.userpilotTooltip(
            around: mainRect, boxCornerRadius: cornerRadius, pointer: pointer)
    }

    // MARK: Positioning

    /// Places the card against its target, or at the fallback position when
    /// there is no target yet.
    ///
    /// **Every placement must also resize the card and recut its shape.** The
    /// frame assigned here is `shadowWrappingView`'s; `contentWrapperView`,
    /// `cardView`, the mask, the border and the shadow path all derive from it,
    /// and none of them is constraint-driven. Setting a subview's frame dirties
    /// only that subview, so `layoutSubviews` is *not* re-entered and would never
    /// catch up — the card would keep the size and outline of whatever placement
    /// came before, most visibly the bottom fallback it starts at. The same
    /// sync happens inside `positionContentView`.
    func positionContent(animated: Bool) {
        guard bounds != .zero else { return }

        guard let targetRect else {
            resolvedPlacement = nil
            offsetFromCenter = 0
            cardView.pointerInset = .zero
            applyFrame(
                TooltipLayoutEngine.fallbackFrame(
                    containerBounds: bounds,
                    safeAreaInsets: safeAreaInsets,
                    layoutMargins: layoutMargins,
                    preferredContentSize: preferredContentSize,
                    borderInsets: contentWrapperView.layoutMargins
                ),
                animated: animated
            )
            // Close the keyhole too, or a target that goes away leaves a hole cut
            // where it used to be.
            backdropView.setKeyhole(nil, animated: animated)
            return
        }

        // Laid out against the **spread** keyhole, not the bare target rect. The
        // keyhole is what the user sees as "the target", and whenever its spread
        // exceeds the gap a card placed against the bare rect is drawn *over*
        // the lit hole. That is visibly wrong on its own, and it also kills the target hotspot: the
        // card is a later sibling than the backdrop, so it wins the hit test and
        // the backdrop's recogniser never runs.
        let output = TooltipLayoutEngine.layout(
            TooltipLayoutInput(
                containerBounds: bounds,
                layoutMargins: layoutMargins,
                targetRect: spreadTargetRect(targetRect),
                preferredContentSize: preferredContentSize,
                borderInsets: contentWrapperView.layoutMargins,
                pointerLength: pointerSize?.height ?? 0,
                distanceFromTarget: distanceFromTarget,
                preferredPlacement: preferredPlacement
            )
        )

        resolvedPlacement = output.placement
        offsetFromCenter = output.offsetFromCenter
        cardView.pointerInset = output.pointerInset

        applyFrame(output.frame, animated: animated)
        backdropView.setKeyhole(targetRect, animated: animated)

        // Latched only once a placement has actually happened, so a target rect
        // assigned before the view has bounds cannot consume the single instant
        // placement and leave the first *visible* one animating up from the
        // fallback position.
        hasPositionedOnce = true
    }

    /// The target rect grown by the keyhole's spread — the lit area the card
    /// must stay clear of.
    private func spreadTargetRect(_ rect: CGRect) -> CGRect {
        let spread = backdropView.keyholeSpread
        return rect.insetBy(dx: -spread, dy: -spread)
    }

    /// Assigns the card frame and resizes everything derived from it.
    ///
    /// Only the frame animates. Reduce Motion collapses the duration to zero
    /// rather than skipping the update, so the card still lands in the right
    /// place — just without the travel. Cheap and expected of us.
    private func applyFrame(_ frame: CGRect, animated: Bool) {
        let duration = animated && !UIAccessibility.isReduceMotionEnabled
            ? LayoutValues.repositionDuration
            : 0

        let apply = { [weak self] in
            guard let self else { return }
            self.shadowWrappingView.frame = frame
            self.contentWrapperView.frame = self.shadowWrappingView.bounds
            self.cardView.frame = self.contentWrapperView.bounds
        }

        guard duration > 0 else {
            apply()
            rebuildShape()
            return
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveLinear, .beginFromCurrentState],
            animations: apply
        )

        // Deliberately outside the animation block: the frame assignments above
        // take effect on the model layer immediately, so the outline is rebuilt
        // from final geometry — and keeping it out of the block is half of what
        // stops the mask, border and shadow paths animating along with it.
        rebuildShape()
    }

    /// Re-runs placement when the content's measured size changes.
    private func updatePreferredContentSize(_ size: CGSize) {
        guard size != preferredContentSize else { return }
        preferredContentSize = size
        // Never animated: a content size change is not a reposition. Without
        // this, an image finishing loading would visibly slide the card.
        positionContent(animated: false)
    }
}
