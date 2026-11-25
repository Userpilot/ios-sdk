//
//  BuilderCaptureUploadRunTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Drives the upload retry run on virtual time and the capture-mode lifecycle around its results.
//

import XCTest
@testable import Userpilot

final class BuilderCaptureUploadRunTests: BuilderCaptureCoordinatorTestCase {

    // MARK: - Retry run

    func testTransientFailuresWaitTwoFourAndEightSecondsThenSaveOnTheFourthAttempt() throws {
        coordinator.start(link: makeLink("cap-retry"))
        try save()
        for attempt in 0..<3 {
            try finish(attempt, .failure(.transient(statusCode: 503)))
            try fireLastWait()
        }
        try finish(3, .success(()))

        XCTAssertEqual(delays, [2, 4, 8])
        XCTAssertEqual(remote.uploads.count, 4)
        XCTAssertEqual(Set(remote.uploads.map(\.upload.captureID)), ["cap-retry"])
        XCTAssertEqual(dialogs.alerts, [.saved])
    }

    func testFourTransientFailuresShowRetryAndRetryStartsANewRun() throws {
        coordinator.start(link: makeLink())
        try save()
        for attempt in 0..<4 {
            try finish(attempt, .failure(.transient(statusCode: 503)))
            if attempt < 3 { try fireLastWait() }
        }

        XCTAssertEqual(delays, [2, 4, 8])
        XCTAssertEqual(remote.uploads.count, 4)
        XCTAssertEqual(dialogs.alerts, [.failure(.transient(statusCode: 503))])

        dialogs.tap(.retry)
        XCTAssertEqual(remote.uploads.count, 5)
        try finish(4, .failure(.transient(statusCode: 503)))
        XCTAssertEqual(delays.last, 2, "A new run starts its waits again")
    }

