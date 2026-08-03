//
//  UPGlassEffectView.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A background view that renders Liquid Glass where it is permitted and a solid colour
//  everywhere else. Call sites configure it once and never branch on iOS version, Xcode
//  version, or host configuration themselves.
//

import UIKit

/// Which Liquid Glass variant to request.
internal enum UPGlassStyle {

    /// Frosted, diffuse. **The default for SDK chrome.**
    ///
    /// Chosen over `clear` after the Phase 0 spike: `clear` behaves like a strong optical
    /// lens and distorts busy host content enough to compromise glyphs and text drawn on
    /// top of it. Measured during the iOS 26 spike (Q1a).
    case regular

    /// Highly transparent and strongly refractive. Only for elements over calm content,
    /// and only after checking it against real screens.
    case clear
}

/// Background view that is Liquid Glass on iOS 26+ when allowed, and a plain coloured view
/// otherwise.
///
/// Add it as the lowest subview of the thing it backs and pin it to the edges; put content
/// in ``contentContainer`` so it composites correctly against the material.
internal final class UPGlassEffectView: UIView {

    // MARK: Properties

    /// The view content should be added to.
    ///
    /// When glass is active this is the effect view's `contentView` — required for correct
    /// vibrancy compositing, and the reason content must not be added to the effect view
    /// directly. Otherwise it is `self`.
    private(set) var contentContainer: UIView

    /// Colour used when glass is unavailable or disabled. Also the tint source when glass
    /// is active.
    private let fallbackBackgroundColor: UIColor

    /// Tint alpha to apply to ``fallbackBackgroundColor`` when rendering as glass.
    /// `nil` leaves the glass untinted.
    private let tintAlpha: CGFloat?

    /// Whether this instance actually resolved to glass. Useful for callers that need to
    /// adjust surrounding styling (for example dropping a hand-rolled shadow, which glass
    /// supplies itself).
    private(set) var isRenderingGlass: Bool = false

    /// The view actually rendering the material, held so its shape can be set. Nil when this
    /// resolved to a solid fill.
    private weak var glassEffectView: UIVisualEffectView?

    /// The effect detached for an animation, kept so it can be put back.
    private var pendingEffect: UIVisualEffect?

    // MARK: Initializers

    /// - Parameters:
    ///   - style: Glass variant to request when glass is permitted.
    ///   - allowsGlass: The resolver's verdict for this element. Pass
    ///     `resolver.allowsGlass(for:)` — this view deliberately does not resolve
    ///     capability itself, so the decision stays in one place and stays testable.
    ///   - fallbackBackgroundColor: Colour used when rendering solid; tint source when
    ///     rendering glass.
    ///   - tintAlpha: Alpha for the glass tint, or `nil` for untinted glass.
    ///   - isInteractive: Whether the glass reacts to touches by expanding and
    ///     highlighting. Enable for glass that backs a control.
    ///   - appearance: Pins the material to a light or dark rendering, rather than following the
    ///     host app's. Used when a theme colour has been replaced by Apple's material but its
    ///     light-or-dark intent should be kept.
    init(
        style: UPGlassStyle = .regular,
        allowsGlass: Bool,
        fallbackBackgroundColor: UIColor,
        tintAlpha: CGFloat? = nil,
        isInteractive: Bool = false,
        appearance: UIUserInterfaceStyle? = nil
    ) {
        self.fallbackBackgroundColor = fallbackBackgroundColor
        self.tintAlpha = tintAlpha
        self.contentContainer = UIView()

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        if let appearance {
            overrideUserInterfaceStyle = appearance
        }

        if allowsGlass, let effectView = Self.makeGlassEffectView(
            style: style,
            tintColor: tintAlpha.map { fallbackBackgroundColor.withAlphaComponent($0) },
            isInteractive: isInteractive
        ) {
            install(effectView)
            contentContainer = effectView.contentView
            isRenderingGlass = true
        } else {
            backgroundColor = fallbackBackgroundColor
            contentContainer = self
        }
    }

