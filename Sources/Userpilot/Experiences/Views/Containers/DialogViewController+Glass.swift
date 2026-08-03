//
//  DialogViewController+Glass.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The backdrop mask that lets a glass dialog refract the host app instead of the dimming
//  scrim. Split out of `DialogViewController.swift` to keep that file under the SwiftLint
//  file-length limit, mirroring `BottomSheetViewController+Glass.swift`.
//

import UIKit

// MARK: - Backdrop mask

extension DialogViewController {

    /// Cuts the dialog's shape out of the dimming backdrop so a glass surface refracts the host
    /// app rather than the scrim. All four corners, unlike the bottom sheet.
    ///
    /// The customer's backdrop colour and opacity are untouched — only the region the dialog
    /// already covers is removed, which the user cannot see through anyway.
    ///
    /// Suppressed while the dialog is moving (`suspendsBackdropMask`): the path is cut at a fixed
    /// frame, so leaving it active during a transition would show an undimmed, card-shaped hole at
    /// the resting position while the dialog was still travelling.
    func updateBackdropMask() {
        guard masksBackdrop, !suspendsBackdropMask, mainContainerView.bounds.height > 0 else {
            backdropMask.remove(from: dimmedView)
            return
        }

        // Uniform here — a centre dialog's four corners share one radius.
        let hole = dimmedView.convert(mainContainerView.bounds, from: mainContainerView)
        backdropMask.apply(
            to: dimmedView,
            geometry: UPBackdropMaskGeometry(
                bounds: dimmedView.bounds,
                hole: hole,
                topRadius: appliedCornerRadius,
                bottomRadius: appliedCornerRadius
            )
        )
    }
}

// MARK: - Content hosting

extension DialogViewController {

    /// Pins the content inside `host` with the card's padding, replacing any previous set.
    ///
    /// The constraints are recreated rather than retargeted because a constraint's `firstItem` is
    /// immutable; deactivating the previous set first is what stops repeated calls accumulating.
    func hostContent(in host: UIView) {
        NSLayoutConstraint.deactivate(contentHostConstraints)
        host.addSubview(contentView)
        contentHostConstraints = [
            contentView.leadingAnchor.constraint(
                equalTo: host.leadingAnchor,
                constant: UPCardMetrics.contentHorizontal),
            contentView.trailingAnchor.constraint(
                equalTo: host.trailingAnchor,
                constant: UPCardMetrics.contentHorizontal.negative),
            contentView.topAnchor.constraint(
                equalTo: host.topAnchor,
                constant: UPCardMetrics.dialogContentTop),
            contentView.bottomAnchor.constraint(
                equalTo: host.bottomAnchor,
                constant: UPCardMetrics.dialogContentBottom.negative)
        ]
        NSLayoutConstraint.activate(contentHostConstraints)
    }
}

// MARK: - Re-resolving a presented dialog

extension DialogViewController {

    /// Resolves the surface again from the inputs it was built with. See the sheet's equivalent for
    /// why re-running the whole of `applySurfaceStyle` is the update path.
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
    func observeSurfaceInvalidations() {
        UPSurfaceInvalidation.observe(self) { [weak self] in
            self?.reapplySurfaceStyle()
        }
    }
}