    func testThrottledThenSavedWaitsTenSeconds() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.throttled))
        try fireLastWait()
        try finish(1, .success(()))

        XCTAssertEqual(delays, [10])
        XCTAssertEqual(dialogs.alerts, [.saved])
    }

    func testMixedFailuresStopAtFourAttempts() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.transient(statusCode: 503)))
        try fireLastWait()
        try finish(1, .failure(.throttled))
        try fireLastWait()
        try finish(2, .failure(.transient(statusCode: 503)))
        try fireLastWait()
        try finish(3, .failure(.transient(statusCode: 503)))

        XCTAssertEqual(delays, [2, 10, 8])
        XCTAssertEqual(remote.uploads.count, 4)
        XCTAssertEqual(dialogs.alerts, [.failure(.transient(statusCode: 503))])
    }

    func testSecondThrottleEndsTheRun() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.throttled))
        try fireLastWait()
        try finish(1, .failure(.throttled))

        XCTAssertEqual(delays, [10])
        XCTAssertEqual(remote.uploads.count, 2)
        XCTAssertEqual(dialogs.alerts, [.failure(.throttled)])
    }

    func testTokenSizeAndRejectionFailuresMakeOneAttempt() throws {
        let failures: [CaptureUploadError] = [.sessionExpired, .tooLarge, .rejected(statusCode: 422), .invalidToken]
        for (index, failure) in failures.enumerated() {
            coordinator.start(link: makeLink())
            try save()
            try finish(index, failure.asFailure)

            XCTAssertEqual(remote.uploads.count, index + 1, "\(failure)")
            XCTAssertEqual(dialogs.alerts.last, .failure(failure))
        }
        XCTAssertTrue(delays.isEmpty)
    }

    func testStopDuringAWaitSendsNothingMore() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.transient(statusCode: 503)))

        coordinator.stop()
        try fireLastWait()

        XCTAssertEqual(remote.uploads.count, 1)
        XCTAssertTrue(try XCTUnwrap(waits.last).isCancelled)
        XCTAssertFalse(BuilderCaptureMode.isActive)
    }

    func testLogoutDuringAWaitSendsNothingMore() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.transient(statusCode: 503)))

        owner.logout()
        try fireLastWait()

        XCTAssertEqual(remote.uploads.count, 1)
        XCTAssertFalse(coordinator.isActive)
    }

    func testOversizedCaptureIsNotSent() throws {
        encoder.failure = .tooLarge
        coordinator.start(link: makeLink())
        try save()

        XCTAssertTrue(remote.uploads.isEmpty)
        XCTAssertEqual(dialogs.alerts, [.failure(.tooLarge)])
        dialogs.tap(.discard)
        XCTAssertTrue(coordinator.isActive)
    }

    func testUnencodableCaptureShowsPreparationFailed() throws {
        encoder.failure = .documentEncodingFailed
        coordinator.start(link: makeLink())
        try save()

        XCTAssertTrue(remote.uploads.isEmpty)
        XCTAssertEqual(dialogs.alerts, [.preparationFailed])
    }

    // MARK: - Lifecycle

    func testSavedEndsCaptureModeAtOnceAndSpendsTheQRCode() throws {
        let link = makeLink("cap-saved")
        coordinator.start(link: link)
        try save()
        try finish(0, .success(()))

        XCTAssertFalse(coordinator.isActive, "Capture mode ends on the result, before OK")
        XCTAssertFalse(BuilderCaptureMode.isActive)
        XCTAssertTrue(BuilderCaptureMode.endedCaptureIDs.contains("cap-saved"))
        XCTAssertEqual(dialogs.alerts, [.saved])
        coordinator.start(link: link)
        XCTAssertFalse(coordinator.isActive)
        XCTAssertEqual(dialogs.alerts.last, .linkAlreadyUsed)
    }

    func testUnauthorizedEndsCaptureModeAtOnce() throws {
        coordinator.start(link: makeLink("cap-401"))
        try save()
        try finish(0, .failure(.invalidToken))

        XCTAssertEqual(dialogs.alerts, [.failure(.invalidToken)])
        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(BuilderCaptureMode.isActive)
        XCTAssertTrue(BuilderCaptureMode.endedCaptureIDs.contains("cap-401"))
    }

    func testRejectedCaptureKeepsCaptureMode() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.rejected(statusCode: 422)))

        dialogs.tap(.discard)

        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(BuilderCaptureMode.isActive)
        try save()
        XCTAssertEqual(remote.uploads.count, 2)
    }

    func testLogoutDuringAnUploadEndsCaptureMode() throws {
        coordinator.start(link: makeLink("cap-logout"))
        try save()

        owner.logout()
        try finish(0, .success(()))

        XCTAssertTrue(remote.uploads[0].isCancelled)
        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(BuilderCaptureMode.isActive)
        XCTAssertTrue(BuilderCaptureMode.endedCaptureIDs.contains("cap-logout"))
        XCTAssertTrue(dialogs.alerts.isEmpty)
    }

    func testOneBackgroundTaskSpansTheWholeRun() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.transient(statusCode: 503)))
        try fireLastWait()
        try finish(1, .failure(.transient(statusCode: 503)))
        let task = try XCTUnwrap(backgroundTasks.first)
        XCTAssertTrue(task.isRunning, "The wait between attempts keeps the background time")
        try fireLastWait()
        try finish(2, .success(()))

        XCTAssertEqual(backgroundTasks.count, 1)
        XCTAssertEqual(task.begins, 1)
        XCTAssertFalse(task.isRunning)
    }

    func testBackgroundExpiryEndsTheRunAsTransient() throws {
        coordinator.start(link: makeLink())
        try save()
        try finish(0, .failure(.transient(statusCode: 503)))

        try XCTUnwrap(backgroundTasks.first).expire()
        try fireLastWait()

        XCTAssertEqual(remote.uploads.count, 1)
        XCTAssertEqual(dialogs.alerts, [.failure(.transient(statusCode: nil))])
        XCTAssertTrue(coordinator.isActive)
    }
}

private extension CaptureUploadError {
    var asFailure: Result<Void, CaptureUploadError> { .failure(self) }
}