    /// Installs a resolved fill as the background of `container`, pinned to its edges.
    ///
    /// Every glass surface in the SDK did this by hand — the bottom sheet, the centre dialog, carousel
    /// cards and the survey list — and the copies had drifted: two of them built a tinted material
    /// directly, so they never saw `liquidGlassDefaultBackground` and never pinned an appearance.
    ///
    /// Pinning the appearance on the container is the part that is easy to miss. The chrome inside a
    /// card draws its *own* glass — the dismiss button most visibly — and glass renders from the trait
    /// environment, not from the card's colour. Without it a light glass circle sits on a dark card.
    ///
    /// - Returns: The installed background, for a caller that needs to remove it later, or `nil` when
    ///   the fill is solid.
    @discardableResult
    static func install(_ fill: UPSurfaceFill, in container: UIView) -> UPGlassEffectView? {
        container.overrideUserInterfaceStyle = fill.appearance ?? .unspecified

        guard case .solid(let color) = fill else {
            let background = UPGlassEffectView(fill: fill)
            container.insertSubview(background, at: 0)
            NSLayoutConstraint.activate([
                background.topAnchor.constraint(equalTo: container.topAnchor),
                background.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                background.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                background.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
            container.backgroundColor = .clear
            return background
        }

        container.backgroundColor = color
        return nil
    }

    /// Opaque stand-in for Apple's sheet material, for builds and systems that cannot render it.
    ///
    /// Chosen against the measured material: light reads ~rgb(250), which `systemBackground`
    /// matches; dark reads ~rgb(39), closest to `tertiarySystemBackground` (~44).
    private static func opaqueEquivalent(of appearance: UIUserInterfaceStyle) -> UIColor {
        let traits = UITraitCollection(userInterfaceStyle: appearance)
        return appearance == .dark
            ? UIColor.tertiarySystemBackground.resolvedColor(with: traits)
            : UIColor.systemBackground.resolvedColor(with: traits)
    }

    /// Builds the background for a surface whose appearance has already been resolved by
    /// ``GlassCapabilityResolving/surfaceStyle(themeBackground:themeBackdrop:themeBackdropEnabled:appearance:)``.
    ///
    /// This is the initializer surfaces should use: the fill carries the whole decision, so no call
    /// site re-derives whether to tint, what to tint with, or which appearance to pin.
    convenience init(fill: UPSurfaceFill, style: UPGlassStyle = .regular) {
        switch fill {
        case .solid(let color):
            self.init(style: style, allowsGlass: false, fallbackBackgroundColor: color)

        case .appleGlass(let appearance):
            // Untinted — Apple's sheet material is a material, not a colour, so anything added on
            // top of it is a departure rather than a default. The appearance is pinned so the
            // theme's light-or-dark intent survives having its colour replaced.
            self.init(
                style: style,
                allowsGlass: true,
                fallbackBackgroundColor: Self.opaqueEquivalent(of: appearance),
                tintAlpha: nil,
                appearance: appearance
            )

        case .tintedGlass(let color, let alpha):
            self.init(
                style: style,
                allowsGlass: true,
                fallbackBackgroundColor: color,
                tintAlpha: alpha
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    /// Rounds the material's corners.
    ///
    /// Applied to the effect view rather than to `self`, because the effect view is what
    /// draws the edge treatment. Clipping stays off for the same reason — glass renders its
    /// own boundary and clipping it produces a hard, flat edge.
    func applyGlassCorners(_ radius: UPCornerRadius, edges: UPCornerEdges = .all) {
        let target = subviews.first(where: { $0 is UIVisualEffectView }) ?? self
        target.applyCorners(radius, edges: edges, clip: !isRenderingGlass)
    }

    // MARK: Private

    /// Builds the effect view, or returns `nil` when this build/OS cannot.
    ///
    /// The `#if compiler(>=6.2)` gate is what allows the SDK to keep compiling on Xcode
    /// versions that predate the iOS 26 SDK: Swift does not name-resolve symbols inside an
    /// inactive `#if` branch, so `UIGlassEffect` is invisible there rather than missing.
    private static func makeGlassEffectView(
        style: UPGlassStyle,
        tintColor: UIColor?,
        isInteractive: Bool
    ) -> UIVisualEffectView? {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: style == .clear ? .clear : .regular)
            effect.isInteractive = isInteractive
            effect.tintColor = tintColor
            return UIVisualEffectView(effect: effect)
        }
        #endif
        return nil
    }

    /// Gives the material its own shape.
    ///
    /// Without this the effect is merely *clipped* by the card that contains it, and UIKit cannot
    /// draw the material's edge treatment along a curve it does not know about — which reads as a
    /// hard, flat edge, most visibly on a sheet's asymmetric corners. Apple exposes corner
    /// configuration on the effect for exactly this reason.
    ///
    /// The effect is deliberately left **unclipped**: clipping it is the thing that flattens the
    /// edge. Shaping replaces clipping here, it does not accompany it.
    ///
    /// Values come from the card that already resolved them, so the container, the material and the
    /// backdrop hole are all cut from one set of numbers.
    ///
    /// - Parameters:
    ///   - top: Radius for the two top corners.
    ///   - bottom: Radius for the two bottom corners. Pass the same value as `top` for a uniform
    ///     shape, which is what a centre dialog needs.
    func applyMaterialCorners(top: CGFloat, bottom: CGFloat) {
        guard isRenderingGlass else { return }
        applyCorners(top: top, bottom: bottom, clip: false)
        glassEffectView?.applyCorners(top: top, bottom: bottom, clip: false)
    }

    /// Detaches the material so it can be animated in, and reports whether that is possible.
    ///
    /// Apple's way to animate a `UIVisualEffectView` is to move its `effect` between `nil` and the
    /// desired effect inside an animation block; UIKit interpolates the material itself. Fading the
    /// view's `alpha` instead cross-fades a fully-formed material, which is not the same
    /// materialisation and is explicitly not how the API is meant to be driven.
    ///
    /// - Returns: `true` when there is a material to animate, so the caller can fall back to an
    ///   opacity fade for a solid surface or on an OS without glass.
    @discardableResult
    func prepareMaterialForAnimation() -> Bool {
        guard isRenderingGlass, let effectView = glassEffectView else { return false }
        pendingEffect = effectView.effect
        effectView.effect = nil
        return true
    }

    /// Restores the material. Call inside an animation block, having called
    /// ``prepareMaterialForAnimation()`` first.
    func materialize() {
        guard let effectView = glassEffectView, let pendingEffect else { return }
        effectView.effect = pendingEffect
    }

    /// Removes the material. Call inside an animation block; the effect is remembered so a later
    /// ``materialize()`` can put it back.
    func dematerialize() {
        guard let effectView = glassEffectView, effectView.effect != nil else { return }
        pendingEffect = effectView.effect
        effectView.effect = nil
    }

    private func install(_ effectView: UIVisualEffectView) {
        effectView.translatesAutoresizingMaskIntoConstraints = false
        glassEffectView = effectView
        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
