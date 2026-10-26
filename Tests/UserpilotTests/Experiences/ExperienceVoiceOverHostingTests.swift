//
//  ExperienceVoiceOverHostingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 26/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The VoiceOver escape gesture and Reduce Motion. Traits are checked in RendererGestureTests,
//  because SwiftUI builds its accessibility tree only when an assistive client (XCUITest) asks.
//

import SwiftUI
import UIKit
import XCTest

@testable import Userpilot

final class ExperienceVoiceOverHostingTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "VO-\(UUID().uuidString)").defaultInstance(false))
        userpilot.themeHandler.onMergeExperienceThemes = { _, theme, _ in
            ThemeData(carousel: theme ?? ExperienceTheme(), slideOut: theme ?? ExperienceTheme(), survey: nil)
        }
        userpilot.themeHandler.onMergeSurveyThemes = { _, theme in theme ?? MockContentFactory.makeSurveyTheme() }
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
        window = nil
        userpilot = nil
        super.tearDown()
    }

    func testReduceMotionShowsTheFirstFrameAndAnimatedImagesIgnoreInvert() throws {
        let frames = (0..<3).map { index in
            UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { context in
                UIColor(hue: CGFloat(index) / 3, saturation: 1, brightness: 1, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
            }
        }
        let loader = MockImageLoader()
        loader.cachedImages["gif"] = try XCTUnwrap(UIImage.animatedImage(with: frames, duration: 0.3))
        let model = UPImageModel(url: "gif", blurHash: nil, size: CGSize(width: 200, height: 100), loader: loader)
        // The view follows SwiftUI's Reduce Motion environment value, as the system sets it.
        let host = UIHostingController(rootView: UPExperienceImage(model: model, size: CGSize(width: 200, height: 100))
            .environment(\._accessibilityReduceMotion, true))
        window.rootViewController = host
        host.view.layoutIfNeeded()
        let imageView = try XCTUnwrap(allViews(in: host.view).compactMap { $0 as? UIImageView }.first)
        XCTAssertTrue(imageView.image === frames[0], "Reduce Motion shows a still first frame.")
        XCTAssertNil(imageView.image?.images)
        XCTAssertTrue(imageView.accessibilityIgnoresInvertColors)
    }
}

// MARK: - Escape gesture

extension ExperienceVoiceOverHostingTests {
    func testEscapeReportsTheSameDismissalAsTheCloseControl() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "Native dismissal needs an app-hosted scene.")
        for family in try families() {
            let viaClose = try record(family) { $0.state.userClose() }
            let viaEscape = try record(family) { XCTAssertTrue($0.accessibilityPerformEscape(), family.name) }
            XCTAssertFalse(viaClose.isEmpty, "\(family.name): closing reports a dismissal")
            XCTAssertEqual(viaEscape, viaClose, family.name)
        }
    }

    /// A date or country picker sheet is presented by the renderer. Escape must leave it to the sheet,
    /// and closing must remove the whole experience, not only the sheet (which left a frozen card).
    func testEscapeAndCloseWithAPickerOpenRemoveTheWholeExperience() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "Native dismissal needs an app-hosted scene.")
        let survey = try MockContentFactory.makeQuestionSurvey(type: .step)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let renderer = UPExperienceHostingController(
            state: ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container))), style: .bottomSheet)
        renderer.modalPresentationStyle = .overFullScreen
        let parent = UIViewController()
        window.rootViewController = parent
        let presented = expectation(description: "renderer presented")
        parent.present(renderer, animated: false) { presented.fulfill() }
        wait(for: [presented], timeout: 3)
        let pickerShown = expectation(description: "picker presented")
        renderer.present(UIViewController(), animated: false) { pickerShown.fulfill() }
        wait(for: [pickerShown], timeout: 3)

        XCTAssertFalse(renderer.accessibilityPerformEscape(), "The open picker handles escape first")
        XCTAssertFalse(renderer.state.isClosing)

        let closed = expectation(description: "closed")
        renderer.triggerCloseExperience(manualClose: true) { closed.fulfill() }
        wait(for: [closed], timeout: 3)
        XCTAssertNil(renderer.presentingViewController, "The card itself is removed")
        XCTAssertNil(parent.presentedViewController)
    }

    func testEscapeDoesNothingWithoutACloseControl() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "Native dismissal needs an app-hosted scene.")
        let noClose = try JSONDecoder().decode(ExperienceTheme.self, from: JSONSerialization.data(
            withJSONObject: ["dismiss_content": ["enabled": false]]))
        userpilot.themeHandler.onMergeExperienceThemes = { _, _, _ in
            ThemeData(carousel: noClose, slideOut: noClose, survey: nil)
        }
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload().toJSONString()?.toFlowContent()?.flowContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let container = userpilot.container
        let family = Family(name: "carousel without close", style: .fullScreen) {
            ExperienceRenderState(.flow(ExperienceViewModel(container: container)))
        }
        var renderer: UPExperienceHostingController?
        let events = try record(family, expectDismissal: false) {
            renderer = $0
            XCTAssertFalse($0.accessibilityPerformEscape())
        }
        XCTAssertEqual(events, [])
        XCTAssertNotNil(renderer?.presentingViewController, "Still on screen.")
    }
}

