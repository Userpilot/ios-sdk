//
//  ExperiencesPublisherHostTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies preview host recovery through native lifecycle delivery and operation cancellation.
//

import UIKit
import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {
    /// TIP-007: resign the app input before handing the tooltip to its separate presentation host.
    func testTooltipEndsEditingInAdmittedWindowBeforePresentation() throws {
        let previousKeyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
        let targetWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let targetController = UIViewController()
        targetWindow.rootViewController = targetController
        let input = UITextField(frame: CGRect(x: 20, y: 80, width: 200, height: 44))
        targetController.view.addSubview(input)
        targetWindow.makeKeyAndVisible()
        defer {
            targetWindow.endEditing(true)
            targetWindow.isHidden = true
            previousKeyWindow?.makeKey()
        }
        XCTAssertTrue(input.becomeFirstResponder())
        XCTAssertTrue(input.isFirstResponder)
        userpilot.container.register(
            ElementTargeting.self, value: MockTooltipTargeting(owner: userpilot, window: targetWindow))
        receiveScreen(MockContentFactory.makeTooltipFlowPayload(stepCount: 1))
        XCTAssertTrue(input.isFirstResponder, "Scheduling must leave editing alone until presentation")

        let shown = expectation(description: "tooltip presented after editing ended")
        host.onPresent = {
            XCTAssertFalse(input.isFirstResponder)
            shown.fulfill()
        }
        try displayDelay.fire()
        wait(for: [shown], timeout: 2)
        host.onPresent = nil
        XCTAssertTrue(host.presentedExperience is TooltipViewController)
    }

    func testPreviewWithoutHostWaitsAndPresentsOnceAfterLifecycleRecovery() throws {
        try waitForPreviewHost()
        XCTAssertFalse(publisher.canRequestScreenEvent())
        XCTAssertNil(publisher.activeRendererID)
        XCTAssertNil(host.presentedExperience)
        XCTAssertFalse(displayDelay.hasAction)

        publisher.topViewControllerProvider = { [weak self] in self?.host }
        postHostLifecycle()
        XCTAssertEqual(displayDelay.scheduleCount, 2)
        try presentScheduled()
        XCTAssertTrue(host.presentedExperience is CarouselExperienceViewController)
        XCTAssertEqual(publisher.activeExperience?.experienceId(), 77)
        postHostLifecycle()
        XCTAssertEqual(displayDelay.scheduleCount, 2)
        XCTAssertFalse(displayDelay.hasAction)
    }

    func testEveryHostLifecycleSignalCanResumeWaitingPreview() throws {
        for notification in [UIApplication.didBecomeActiveNotification,
                             UIScene.didActivateNotification, UIWindow.didBecomeKeyNotification] {
            try waitForPreviewHost()
            publisher.topViewControllerProvider = { [weak self] in self?.host }
            lifecycleCenter.post(name: notification, object: nil)
            settleHostRecovery()
            try presentScheduled()
            publisher.experienceDidFinishDismissing(rendererID: publisher.activeRendererID)
            settle()
        }
    }

    func testLifecycleWithoutHostKeepsPreviewPendingWithoutPolling() throws {
        try waitForPreviewHost()
        postHostLifecycle()
        postHostLifecycle()
        XCTAssertFalse(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(displayDelay.scheduleCount, 1)
        XCTAssertNil(host.presentedExperience)
    }

    func testHostReadyDuringFailedPresentationHandoffIsNotMissed() throws {
        let preview = try makePreview()
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in completion(.success(preview)) }
        publisher.topViewControllerProvider = { [weak self] in
            // Deliver readiness before the missing-host result has reached the operation queue.
            self?.publisher.topViewControllerProvider = { [weak self] in self?.host }
            self?.lifecycleCenter.post(name: UIWindow.didBecomeKeyNotification, object: nil)
            return nil
        }
        publisher.triggerPreviewExperience("preview-a", [])
        settle()
        try displayDelay.fire()
        settleHostRecovery()
        XCTAssertTrue(displayDelay.hasAction)
        try presentScheduled()
    }

    func testLogoutCancelsPreviewWaitingForHost() throws {
        try waitForPreviewHost()
        publisher.logout()
        settle()
        publisher.topViewControllerProvider = { [weak self] in self?.host }
        postHostLifecycle()
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertNil(host.presentedExperience)
        XCTAssertEqual(reloadCount, 0)
    }

    func testManualCloseCancelsPreviewWaitingForHost() throws {
        try waitForPreviewHost()
        let closed = expectation(description: "waiting preview released")
        publisher.endExperience(manualClose: true) { closed.fulfill() }
        wait(for: [closed], timeout: 2)
        publisher.topViewControllerProvider = { [weak self] in self?.host }
        postHostLifecycle()
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 0)
    }

    func testLogoutBeforeHostProbeDoesNotRecreatePresentationUI() throws {
        try waitForPreviewHost()
        var probes = 0
        publisher.topViewControllerProvider = { [weak self] in
            probes += 1
            return self?.host
        }
        lifecycleCenter.post(name: UIScene.didActivateNotification, object: nil)
        publisher.mockWaitForQueue() // Queue has submitted the host lookup; main has not executed it.
        publisher.logout()
        settleHostRecovery()
        XCTAssertEqual(probes, 0)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
    }

    func testNewPreviewReplacesPreviewWaitingForHost() throws {
        try waitForPreviewHost()
        var completion: ((Result<PreviewExperience, RemoteSourceError>) -> Void)?
        userpilot.remoteSource.onFetchPreviewExperience = { _, callback in completion = callback }
        publisher.triggerPreviewExperience("preview-b", [])
        publisher.mockWaitForQueue()
        publisher.topViewControllerProvider = { [weak self] in self?.host }
        postHostLifecycle()
        XCTAssertFalse(displayDelay.hasAction, "The old preview must not resume during the new fetch")
        try XCTUnwrap(completion)(.success(try makePreview()))
        publisher.mockWaitForQueue()
        try presentScheduled()
        XCTAssertEqual(displayDelay.scheduleCount, 2)
    }

    func testNavigationAndSocketCloseKeepWaitingPreviewButNormalRequestsAreDropped() throws {
        try waitForPreviewHost()
        publisher.updateScreen("Next")
        publisher.onSocketClosed()
        publisher.triggerExperience("ignored")
        receiveScreen(MockContentFactory.makeFlowContentPayload(), screen: "Next")
        XCTAssertTrue(userpilot.analyticsPublisher.requests.isEmpty)
        publisher.topViewControllerProvider = { [weak self] in self?.host }
        postHostLifecycle()
        try presentScheduled()
        XCTAssertEqual(publisher.getCurrentScreen, "Next")
    }

    private func waitForPreviewHost() throws {
        let preview = try makePreview()
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in completion(.success(preview)) }
        publisher.topViewControllerProvider = { nil }
        publisher.triggerPreviewExperience("preview-a", [])
        settle()
        try displayDelay.fire()
        settleHostRecovery()
    }

    private func postHostLifecycle() {
        lifecycleCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        lifecycleCenter.post(name: UIScene.didActivateNotification, object: nil)
        lifecycleCenter.post(name: UIWindow.didBecomeKeyNotification, object: nil)
        settleHostRecovery()
    }

    /// Readiness crosses queue -> main -> queue after the failed presentation has been recorded.
    private func settleHostRecovery() {
        settle()
        settle()
        settle()
    }
}
