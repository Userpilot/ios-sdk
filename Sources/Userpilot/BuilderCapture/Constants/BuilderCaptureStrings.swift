//
//  BuilderCaptureStrings.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  English-only copy for the Builder capture controls and alerts.
//

import Foundation

internal enum BuilderCaptureStrings {
    // MARK: Capture controls
    static let captureButtonAccessibilityLabel = "Userpilot capture screen"
    static let captureButtonAccessibilityHint = "Double tap to capture. Long press to exit capture mode."
    static let exitAccessibilityLabel = "Exit Userpilot capture mode"

    // MARK: Confirmation
    static let confirmationTitle = "Save screen capture"
    static let previewAccessibilityLabel = "Captured screen preview"
    static let screenNamePlaceholder = "Screen name"
    static let save = "Save"
    /// `%d` is the number of targetable elements.
    static let targetableSummaryFormat = "%d targetable elements found, outlined above."
    static let noTargetsWarning = """
        Warning: no targetable elements were found on this screen. \
        Tooltips authored against this capture will not be able to \
        resolve a target. Set an accessibility identifier on the views \
        you want to target, or apply .userpilotTarget(_:) in SwiftUI.
        """

    // MARK: Upload progress
    static let uploadingTitle = "Uploading screenshot"
    static let uploadingMessage = "Keep the app open and in the foreground until the upload finishes."

    // MARK: Alerts
    static let savedTitle = "Saved"
    static let savedMessage = "Continue in the web app."
    static let invalidQRTitle = "Invalid QR code"
    static let invalidQRMessage = "This QR code isn't valid. Scan a new one."
    static let sessionEndedTitle = "Session ended"
    static let sessionEndedMessage = "Capture session ended. Scan a new QR code."
    static let androidQRTitle = "QR code for Android"
    static let androidQRMessage = """
        This QR code was created for Android. Scan it with an Android device, \
        or create an iOS QR code in the builder.
        """
    static let usedQRTitle = "QR code already used"
    static let usedQRMessage = "This QR code was already used. Scan a new one."
    static let notReadyTitle = "Can't capture yet"
    static let notReadyMessage = "Sign in to the app and open a screen Userpilot tracks, then tap Capture again."
    static let captureFailedTitle = "Capture failed"
    static let tooLargeMessage = "This screen is too large to upload."
    /// `%d` is the HTTP status code.
    static let rejectedMessageFormat = "This screen couldn't be saved (error %d)."
    static let prepareFailedMessage = "The screenshot couldn't be prepared. Capture it again."
    static let uploadFailedTitle = "Upload failed"
    static let uploadFailedMessage = "Check your connection and tap Retry."
    static let throttledMessage = "Too many uploads. Try again in a moment."

    // MARK: Buttons
    static let retry = "Retry"
    static let cancel = "Cancel"
    static let okay = "OK"
}
