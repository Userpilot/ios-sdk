//
//  ExperiencesPublisherSilentCloseTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Every SDK-driven close (navigation, logout, a QR preview, Builder capture mode) takes one silent path
//  for every content type: the natively presented renderer receives the close and reports nothing,
//  neither `dismissed_mobile_content` nor a host delegate callback, and no fake reload follows. The close
//  waits `screenTransitionCloseDelay` first, as Android's `dismissOnMain` does.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {

    // MARK: - One silent path, cause × content

    func testNavigation_closesEveryContentTypeSilently() throws {
        try assertEveryContentTypeClosesSilently { $0.publisher.updateScreen("Next") }
    }

    func testLogout_closesEveryContentTypeSilently() throws {
        try assertEveryContentTypeClosesSilently { $0.publisher.logout() }
    }

    func testAQRPreview_closesEveryContentTypeSilently() throws {
        try assertEveryContentTypeClosesSilently { test in
            test.userpilot.remoteSource.onFetchPreviewExperience = { _, _ in }
            test.publisher.triggerPreviewExperience("preview-a", [])
        }
    }

    func testBuilderCapture_closesEveryContentTypeSilently() throws {
        try assertEveryContentTypeClosesSilently { $0.publisher.closeSilently(completion: nil) }
    }

    // MARK: - The screen-transition delay

    func testAnSDKDrivenClose_waitsForTheScreenTransition_thenCloses() throws {
        XCTAssertEqual(ExperiencesPublisher.screenTransitionCloseDelay, 0.5)
        publisher.mockSetDelayUtils(displayDelay, sdkCloseDelay: 0.2)
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        let closeStarted = Date()

        publisher.updateScreen("Next")
        settle()
        XCTAssertNotNil(publisher.activeRendererID, "the renderer stays until the delay passes")

        waitUntilIdle()
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(closeStarted), 0.2)
        XCTAssertNil(publisher.activeRendererID)
        XCTAssertEqual(reloadCount, 0)
    }

    func testLogoutDuringTheDelay_stillClosesTheExperience() throws {
        publisher.mockSetDelayUtils(displayDelay, sdkCloseDelay: 0.2)
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()

        publisher.updateScreen("Next")
        publisher.logout()
        settle()
        XCTAssertFalse(publisher.canRequestScreenEvent(), "the renderer stays until the delay passes")

        waitUntilIdle()
        XCTAssertEqual(reloadCount, 0)
    }

    func testTheHostsEndExperience_closesWithoutTheDelay() throws {
        publisher.mockSetDelayUtils(displayDelay, sdkCloseDelay: 10)
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()

        publisher.endExperience(manualClose: true)
        settle()

        XCTAssertNil(publisher.activeRendererID)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    // MARK: - Helpers

    /// Presents each content type natively on a fresh publisher, closes it with `close`, and checks that
    /// the renderer received the close yet reported nothing.
    private func assertEveryContentTypeClosesSilently(
        by close: (ExperiencesPublisherTests) -> Void, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        for content in SilentlyClosedContent.allCases {
            let delegate = FlowStepDelegate()
            let renderer = try ObjectIdentifier(presentNatively(content, reportingTo: delegate))
            XCTAssertNotNil(publisher.activeRendererID, "\(content) closed before the SDK closed it",
                            file: file, line: line)

            DismissalLog.recording {
                close(self)
                let reached = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    DismissalLog.receivers.contains(renderer)
                }, object: nil)
                XCTAssertEqual(XCTWaiter().wait(for: [reached], timeout: 3), .completed,
                               "\(content) never received the close", file: file, line: line)
                settle()
            }

            let message = "\(content) reported its close"
            XCTAssertEqual(publishedEvents.map(\.eventName).filter { !$0.hasPrefix("seen_") }, [], message,
                           file: file, line: line)
            XCTAssertEqual((delegate.flowStates + delegate.states).filter { $0 != .started }, [], message,
                           file: file, line: line)
            XCTAssertEqual(reloadCount, 0, message, file: file, line: line)
            tearDown()
            setUp()
        }
    }

    /// Presents `content` through UIKit and returns its renderer. The renderers' ViewModels reach `delegate`;
    /// the publisher, built before, stays off the facade's overlay. A loaded standalone carousel or slideout
    /// dismisses itself without its theme.
    private func presentNatively(
        _ content: SilentlyClosedContent, reportingTo delegate: FlowStepDelegate
    ) throws -> UIViewController {
        host.presentsNatively = true
        addTeardownBlock { [host] in host?.presentsNatively = false }
        userpilot.container.owner = userpilot
        userpilot.experienceDelegate = delegate
        userpilot.themeHandler.onMergeExperienceThemes = { _, _, _ in
            ThemeData(carousel: ExperienceTheme(), slideOut: ExperienceTheme(), survey: nil)
        }
        switch content {
        case .flowTooltipStep:
            return try presentTooltipSegment(TooltipFixture.flowPayload(types: ["tooltip", "modal"]))
        case .carousel: receiveScreen(MockContentFactory.makeFlowContentPayload())
        case .slideout: receiveScreen(standaloneSlideOutPayload())
        case .nps: receiveScreen(MockContentFactory.makeNPSContentPayload())
        case .survey: receiveScreen(MockContentFactory.makeSurveyContentPayload())
        case .flowModalStep: receiveScreen(TooltipFixture.flowPayload(types: ["modal", "modal"]))
        case .flowSlideOutStep: receiveScreen(TooltipFixture.flowPayload(types: ["slideout", "modal"]))
        }
        try presentScheduled()
        return try XCTUnwrap(host.presentedExperience)
    }

    private func standaloneSlideOutPayload() -> [String: Any] {
        var payload = MockContentFactory.makeFlowContentPayload()
        var content = payload["mobile_contents"] as? [String: Any] ?? [:]
        content["type"] = "slideout"
        payload["mobile_contents"] = content
        return payload
    }

    /// Waits for the delayed close to finish: the publisher can ask for a screen event again.
    private func waitUntilIdle() {
        let idle = expectation(for: NSPredicate { [weak self] _, _ in
            self?.publisher.canRequestScreenEvent() == true
        }, evaluatedWith: nil)
        wait(for: [idle], timeout: 2)
        settle()
    }
}

