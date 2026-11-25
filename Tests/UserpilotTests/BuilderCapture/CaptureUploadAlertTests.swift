//
//  CaptureUploadAlertTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies each capture outcome maps to the agreed operator copy and actions.
//

import XCTest
@testable import Userpilot

final class CaptureUploadAlertTests: XCTestCase {

    func testSavedEndsCaptureMode() {
        XCTAssertEqual(CaptureUploadAlert.saved, CaptureUploadAlert(
            title: "Saved", message: "Continue in the web app.", buttons: [.init(title: "OK", action: .endSession)]))
        XCTAssertTrue(CaptureUploadAlert.saved.endsSession)
    }

    func testTokenFailuresEndCaptureMode() {
        XCTAssertTrue(CaptureUploadAlert.failure(.invalidToken).endsSession)
        XCTAssertTrue(CaptureUploadAlert.failure(.sessionExpired).endsSession)
        XCTAssertFalse(CaptureUploadAlert.failure(.rejected(statusCode: 422)).endsSession)
        XCTAssertEqual(CaptureUploadAlert.failure(.invalidToken), CaptureUploadAlert(
            title: "Invalid QR code", message: "This QR code isn't valid. Scan a new one.",
            buttons: [.init(title: "OK", action: .endSession)]))
        XCTAssertEqual(CaptureUploadAlert.failure(.sessionExpired), CaptureUploadAlert(
            title: "Session ended", message: "Capture session ended. Scan a new QR code.",
            buttons: [.init(title: "OK", action: .endSession)]))
    }

    func testCaptureFailuresDiscardWithOK() {
        let okOnly = [CaptureUploadAlert.Button(title: "OK", action: .discard)]
        XCTAssertEqual(CaptureUploadAlert.failure(.tooLarge), CaptureUploadAlert(
            title: "Capture failed", message: "This screen is too large to upload.", buttons: okOnly))
        XCTAssertEqual(CaptureUploadAlert.failure(.rejected(statusCode: 422)), CaptureUploadAlert(
            title: "Capture failed", message: "This screen couldn't be saved (error 422).", buttons: okOnly))
        let sentence = "The screenshot must be a PNG image."
        XCTAssertEqual(CaptureUploadAlert.failure(.rejected(statusCode: 422, reason: sentence)), CaptureUploadAlert(
            title: "Capture failed", message: sentence, buttons: okOnly))
        XCTAssertEqual(CaptureUploadAlert.preparationFailed, CaptureUploadAlert(
            title: "Capture failed", message: "The screenshot couldn't be prepared. Capture it again.",
            buttons: okOnly))
    }

    func testUploadFailuresOfferCancelAndRetry() {
        let buttons = [
            CaptureUploadAlert.Button(title: "Cancel", action: .discard), .init(title: "Retry", action: .retry)
        ]
        XCTAssertEqual(CaptureUploadAlert.failure(.throttled), CaptureUploadAlert(
            title: "Upload failed", message: "Too many uploads. Try again in a moment.", buttons: buttons))
        let connection = CaptureUploadAlert(
            title: "Upload failed", message: "Check your connection and tap Retry.", buttons: buttons)
        XCTAssertEqual(CaptureUploadAlert.failure(.transient(statusCode: 503)), connection)
        XCTAssertEqual(CaptureUploadAlert.failure(.transient(statusCode: nil)), connection)
    }

    func testAlertsWithoutAnUploadOnlyClose() {
        let okOnly = [CaptureUploadAlert.Button(title: "OK", action: .discard)]
        XCTAssertEqual(CaptureUploadAlert.invalidLink, CaptureUploadAlert(
            title: "Invalid QR code", message: "This QR code isn't valid. Scan a new one.", buttons: okOnly))
        XCTAssertEqual(CaptureUploadAlert.linkAlreadyUsed, CaptureUploadAlert(
            title: "QR code already used", message: "This QR code was already used. Scan a new one.",
            buttons: okOnly))
        XCTAssertEqual(CaptureUploadAlert.cannotCaptureYet, CaptureUploadAlert(
            title: "Can't capture yet",
            message: "Sign in to the app and open a screen Userpilot tracks, then tap Capture again.",
            buttons: okOnly))
    }

    func testSystemAlertKeepsButtonOrderAndPrefersRetry() {
        let controller = CaptureUploadAlert.failure(.transient(statusCode: nil)).makeController { _ in }
        XCTAssertEqual(controller.preferredStyle, .alert)
        XCTAssertEqual(controller.actions.map(\.title), ["Cancel", "Retry"])
        XCTAssertEqual(controller.actions.map(\.style), [.cancel, .default])
        XCTAssertEqual(controller.preferredAction?.title, "Retry")
    }
}
