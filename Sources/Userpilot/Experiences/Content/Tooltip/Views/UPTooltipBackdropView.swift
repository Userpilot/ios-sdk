//
//  UPTooltipBackdropView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Draws a full-screen dim with an even-odd CAShapeLayer keyhole.
//  A positive corner-radius floor preserves path structure for interpolation.
//  Appear/disappear animations collapse the hole at its centre, and explicit
//  mask updates disable implicit Core Animation actions.

import UIKit

// MARK: - UPTooltipBackdropView

/// Draws a dim with an even-odd rounded keyhole around the tooltip target. A tap inside the keyhole runs
/// `onTargetTapped`; a tap on the dim is consumed without acting on it.
internal final class UPTooltipBackdropView: UIView {

    // MARK: Nested Types

    private enum Constants {
        /// Matches the keyhole path morph, so dim and hole move together.
        static let animationDuration: TimeInterval = 0.3
    }

    // MARK: Properties

    /// Runs the authored action for a tap inside the keyhole. Host-app taps are
    /// not forwarded across windows, and a tap on the dim does nothing.
    var onTargetTapped: (() -> Void)? {
        didSet { refreshAccessibility() }
    }

    /// The target rect to cut out, in this view's coordinate space.
    ///
    /// `nil` means no hole: the whole screen dims. Setting it re-cuts the mask,
    /// animating from wherever the hole was before.
    private(set) var keyholeRect: CGRect?

    /// How far the hole extends beyond the target — `Constants.Theme.tooltipHighlightPadding`.
    ///
    /// Clamped to zero or more. A negative value makes `insetBy` produce a
    /// non-standardised rect, and `CGRect.contains` then rejects *every* point —
    /// which would silently remove the target hotspot, the one exit some
    /// tooltips have.
    var keyholeSpread: CGFloat = 0 {
        didSet { keyholeSpread = max(0, keyholeSpread) }
    }

    /// Corner radius of the hole — `Constants.Theme.tooltipHighlightCornerRadius`.
    var keyholeCornerRadius: CGFloat = 0

    /// Bounds the mask was last cut for, so a layout pass that changed nothing
    /// does not recut it. Recutting mid-animation replaces the model value the
    /// running `path` animation is heading toward, which makes the hole snap at
    /// the end of the morph.
    private var maskedBounds: CGRect = .zero

    /// Reused rather than rebuilt on each refresh: replacing
    /// `accessibilityElements` while VoiceOver focus sits on one of them drops
    /// the focus and re-announces from the top, and the refresh runs on every
    /// layout pass.
    /// No hint: the same tap advances a Flow mid-way and completes it at its last step.
    private lazy var hotspotElement: TooltipActionElement = {
        let element = TooltipActionElement(accessibilityContainer: self)
        element.accessibilityLabel = TooltipStrings.hotspotAccessibilityLabel
        element.accessibilityTraits = .button
        element.accessibilityIdentifier = "userpilot-tooltip-target-hotspot"
        return element
    }()

