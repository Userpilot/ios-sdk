//
//  CaptureUploadAlerts.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps capture outcomes to operator alert copy and builds the matching system alert.
//

import UIKit

// MARK: - CaptureUploadAlert

/// What to show after an upload or a refused capture link: English copy and its buttons, in display order.
/// Pure content, so the mapping is tested without presenting UI.
internal struct CaptureUploadAlert: Equatable {

    /// What the coordinator does when the operator taps a button.
    enum Action: Equatable {
        /// Start a new run with the same prepared capture.
        case retry
        /// Close the alert and drop any prepared capture; capture mode stays as it is.
        case discard
        /// The result ends capture mode as it arrives; OK only closes the alert. A new QR scan is needed.
        case endSession
    }

    struct Button: Equatable {
        let title: String
        let action: Action
    }

    let title: String
    let message: String
    let buttons: [Button]

    /// True for the results that end capture mode: Saved and the token failures.
    var endsSession: Bool { buttons.contains { $0.action == .endSession } }
}

// MARK: - Outcomes

internal extension CaptureUploadAlert {

    private typealias Strings = BuilderCaptureStrings

    /// Saved (any 2xx), which ends capture mode: one QR code is one capture.
    static var saved: CaptureUploadAlert {
        CaptureUploadAlert(
            title: Strings.savedTitle,
            message: Strings.savedMessage,
            buttons: [Button(title: Strings.okay, action: .endSession)]
        )
    }

    /// The alert for a run that ended without a save. Copy never includes the token or a URL; the only
    /// response text it shows is a 422's `details` sentence.
    static func failure(_ error: CaptureUploadError) -> CaptureUploadAlert {
        switch error {
        case .invalidToken:
            return CaptureUploadAlert(title: Strings.invalidQRTitle, message: Strings.invalidQRMessage,
                                      buttons: [Button(title: Strings.okay, action: .endSession)])
        case .sessionExpired:
            return CaptureUploadAlert(
                title: Strings.sessionEndedTitle,
                message: Strings.sessionEndedMessage,
                buttons: [Button(title: Strings.okay, action: .endSession)]
            )
        case .tooLarge:
            return captureFailed(message: Strings.tooLargeMessage)
        case let .rejected(statusCode, reason):
            return captureFailed(message: reason ?? String(format: Strings.rejectedMessageFormat, statusCode))
        case .throttled:
            return uploadFailed(message: Strings.throttledMessage)
        case .transient, .cancelled:
            return uploadFailed(message: Strings.uploadFailedMessage)
        }
    }

    /// The PNG or document could not be encoded, so nothing was sent.
    static var preparationFailed: CaptureUploadAlert {
        captureFailed(message: Strings.prepareFailedMessage)
    }

    /// A capture link with a missing or invalid value; no capture mode starts.
    static var invalidLink: CaptureUploadAlert {
        CaptureUploadAlert(title: Strings.invalidQRTitle, message: Strings.invalidQRMessage,
                           buttons: [Button(title: Strings.okay, action: .discard)])
    }

    /// A capture link created for Android; no capture mode starts.
    static var otherPlatformLink: CaptureUploadAlert {
        CaptureUploadAlert(title: Strings.androidQRTitle, message: Strings.androidQRMessage,
                           buttons: [Button(title: Strings.okay, action: .discard)])
    }

    /// A capture link whose session already ended in this process.
    static var linkAlreadyUsed: CaptureUploadAlert {
        CaptureUploadAlert(
            title: Strings.usedQRTitle,
            message: Strings.usedQRMessage,
            buttons: [Button(title: Strings.okay, action: .discard)]
        )
    }

    /// Capture tapped without an identified user or a tracked screen; nothing is taken, capture mode stays.
    static var cannotCaptureYet: CaptureUploadAlert {
        CaptureUploadAlert(
            title: Strings.notReadyTitle,
            message: Strings.notReadyMessage,
            buttons: [Button(title: Strings.okay, action: .discard)]
        )
    }

    private static func captureFailed(message: String) -> CaptureUploadAlert {
        CaptureUploadAlert(
            title: Strings.captureFailedTitle,
            message: message,
            buttons: [Button(title: Strings.okay, action: .discard)]
        )
    }

    private static func uploadFailed(message: String) -> CaptureUploadAlert {
        CaptureUploadAlert(
            title: Strings.uploadFailedTitle,
            message: message,
            buttons: [
                Button(title: Strings.cancel, action: .discard),
                Button(title: Strings.retry, action: .retry)
            ]
        )
    }
}

// MARK: - System alert

internal extension CaptureUploadAlert {

    /// The standard system alert. Cancel takes the cancel slot when Retry is offered; Retry is preferred.
    func makeController(onAction: @escaping (Action) -> Void) -> UIAlertController {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        for button in buttons {
            let style: UIAlertAction.Style = button.action == .discard && buttons.count > 1 ? .cancel : .default
            let action = UIAlertAction(title: button.title, style: style) { _ in onAction(button.action) }
            controller.addAction(action)
            if button.action == .retry { controller.preferredAction = action }
        }
        return controller
    }
}
