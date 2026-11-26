//
//  CaptureUploadDialogs.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Presents the confirmation sheet, the upload progress card and the capture alerts, including the
//  alerts with no upload: invalid link, used QR code and "Can't capture yet".
//

import UIKit

/// Capture dialogs, render-only and main-confined; replaceable in tests. Every decision about what to
/// show and what a button does stays with `BuilderCaptureCoordinator`.
internal protocol CaptureDialogShowing: AnyObject {
    /// Presents the confirmation sheet; `completion` reports the operator's choice once, after dismissal.
    func showConfirmation(
        annotatedScreenshot: UIImage,
        targetableElementCount: Int,
        suggestedScreenName: String,
        from presenter: UIViewController,
        completion: @escaping (CaptureConfirmationViewController.Outcome) -> Void
    )
    /// Shows the blocking progress card unless it is already on screen.
    func showProgress(from presenter: UIViewController?)
    /// Replaces the progress card, if any, with the system alert for `alert`.
    func showAlert(
        _ alert: CaptureUploadAlert,
        from presenter: UIViewController?,
        onAction: @escaping (CaptureUploadAlert.Action) -> Void
    )
}

/// Shows at most one upload dialog at a time from the given presenter.
internal final class CaptureUploadDialogs: CaptureDialogShowing {
    private weak var progress: CaptureUploadProgressViewController?

    func showConfirmation(
        annotatedScreenshot: UIImage,
        targetableElementCount: Int,
        suggestedScreenName: String,
        from presenter: UIViewController,
        completion: @escaping (CaptureConfirmationViewController.Outcome) -> Void
    ) {
        let confirmation = CaptureConfirmationViewController(
            annotatedScreenshot: annotatedScreenshot,
            targetableElementCount: targetableElementCount,
            suggestedScreenName: suggestedScreenName,
            completion: completion
        )
        presenter.present(confirmation, animated: true)
    }

    func showProgress(from presenter: UIViewController?) {
        guard progress == nil, let presenter else { return }
        let controller = CaptureUploadProgressViewController()
        progress = controller
        Self.present(controller, from: presenter)
    }

    func showAlert(
        _ alert: CaptureUploadAlert,
        from presenter: UIViewController?,
        onAction: @escaping (CaptureUploadAlert.Action) -> Void
    ) {
        dismissProgress { [weak presenter] in
            guard let presenter else { return }
            Self.present(alert.makeController(onAction: onAction), from: presenter)
        }
    }

    /// Completion runs after the card is gone, or at once when none is showing.
    private func dismissProgress(completion: @escaping () -> Void) {
        guard let controller = progress, controller.presentingViewController != nil else {
            progress = nil
            completion()
            return
        }
        progress = nil
        controller.dismiss(animated: true, completion: completion)
    }

    /// Replaces any capture modal still on screen, such as an alert that is finishing its dismissal.
    private static func present(_ controller: UIViewController, from presenter: UIViewController) {
        guard presenter.presentedViewController != nil else {
            presenter.present(controller, animated: true)
            return
        }
        presenter.dismiss(animated: false) { [weak presenter] in
            presenter?.present(controller, animated: true)
        }
    }
}
