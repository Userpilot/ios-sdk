//
//  BuilderCaptureCoordinatorTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises the QR session (start, refresh, replace, invalid and used links), the capture entry checks
//  and stale callbacks across session/host changes.
//

import XCTest
@testable import Userpilot

final class BuilderCaptureCoordinatorTests: BuilderCaptureCoordinatorTestCase {

    // MARK: - Session

    func testValidLinkStartsCaptureModeAndUploadsWithItsValues() throws {
        let link = makeLink("cap-valid", token: "token-a")

        coordinator.start(link: link)
        try save(named: "  Checkout  ")

        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(BuilderCaptureMode.isActive)
        let document = try XCTUnwrap(encoder.documents.last)
        XCTAssertEqual(document.captureID, "cap-valid")
        XCTAssertEqual(document.displayName, "Checkout")
        XCTAssertEqual(document.screen.title, "Home")
        XCTAssertEqual(document.screen.name, "Home")
        let upload = try XCTUnwrap(remote.uploads.last)
        XCTAssertEqual(upload.url.absoluteString, Environment.getCaptureUploadUrl())
        XCTAssertEqual(upload.token.bearerHeader(), "Bearer token-a")
        XCTAssertEqual(upload.upload.captureID, "cap-valid")
    }

    func testStartClosesTheCurrentExperienceOfEveryInstance() {
        let other = MockUserpilot.make(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false))
        var silentCloses = 0
        var endExperienceCalls = 0
        for publisher in [owner.experiencesPublisher, other.experiencesPublisher] {
            publisher.onCloseSilently = { _ in silentCloses += 1 }
            publisher.onEndExperience = { _ in endExperienceCalls += 1 }
        }

        coordinator.start(link: makeLink())