/// Every renderer an SDK-driven close must close silently: standalone content and each Flow step type.
private enum SilentlyClosedContent: CaseIterable {
    case carousel, slideout, nps, survey, flowModalStep, flowSlideOutStep, flowTooltipStep
}

/// Records the controllers that call `dismiss(animated:completion:)` while `recording` runs. UIKit hands a
/// presented controller's own dismissal to its presenter without calling the presenter's override, and the
/// runner never finishes the transition, so the call itself is the only sign the renderer acted.
private enum DismissalLog {
    static var receivers: Set<ObjectIdentifier> = []

    /// Logs dismiss calls only while `body` runs, then restores UIKit's own dismiss for later tests.
    static func recording(_ body: () -> Void) {
        receivers = []
        exchangeImplementations()
        defer { exchangeImplementations() }
        body()
    }

    private static func exchangeImplementations() {
        guard let original = class_getInstanceMethod(
                UIViewController.self, #selector(UIViewController.dismiss(animated:completion:))),
              let logging = class_getInstanceMethod(
                UIViewController.self, #selector(UIViewController.loggingDismiss(animated:completion:)))
        else { return }
        method_exchangeImplementations(original, logging)
    }
}

private extension UIViewController {
    /// Once exchanged, the inner `loggingDismiss` call runs UIKit's original dismiss, so it does not recurse.
    @objc func loggingDismiss(animated: Bool, completion: (() -> Void)?) {
        DismissalLog.receivers.insert(ObjectIdentifier(self))
        loggingDismiss(animated: animated, completion: completion)
    }
}