    /// The mask currently applied, kept so a re-layout can rebuild the path
    /// without animating.
    private let maskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillRule = .evenOdd
        return layer
    }()

    // MARK: Initialization

    init() {
        super.init(frame: .zero)
        layer.mask = maskLayer
        addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(backdropTapped(_:)))
        )

        refreshAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Layout

    /// Rebuilds the mask on every bounds change.
    ///
    /// A mask layer does **not** participate in autoresizing, so without this the
    /// hole keeps the size and position it had at the previous bounds — most
    /// visibly after a rotation, where the dim would be cut in the wrong place
    /// and partly not cover the screen at all.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != maskedBounds else { return }
        maskedBounds = bounds
        applyMask(for: keyholeRect, animated: false)
        refreshAccessibility()
    }

    // MARK: Keyhole

    /// Moves, opens, or closes the keyhole.
    ///
    /// - Parameters:
    ///   - rect: the target rect, or `nil` to close the hole entirely.
    ///   - animated: whether to morph from the current hole. The first
    ///     application must not animate, or the hole visibly flies in from the
    ///     card's pre-target fallback position.
    func setKeyhole(_ rect: CGRect?, animated: Bool) {
        let previous = keyholeRect
        keyholeRect = rect
        maskedBounds = bounds
        applyMask(for: rect, from: previous, animated: animated)
        // The hotspot's frame follows the keyhole.
        refreshAccessibility()
    }

    // MARK: Mask

    /// Cuts the hole, optionally morphing from the previous one.
    ///
    /// Both the appearing and disappearing cases are expressed as a morph
    /// between a real rect and a zero-size rect at the same centre. That keeps
    /// the two paths structurally identical — same subpaths, same control points
    /// — which is the precondition for `CABasicAnimation` on `path` producing
    /// anything sensible rather than a scramble.
    private func applyMask(for rect: CGRect?, from previous: CGRect? = nil, animated: Bool = false) {
        guard bounds != .zero else { return }

        let newPath = maskPath(for: rect, collapsingFrom: previous)

        // Reduce Motion collapses the morph, matching what the card's frame
        // already does — otherwise the card snaps into place while the hole
        // crawls after it.
        let shouldAnimate = animated && !UIAccessibility.isReduceMotionEnabled

        if shouldAnimate, let oldPath = maskPath(for: previous, collapsingFrom: rect) {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = oldPath
            animation.toValue = newPath
            animation.duration = Constants.animationDuration
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            maskLayer.add(animation, forKey: "keyhole")
        }

        // Assigning `path` outside a transaction would let Core Animation add
        // its own implicit animation on top of the explicit one above.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.path = newPath
        CATransaction.commit()
    }

    /// Builds the even-odd mask: the full bounds, with the keyhole appended as a
    /// second subpath that the fill rule turns into a hole.
    ///
    /// - Parameters:
    ///   - rect: the hole, or `nil`.
    ///   - other: the rect at the other end of the animation, used to place a
    ///     collapsed hole at the right centre when `rect` is `nil`.
    private func maskPath(for rect: CGRect?, collapsingFrom other: CGRect?) -> CGPath? {
        let path = UIBezierPath(rect: bounds)

        let hole: CGRect
        if let rect {
            hole = rect.insetBy(dx: -keyholeSpread, dy: -keyholeSpread)
        } else if let other {
            // Collapse to a zero-size rect at the other rect's centre, so the
            // hole shrinks into the target rather than vanishing abruptly.
            let spread = other.insetBy(dx: -keyholeSpread, dy: -keyholeSpread)
            hole = CGRect(x: spread.midX, y: spread.midY, width: 0, height: 0)
        } else {
            return path.cgPath
        }

        // A literal 0 radius produces a path with no corner arcs, which cannot
        // be interpolated against a rounded one. `.leastNonzeroMagnitude` is
        // visually identical to a square corner and keeps the arcs.
        let radius = max(keyholeCornerRadius, .leastNonzeroMagnitude)
        path.append(UIBezierPath(roundedRect: hole, cornerRadius: radius))

        return path.cgPath
    }

    // MARK: Actions

    @objc private func backdropTapped(_ recognizer: UITapGestureRecognizer) {
        handleTap(at: recognizer.location(in: self))
    }

    /// A tap at `point`, in this view's space. Inside the lit area it counts as a tap on the target;
    /// anywhere else the dim consumes it and nothing happens. Tested against the drawn shape,
    /// so a large corner radius does not make the still-dimmed corners behave like the target.
    func handleTap(at point: CGPoint) {
        guard let onTargetTapped, hotspotPath?.contains(point) == true else { return }
        onTargetTapped()
    }

    /// Bounding box of the keyhole, including its spread. `nil` when there is no
    /// hole.
    ///
    /// A bounding box, not the drawn shape — the drawn hole is rounded by
    /// `keyholeCornerRadius`. Used for layout and for the accessibility frame,
    /// both of which want a rect; the tap test uses the rounded path instead so
    /// the visibly-dimmed corners do not count as target taps.
    var hotspotRect: CGRect? {
        keyholeRect?.insetBy(dx: -keyholeSpread, dy: -keyholeSpread)
    }

    /// The keyhole exactly as drawn, for hit testing.
    private var hotspotPath: UIBezierPath? {
        guard let hotspotRect else { return nil }
        return UIBezierPath(
            roundedRect: hotspotRect,
            cornerRadius: max(keyholeCornerRadius, 0)
        )
    }

    // MARK: Accessibility

    /// Rebuilds what VoiceOver sees, which is **not** the same as what a sighted
    /// user sees.
    ///
    /// A sighted user aims at a hole in the dim; VoiceOver has no aim, so the
    /// target hotspot has to exist as its own element. Getting this wrong is not
    /// cosmetic: a tooltip with no close button and no action button, whose only
    /// way out is tapping the target, would otherwise leave a VoiceOver user with
    /// **no way out at all**. The dim does nothing, so it has no element.
    private func refreshAccessibility() {
        var elements: [UIAccessibilityElement] = []

        if onTargetTapped != nil, let hole = hotspotRect {
            // Copy describes what activating it *does*, not what it points at.
            // The tooltip does not forward the tap to the host app's element, so
            // copy like "activates the element this tip points at" would promise
            // something the code cannot deliver.
            let hotspot = hotspotElement
            hotspot.accessibilityFrameInContainerSpace = hole
            hotspot.onActivate = { [weak self] in self?.onTargetTapped?() }
            elements.append(hotspot)
        }

        // Without a hotspot nothing here is actionable: stay out of the
        // accessibility tree so VoiceOver goes straight to the card instead of
        // stopping on a full-screen element that does nothing.
        isAccessibilityElement = false
        accessibilityElements = elements.isEmpty ? nil : elements
    }
}

// MARK: - Accessibility Element

/// An accessibility element that runs a closure when VoiceOver activates it.
///
/// `UIAccessibilityElement` has no built-in activation hook, so the only way to
/// make a region of a view independently actionable is to override
/// `accessibilityActivate()`.
private final class TooltipActionElement: UIAccessibilityElement {

    /// Called on a VoiceOver double-tap.
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}