        XCTAssertEqual(silentCloses, 2, "Each instance closes once, silently like a QR preview")
        XCTAssertEqual(endExperienceCalls, 0, "Capture never ends an experience like the host app")
        withExtendedLifetime(other) {}
    }

    func testSameCaptureIDRefreshesTheTokenForTheNextAttempt() throws {
        coordinator.start(link: makeLink("cap-refresh", token: "token-a"))
        try save()
        try finish(0, .failure(.transient(statusCode: 503)))

        coordinator.start(link: makeLink("cap-refresh", token: "token-b"))
        try fireLastWait()

        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(BuilderCaptureMode.owner === coordinator)
        XCTAssertEqual(remote.uploads.count, 2)
        XCTAssertEqual(remote.uploads[1].url.absoluteString, Environment.getCaptureUploadUrl())
        XCTAssertEqual(remote.uploads[1].token.bearerHeader(), "Bearer token-b")
        XCTAssertEqual(remote.uploads[1].upload.captureID, "cap-refresh")
    }

    func testDifferentCaptureIDReplacesTheSessionAndCancelsTheUploadInFlight() throws {
        coordinator.start(link: makeLink("cap-first"))
        try save()

        coordinator.start(link: makeLink("cap-second"))
        try finish(0, .success(()))

        XCTAssertTrue(remote.uploads[0].isCancelled)
        XCTAssertTrue(dialogs.alerts.isEmpty, "A replaced upload's late result shows nothing")
        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(BuilderCaptureMode.isActive)
        XCTAssertFalse(BuilderCaptureMode.endedCaptureIDs.contains("cap-first"))
        try save()
        XCTAssertEqual(remote.uploads.last?.upload.captureID, "cap-second")
    }

    func testLinkForAnotherInstanceStopsItsSessionFirst() {
        let otherOwner = MockUserpilot.make(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false))
        let otherCoordinator = makeCoordinator(container: makeContainer(for: otherOwner), owner: otherOwner)
        coordinator.start(link: makeLink("cap-this-instance"))

        otherCoordinator.start(link: makeLink("cap-other-instance"))

        XCTAssertTrue(BuilderCaptureMode.owner === otherCoordinator)
        XCTAssertFalse(coordinator.isActive)
        XCTAssertTrue(otherCoordinator.isActive)
        XCTAssertTrue(BuilderCaptureMode.isActive)
        XCTAssertTrue(BuilderCaptureMode.endedCaptureIDs.contains("cap-this-instance"), "Stopped like Close")
        otherCoordinator.stop()
        XCTAssertFalse(BuilderCaptureMode.isActive)
    }

    func testInvalidLinkCancelsOnlyTheReceivingInstancesSession() {
        let otherOwner = MockUserpilot.make(
            config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false))
        let otherCoordinator = makeCoordinator(container: makeContainer(for: otherOwner), owner: otherOwner)
        coordinator.start(link: makeLink())

        otherCoordinator.rejectInvalidLink()

        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(BuilderCaptureMode.owner === coordinator)
        XCTAssertEqual(dialogs.alerts, [.invalidLink])
    }

    func testInvalidLinkCancelsCaptureModeAndShowsInvalidQRCode() {
        let link = makeLink("cap-invalid-after")
        coordinator.start(link: link)

        coordinator.rejectInvalidLink()

        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(BuilderCaptureMode.isActive)
        XCTAssertEqual(dialogs.alerts, [.invalidLink])
        coordinator.start(link: link)
        XCTAssertTrue(coordinator.isActive, "A cancelled session's QR code is not spent")
    }

    func testAndroidLinkCancelsCaptureModeAndNamesTheDeviceToScanItWith() {
        let link = makeLink("cap-android-after")
        coordinator.start(link: link)

        coordinator.rejectOtherPlatformLink()

        XCTAssertFalse(coordinator.isActive)
        XCTAssertEqual(dialogs.alerts, [.otherPlatformLink])
        coordinator.start(link: link)
        XCTAssertTrue(coordinator.isActive, "A cancelled session's QR code is not spent")
    }

    func testInvalidLinkWithoutCaptureModeOnlyShowsInvalidQRCode() {
        coordinator.rejectInvalidLink()

        XCTAssertFalse(coordinator.isActive)
        XCTAssertEqual(dialogs.alerts, [.invalidLink])
    }

    func testUsedCaptureIDShowsAlreadyUsedAndDoesNotStart() {
        let link = makeLink("cap-used")
        coordinator.start(link: link)
        coordinator.stop()

        coordinator.start(link: link)

        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(BuilderCaptureMode.isActive)
        XCTAssertEqual(dialogs.alerts, [.linkAlreadyUsed])
    }

    // MARK: - Capture entry

    func testCaptureWithoutAnIdentifiedUserShowsCannotCaptureYet() {
        owner.storage.userId = ""
        coordinator.start(link: makeLink())

        coordinator.capture()

        XCTAssertEqual(dialogs.alerts, [.cannotCaptureYet])
        XCTAssertTrue(dismissals.isEmpty)
        XCTAssertEqual(snapshotter.calls, 0)
        XCTAssertTrue(coordinator.isActive)
    }

    func testCaptureWithoutAScreenSessionShowsCannotCaptureYet() {
        owner.analyticsPublisher.screenSessionStateMachine = nil
        coordinator.start(link: makeLink())

        coordinator.capture()

        XCTAssertEqual(dialogs.alerts, [.cannotCaptureYet])
        XCTAssertEqual(snapshotter.calls, 0)
    }

    func testIdentifiedUserOnATrackedScreenTakesTheSnapshot() {
        owner.experiencesPublisher.isExperienceVisible = false
        coordinator.start(link: makeLink())

        coordinator.capture()

        XCTAssertEqual(snapshotter.calls, 1)
        XCTAssertFalse(dialogs.alerts.contains(.cannotCaptureYet))
    }

    // MARK: - Stale callbacks

    func testRepeatedTapWaitsForOneActualDismissal() throws {
        coordinator.start(link: makeLink())
        coordinator.capture()
        coordinator.capture()
        XCTAssertEqual(dismissals.count, 1)
        XCTAssertEqual(snapshotter.calls, 0)

        try XCTUnwrap(dismissals.first)()

        XCTAssertEqual(snapshotter.calls, 1)
    }

    func testOldDismissalCannotCaptureIntoReplacementSession() throws {
        coordinator.start(link: makeLink("cap-old"))
        coordinator.capture()
        let oldDismissal = try XCTUnwrap(dismissals.first)
        coordinator.stop()
        coordinator.start(link: makeLink("cap-new"))
        coordinator.capture()
        oldDismissal()
        XCTAssertEqual(snapshotter.calls, 0)
        XCTAssertEqual(dismissals.count, 2)
        dismissals[1]()
        XCTAssertEqual(snapshotter.calls, 1)
    }

    func testInvalidHostReleasesCaptureSlotWithoutReselecting() throws {
        coordinator.start(link: makeLink())
        coordinator.capture()
        targeting.valid = false
        try XCTUnwrap(dismissals.first)()
        XCTAssertEqual(snapshotter.calls, 0)
        targeting.valid = true
        coordinator.capture()
        XCTAssertEqual(dismissals.count, 2)
    }
}
