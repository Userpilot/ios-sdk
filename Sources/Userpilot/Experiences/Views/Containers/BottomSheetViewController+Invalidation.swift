//
//  BottomSheetViewController+Invalidation.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Re-resolving a sheet's surface after it is already on screen. See ``UPSurfaceInvalidation`` for
//  what can invalidate a resolved surface and which of those the host can opt out of.
//

import UIKit

extension BottomSheetViewController {

    /// Resolves the surface again from the inputs it was built with.
    ///
    /// Safe to call repeatedly: `applySurfaceStyle` recomputes fill, backdrop, mask, geometry, inset
    /// and content host from scratch every time, and each of those is an assignment rather than an
    /// accumulation. That is what makes this the whole of the update path — there is no partial
    /// "refresh" that could leave two of them disagreeing.
    func reapplySurfaceStyle() {
        guard let inputs = lastSurfaceInputs else { return }
        applySurfaceStyle(
            backgroundColor: inputs.backgroundColor,
            cornerRadius: inputs.cornerRadius,
            backdropEnabled: inputs.backdropEnabled,
            backdropColor: inputs.backdropColor,
            surfaceMaterial: inputs.surfaceMaterial
        )
    }

    /// Starts listening for the things that can change a resolved surface while it is presented.
    ///
    /// Overlay changes are always honoured — glass-on-glass is a rendering fault, not a preference.
    /// The accessibility and appearance signals are gated on
    /// `Config.liquidGlassAccessibilityAdaptation(_:)`.
    func observeSurfaceInvalidations() {
        UPSurfaceInvalidation.observe(self) { [weak self] in
            self?.reapplySurfaceStyle()
        }
    }
}