private extension ExperienceVoiceOverHostingTests {
    struct Family {
        let name: String
        let style: UPExperienceHostingController.Style
        let make: () throws -> ExperienceRenderState
    }

    func families() throws -> [Family] {
        let carousel = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload().toJSONString()?.toFlowContent()?.flowContent)
        let slideout = FlowContent(
            id: carousel.id, type: .slideout, steps: carousel.steps, mobileTheme: carousel.mobileTheme,
            screens: [], screenType: .all, localeCode: "en")
        let survey = try MockContentFactory.makeQuestionSurvey(type: .step)
        let list = try MockContentFactory.makeQuestionSurvey(type: .list)
        let nps = try XCTUnwrap(MockContentFactory.makeNPSContentPayload().toJSONString()?.toNPSContent()?.npsContent)
        let publisher = userpilot.experiencesPublisher
        let container = userpilot.container
        func flowState(_ content: FlowContent) -> ExperienceRenderState {
            publisher.onGetActiveMobileContent = { .flow(content: content) }
            return ExperienceRenderState(.flow(ExperienceViewModel(container: container)))
        }
        return [
            Family(name: "carousel", style: .fullScreen) { flowState(carousel) },
            Family(name: "slideout", style: .bottomSheet) { flowState(slideout) },
            Family(name: "survey", style: .bottomSheet) {
                publisher.onGetActiveMobileContent = { .survey(content: survey) }
                return ExperienceRenderState(.survey(SurveyViewModel(container: container)))
            },
            Family(name: "nps score", style: .bottomSheet) {
                publisher.onGetActiveMobileContent = { .nps(content: nps) }
                return ExperienceRenderState(.nps(NPSViewModel(container: container)))
            },
            Family(name: "nps follow-up", style: .bottomSheet) {
                publisher.onGetActiveMobileContent = { .nps(content: nps) }
                let state = ExperienceRenderState(.nps(NPSViewModel(container: container)))
                state.selectNPSScore(8)
                return state
            },
            Family(name: "thank-you", style: .bottomSheet) {
                ExperienceRenderState(.thankYou(list, MockContentFactory.makeSurveyTheme()))
            }
        ]
    }

    /// Presents the family, then records only what the action reports: SDK events, delegate states and
    /// the thank-you action callback.
    func record(
        _ family: Family, expectDismissal: Bool = true,
        _ action: (UPExperienceHostingController) -> Void
    ) throws -> [String] {
        var events: [String] = []
        let delegate = ExperienceStateRecorder { events.append($0) }
        userpilot.experienceDelegate = delegate
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append("event:\(type(of: $0))") }
        let state = try family.make()
        state.actionButtonClicked = { events.append("thank-you action:\($0 ?? "none")") }
        let renderer = UPExperienceHostingController(state: state, style: family.style)
        renderer.modalPresentationStyle = family.style == .fullScreen ? .fullScreen : .overFullScreen
        let parent = UIViewController()
        window.rootViewController = parent
        let presented = expectation(description: "\(family.name) presented")
        parent.present(renderer, animated: false) { presented.fulfill() }
        wait(for: [presented], timeout: 3)
        let appeared = expectation(for: NSPredicate { _, _ in state.hasAppeared }, evaluatedWith: nil)
        wait(for: [appeared], timeout: 3)
        events.removeAll()
        action(renderer)
        if expectDismissal {
            let removed = expectation(for: NSPredicate { _, _ in renderer.presentingViewController == nil },
                                      evaluatedWith: nil)
            wait(for: [removed], timeout: 3)
        }
        let settled = expectation(description: "callbacks settle")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        withExtendedLifetime(delegate) {}
        return events
    }

    func allViews(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { allViews(in: $0) }
    }
}

private final class ExperienceStateRecorder: NSObject, UserpilotExperienceDelegate {
    let record: (String) -> Void
    init(_ record: @escaping (String) -> Void) { self.record = record }

    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType, experienceId: NSNumber?, experienceState: UserpilotExperienceState
    ) {
        record("experience:\(experienceState.rawValue)")
    }

    // swiftlint:disable:next function_parameter_count
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType, experienceId: NSNumber, stepId: NSNumber,
        stepState: UserpilotExperienceState, step: NSNumber?, totalSteps: NSNumber?
    ) {
        record("step:\(stepState.rawValue)")
    }
}
