//
//  UPSurfaceInvalidation.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The things that can change a resolved surface *after* it is on screen, and the one way a
//  presented sheet or dialog subscribes to them.
//
//  A surface is resolved once, when its theme is applied. Three things can invalidate that answer
//  while the experience is still visible:
//
//  1. Another Userpilot overlay window appears or disappears, which switches large glass surfaces
//     to solid and back — always honoured, because glass-on-glass is a rendering fault rather than
//     a preference.
//  2. Reduce Transparency or Increase Contrast changes, which affects the tint and backdrop the SDK
//     picks itself.
//  3. The interface style changes, which changes the resolved theme colours — handled by the
//     containers in `traitCollectionDidChange`, since traits are per-view rather than global.
//
//  2 and 3 are gated on `Config.liquidGlassAccessibilityAdaptation(_:)`; 1 is not.
//

import UIKit

internal enum UPSurfaceInvalidation {

    /// The inputs a surface was resolved from, kept so the same question can be asked again.
    ///
    /// Re-resolving from the original inputs — rather than patching the current appearance — is what
    /// makes the update idempotent: every derived value is recomputed together, so none of them can
    /// drift out of step with the others.
    internal struct Inputs {
        let backgroundColor: UIColor
        let cornerRadius: CGFloat
        let backdropEnabled: Bool
        let backdropColor: UIColor
        let surfaceMaterial: SurfaceMaterial?
    }

    /// Calls `onInvalidated` on the main thread whenever `observer`'s surface may need re-resolving.
    ///
    /// The observers are block-based and tied to `observer`'s lifetime through the returned tokens,
    /// which the SDK stores on the observer itself — so nothing has to be unregistered by hand and a
    /// dismissed experience stops being notified as soon as it is released.
    static func observe(_ observer: UIViewController, onInvalidated: @escaping () -> Void) {
        var tokens: [NSObjectProtocol] = []
        let center = NotificationCenter.default

        // Always: a second overlay must not leave two large glass surfaces stacked.
        tokens.append(
            center.addObserver(
                forName: UPOverlayVisibility.didChangeNotification,
                object: nil,
                queue: .main
            ) { _ in onInvalidated() }
        )

        // Gated: these are the SDK's own colour choices reacting to the user's settings.
        for name in [
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification
        ] {
            tokens.append(
                center.addObserver(forName: name, object: nil, queue: .main) { _ in onInvalidated() }
            )
        }

        objc_setAssociatedObject(
            observer,
            &UPSurfaceInvalidationKeys.tokens,
            UPObservationTokens(tokens: tokens),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

/// Holds notification tokens for as long as its owner lives, removing them on the way out.
private final class UPObservationTokens {

    private let tokens: [NSObjectProtocol]

    init(tokens: [NSObjectProtocol]) {
        self.tokens = tokens
    }

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}

private enum UPSurfaceInvalidationKeys {
    static var tokens: UInt8 = 0
}

/// Convenience so the containers can name the type without the enclosing namespace.
internal typealias UPSurfaceInputs = UPSurfaceInvalidation.Inputs
