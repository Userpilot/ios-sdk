//
//  UPButtonView+Shape.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  What shape a glass button takes, how it sizes itself, and how it acknowledges a press. Split out of
//  `UPButtonView.swift` to keep that file within the 400-line limit.
//

import UIKit

extension UPButtonView {

    /// The shape a glass button takes, and the whole of that decision.
    ///
    /// Three outcomes, in priority order:
    ///
    ///  1. ``wrapsContentWidth`` — a capsule. A pill that hugs its title is a distinct kind of
    ///     control (NPS's follow-up pair).
    ///  2. Inside a card — a capsule too, taking priority over the theme's radius. This is Apple's
    ///     own shape for a glass control, and the shape that actually reads as belonging inside a
    ///     rounded card.
    ///
    ///     Strict concentricity was tried first and rejected on the screen: concentric means
    ///     `cardRadius − gap`, which for Apple's 27 pt alert radius and the card's 20 pt padding is
    ///     7 pt — geometrically correct, and indistinguishable from the flat corner it replaced.
    ///     Apple's own sheets look concentric only because their cards are 36–52 pt, where the same
    ///     subtraction leaves something substantial. The capsule is what Apple ships for controls,
    ///     and it needs no arithmetic to stay right as padding changes.
    ///  3. Anything else — the theme's radius, untouched. Full-screen experiences have no card, so
    ///     this is what they get, and it is why nothing outside a sheet or dialog changes shape.
    ///
    /// `prominentGlass()` defaults to `.capsule`, so case 3 has to say `.fixed` explicitly — leaving
    /// `cornerStyle` alone is what turned every filled button in every experience into a pill.
    @available(iOS 15.0, *)
    func applyGlassCornerStyle(to glass: inout UIButton.Configuration, themeRadius: CGFloat) {
        guard !wrapsContentWidth, !isInsideCard else { return }  // `.capsule` already, by default

        glass.cornerStyle = .fixed
        glass.background.cornerRadius = themeRadius
    }

    /// Whether a card ancestor is publishing a shape for this control to match.
    ///
    /// A card only publishes while glass is in use, so this is false for a solid sheet as well as for
    /// a full-screen experience that has no card at all — both of which keep the theme's radius.
    var isInsideCard: Bool { upNearestCard != nil }

    /// Half the button's height, for a capsule drawn on the layer rather than by a configuration.
    ///
    /// A transparent button takes the legacy path even on iOS 26 — that is what keeps a text or outline
    /// button's background empty — so there is no `UIButton.Configuration` to supply the shape and the
    /// layer has to be rounded directly.
    ///
    /// `bounds.height` is zero when the theme is applied during binding, so it falls back to the height
    /// these buttons are constrained to. ``refreshCornerShapeIfNeeded()`` corrects it once the real
    /// height exists — without the fallback the radius would be 0, which is how "Update score" came out
    /// square.
    var wrappedCapsuleRadius: CGFloat {
        (bounds.height > 0 ? bounds.height : UPButtonView.buttonHeight) / 2
    }

    /// Brings the button's corners up to date once it can see where it lives.
    ///
    /// Needed because the two inputs arrive in an order nothing guarantees: the theme is applied
    /// during binding, while the card only publishes its shape when its surface style is resolved, and
    /// either can happen first. Rather than depend on that ordering, the shape is re-checked on layout
    /// and corrected if the answer has changed.
    func refreshCornerShapeIfNeeded() {
        if #available(iOS 15.0, *), var glass = configuration {
            let target: UIButton.Configuration.CornerStyle =
                (wrapsContentWidth || isInsideCard) ? .capsule : .fixed
            guard glass.cornerStyle != target else { return }

            glass.cornerStyle = target
            if target == .fixed {
                glass.background.cornerRadius = pendingFill?.cornerRadius ?? 0
            }
            configuration = glass
            return
        }

        // The layer-drawn capsule, for a transparent button that never gets a configuration.
        guard wrapsContentWidth, bounds.height > 0 else { return }
        let target = wrappedCapsuleRadius
        guard abs(layer.cornerRadius - target) > 0.5 else { return }
        layer.cornerRadius = target
    }

    /// Press feedback.
    ///
    /// `UPButtonView` is built with `init(frame:)`, which makes it a `.custom` button — and a custom
    /// button does **not** dim its title on touch the way a `.system` one does. On a filled CTA that
    /// went unnoticed; on a text-only button such as NPS's "Ask me later" it meant a tap produced no
    /// acknowledgement whatsoever.
    ///
    /// A slight shrink plus a dim, which reads on both: the fill has something to scale, the text has
    /// something to fade.
    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            animatePressFeedback()
        }
    }

    private func animatePressFeedback() {
        let pressed = isHighlighted
        UIView.animate(
            withDuration: pressed ? 0.08 : 0.22,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.transform = pressed
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
                self.alpha = pressed ? 0.62 : 1
            }
        )
    }

    override var intrinsicContentSize: CGSize {
        if wrapsContentWidth, let title = titleLabel?.text, let font = titleLabel?.font {
            let width = title.size(withAttributes: [.font: font]).width
            return CGSize(
                width: width + Self.wrappedContentPadding,
                height: UPButtonView.buttonHeight
            )
        }

        guard
            let titleLabel = self.titleLabel,
            let text = titleLabel.text,
            let font = titleLabel.font
        else {
            return CGSize(width: self.bounds.width, height: UPButtonView.buttonHeight)
        }
        let edgeInsets = CGFloat(16) // 8 top, 8 bottom ,8 left, 8 right
        let actualHight = text.height(
            withFont: font,
            width: self.bounds.width - edgeInsets) + edgeInsets
        if self.bounds.width == 0 {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = text.size(withAttributes: attributes)
            return CGSize(width: size.width + 40, height: max(actualHight, 40))
        } else {
            return CGSize(width: self.bounds.width, height: max(actualHight, UPButtonView.buttonHeight))
        }
    }
}
