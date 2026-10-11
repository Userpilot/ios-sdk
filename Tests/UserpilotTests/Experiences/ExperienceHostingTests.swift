//
//  ExperienceHostingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Mounts real SwiftUI content in native windows and verifies containment and dismissal.
//

import SwiftUI
import UIKit
import XCTest

@testable import Userpilot

final class ExperienceHostingTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "HOST-\(UUID().uuidString)").defaultInstance(false))
        userpilot.themeHandler.onMergeExperienceThemes = { _, theme, _ in
            ThemeData(carousel: theme ?? ExperienceTheme(), slideOut: theme ?? ExperienceTheme(), survey: nil)
        }
        userpilot.themeHandler.onMergeSurveyThemes = { _, theme in theme ?? MockContentFactory.makeSurveyTheme() }
        userpilot.imageLoader.onLoadImage = { target, _, _, size in
            target.image = UIGraphicsImageRenderer(size: size).image { context in
                UIColor.systemIndigo.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        }
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

    func testEveryExperienceFamilyMountsRealSwiftUIAndProducesScreenshot() throws {
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload().toJSONString()?.toFlowContent()?.flowContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        try capture(
            ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container))),
            style: .fullScreen, name: "carousel")
        let slideout = FlowContent(
            id: flow.id, type: .slideout, steps: flow.steps, mobileTheme: flow.mobileTheme,
            screens: flow.screens, screenType: flow.screenType, localeCode: "en")
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: slideout) }
        try capture(
            ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container))),
            style: .bottomSheet, name: "slideout")
        try capture(
            ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container))),
            style: .dialog, name: "dialog")
        let survey = try surveyFixture(type: .step)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        try capture(
            ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container))),
            style: .bottomSheet, name: "survey-step")
        let baseTheme = MockContentFactory.makeSurveyTheme()
        userpilot.themeHandler.onMergeSurveyThemes = { _, _ in
            SurveyTheme(general: baseTheme.general, font: baseTheme.font,
                        progress: ProgressStyle(color: "#007AFF", colorType: .manual, enabled: true, type: .bar),
                        backdrop: baseTheme.backdrop)
        }
        try capture(
            ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container))),
            style: .bottomSheet, name: "survey-continuous-top-bar")
        userpilot.themeHandler.onMergeSurveyThemes = { _, theme in theme ?? MockContentFactory.makeSurveyTheme() }
        let list = try surveyFixture(type: .list)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: list) }
        try capture(
            ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container))),
            style: .fullScreen, name: "survey-list")
        try capture(
            ExperienceRenderState(.thankYou(list, MockContentFactory.makeSurveyTheme())),
            style: .bottomSheet, name: "thank-you")
        let nps = try XCTUnwrap(MockContentFactory.makeNPSContentPayload().toJSONString()?.toNPSContent()?.npsContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .nps(content: nps) }
        let npsState = ExperienceRenderState(.nps(NPSViewModel(container: userpilot.container)))
        try capture(npsState, style: .bottomSheet, name: "nps-score")
        npsState.selectNPSScore(8)
        try capture(npsState, style: .bottomSheet, name: "nps-follow-up")
        npsState.submitNPS()
        try capture(npsState, style: .bottomSheet, name: "nps-complete")
    }

    func testNativeDismissalDetachesBeforeReportingAndCompletesRepeatedRequests() throws {
        try XCTSkipIf(
            UIApplication.shared.connectedScenes.isEmpty,
            "Native presentation needs an app-hosted test with a UIWindowScene; SPM tests are hostless.")
        let survey = MockContentFactory.makeSurveyContent()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let state = ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container)))
        let renderer = UPExperienceHostingController(state: state, style: .bottomSheet)
        let parent = UIViewController()
        window.rootViewController = parent
        window.makeKeyAndVisible()
        parent.view.layoutIfNeeded()
        let presented = expectation(description: "presented")
        parent.present(renderer, animated: false) { presented.fulfill() }
        wait(for: [presented], timeout: 3)
        let finished = expectation(description: "publisher completion")
        let requestOne = expectation(description: "first close request")
        let requestTwo = expectation(description: "second close request")
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = {
            XCTAssertNil(renderer.presentingViewController)
            finished.fulfill()
        }
        renderer.triggerCloseExperience(manualClose: true) { requestOne.fulfill() }
        renderer.triggerCloseExperience(manualClose: true) { requestTwo.fulfill() }
        wait(for: [finished, requestOne, requestTwo], timeout: 3)
        XCTAssertNil(parent.presentedViewController)
    }

    func testCarouselSelectionUpdatesWholePageAndLongContentHasVerticalScroll() throws {
        let payload = try XCTUnwrap(MockContentFactory.makeFlowContentPayload().toJSONString())
        let longText = String(
            repeating: "A long onboarding page keeps its action accessible while content scrolls. ", count: 35)
        let original = try XCTUnwrap(payload.replacingOccurrences(
            of: "We're hosting a webinar February 5th. Click the button to book your spot.Registration is fee!",
            with: longText).toFlowContent()?.flowContent)
        let flow = FlowContent(
            id: original.id, type: .carousel, steps: original.steps + original.steps,
            mobileTheme: original.mobileTheme, screens: [], screenType: .all, localeCode: "en")
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let model = ExperienceViewModel(container: userpilot.container)
        let state = ExperienceRenderState(.flow(model))
        let renderer = UPExperienceHostingController(state: state, style: .fullScreen)
        window.rootViewController = renderer
        renderer.view.layoutIfNeeded()
        let pager = try XCTUnwrap(renderer.carouselController)
        let first = try XCTUnwrap(pager.viewControllers?.first)
        let second = try XCTUnwrap(pager.dataSource?.pageViewController(pager, viewControllerAfter: first))
        XCTAssertEqual(pager.view.bounds.width, renderer.view.bounds.width)
        XCTAssertGreaterThan(pager.view.bounds.height, renderer.view.bounds.height - 120)
        let scrollable = expectation(for: NSPredicate { _, _ in
            self.allViews(in: first.view).compactMap { $0 as? UIScrollView }.contains {
                $0.contentSize.height > $0.bounds.height + 100
            }
        }, evaluatedWith: nil)
        wait(for: [scrollable], timeout: 3)
        pager.delegate?.pageViewController?(pager, willTransitionTo: [second])
        pager.setViewControllers([second], direction: .forward, animated: false)
        pager.delegate?.pageViewController?(pager, didFinishAnimating: true,
                                            previousViewControllers: [first], transitionCompleted: true)
        XCTAssertEqual(model.currentStep, 1)
        XCTAssertEqual(pager.viewControllers?.first?.view.accessibilityIdentifier, "userpilot-carousel-page-1")
        try capture(state, style: .fullScreen, name: "carousel-second-page-dots")
    }

    func testRealImageLoaderKeepsPixelsWhenInitialDisplayProposalIsTiny() throws {
        let size = CGSize(width: 240, height: 120)
        let pixels = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 120, y: 0, width: 120, height: 120))
        }
        let url = try XCTUnwrap(URL(string: "https://image-fixture.invalid/\(UUID().uuidString).png"))
        URLProtocolStub.response = (try XCTUnwrap(pixels.pngData()), URLResponse(
            url: url, mimeType: "image/png", expectedContentLength: -1, textEncodingName: nil), nil)
        URLProtocol.registerClass(URLProtocolStub.self)
        defer {
            URLProtocol.unregisterClass(URLProtocolStub.self)
            URLProtocolStub.reset()
        }
        let loader = ImageLoader(container: userpilot.container)
        let host = UIHostingController(rootView: UPExperienceImage(
            url: url.absoluteString, loader: loader, size: CGSize(width: 1, height: 0.5), loadingSize: size))
        window.rootViewController = host
        host.view.layoutIfNeeded()
        let loaded = expectation(for: NSPredicate { _, _ in
            self.allViews(in: host.view).compactMap { $0 as? UIImageView }.contains { $0.image != nil }
        }, evaluatedWith: nil)
        wait(for: [loaded], timeout: 5)
        host.rootView = UPExperienceImage(url: url.absoluteString, loader: loader, size: size, loadingSize: size)
        host.view.layoutIfNeeded()
        let imageView = try XCTUnwrap(allViews(in: host.view).compactMap { $0 as? UIImageView }.first)
        XCTAssertEqual(imageView.image?.size.width, 240)
        XCTAssertEqual(imageView.image?.size.height, 120)
        XCTAssertEqual(imageView.bounds.width, 240, accuracy: 1)
        XCTAssertEqual(imageView.bounds.height, 120, accuracy: 1)
        attachWindow(name: "loaded-network-image-authored-aspect")
    }

    func testSheetEntranceMovesUpAndExitMovesDownWithoutLayoutJump() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "Animation requires an app-hosted UIWindowScene.")
        let survey = MockContentFactory.makeSurveyContent()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let renderer = UPExperienceHostingController(
            state: ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container))), style: .bottomSheet)
        renderer.modalPresentationStyle = .overFullScreen
        renderer.loadViewIfNeeded()
        let card = try XCTUnwrap(renderer.view.subviews.last)
        XCTAssertEqual(card.alpha, 0, "Card must stay hidden before its settled entrance pose.")
        let parent = UIViewController()
        parent.view.backgroundColor = .systemBlue
        window.rootViewController = parent
        let recorder = CardAnimationRecorder(card: card)
        recorder.start()
        parent.present(renderer, animated: false)
        let entered = expectation(for: NSPredicate { _, _ in
            card.layer.animationKeys()?.isEmpty != false && card.alpha == 1 && card.transform == .identity
        }, evaluatedWith: nil)
        wait(for: [entered], timeout: 3)
        recorder.stop()
        let entrance = recorder.positions
        XCTAssertGreaterThan(entrance.count, 2)
        for (previous, next) in zip(entrance, entrance.dropFirst()) {
            XCTAssertLessThanOrEqual(next, previous + 1, "Entrance reversed instead of settling upward.")
        }
        let frame = card.convert(card.bounds, to: renderer.view)
        XCTAssertEqual(frame.minX, renderer.view.safeAreaInsets.left + 16, accuracy: 1)
        XCTAssertEqual(renderer.view.bounds.maxX - frame.maxX, renderer.view.safeAreaInsets.right + 16, accuracy: 1)
        attachWindow(name: "sheet-settled-with-side-margins")
        recorder.start()
        let dismissed = expectation(description: "native removal")
        renderer.triggerCloseExperience(manualClose: true) { dismissed.fulfill() }
        wait(for: [dismissed], timeout: 3)
        recorder.stop()
        XCTAssertGreaterThan(recorder.positions.count, 2)
        for (previous, next) in zip(recorder.positions, recorder.positions.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next, previous - 1, "Exit reversed instead of continuing downward.")
        }
        let trace = XCTAttachment(string: "entrance y: \(entrance)\nexit y: \(recorder.positions)")
        trace.name = "sheet-animation-frame-trace"
        trace.lifetime = .keepAlways
        add(trace)
    }

}

extension ExperienceHostingTests {
    func testDialogAnimationStaysCenteredAndDismissalDuringEntranceDoesNotJump() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "Animation requires an app-hosted UIWindowScene.")
        let survey = MockContentFactory.makeSurveyContent()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let renderer = UPExperienceHostingController(
            state: ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container))), style: .dialog)
        renderer.modalPresentationStyle = .overFullScreen
        renderer.loadViewIfNeeded()
        let card = try XCTUnwrap(renderer.view.subviews.last)
        XCTAssertEqual(card.alpha, 0)
        window.rootViewController = UIViewController()
        let recorder = CardAnimationRecorder(card: card)
        recorder.start()
        window.rootViewController?.present(renderer, animated: false)
        let entering = expectation(description: "three entrance frames")
        recorder.didSample = { [weak recorder] in
            if recorder?.centers.count == 3 { entering.fulfill() }
        }
        wait(for: [entering], timeout: 3)
        let dismissed = expectation(description: "removed during entrance")
        renderer.triggerCloseExperience(manualClose: true) { dismissed.fulfill() }
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        wait(for: [dismissed], timeout: 3)
        recorder.stop()
        let center = try XCTUnwrap(recorder.centers.first)
        XCTAssertGreaterThan(recorder.centers.count, 4)
        for sample in recorder.centers {
            XCTAssertEqual(sample.x, center.x, accuracy: 1)
            XCTAssertEqual(sample.y, center.y, accuracy: 1)
        }
        let trace = XCTAttachment(string: "dialog center positions: \(recorder.centers)")
        trace.name = "dialog-interrupted-animation-frame-trace"
        trace.lifetime = .keepAlways
        add(trace)
    }
}

private extension ExperienceHostingTests {
    func allViews(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { allViews(in: $0) }
    }

    private func attachWindow(name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
            if window.windowScene != nil {
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            } else {
                window.layer.render(in: context.cgContext)
            }
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func capture(
        _ state: ExperienceRenderState, style: UPExperienceHostingController.Style,
        name: String
    ) throws {
        let controller = UPExperienceHostingController(state: state, style: style)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let laidOut = expectation(
            for: NSPredicate { _, _ in
                (controller.carouselController != nil || controller.children.count == 3)
                    && controller.children.allSatisfy {
                        $0.view.bounds.height > 1 && $0.view.bounds.width > 100
                    }
            }, evaluatedWith: nil)
        wait(for: [laidOut], timeout: 3)
        controller.view.layoutIfNeeded()
        let hosting = try XCTUnwrap(controller.contentController ?? controller.carouselController as UIViewController?)
        XCTAssertTrue(hosting.parent === controller)
        XCTAssertEqual(controller.children.count, controller.carouselController == nil ? 3 : 1)
        XCTAssertGreaterThan(hosting.view.bounds.width, 100)
        XCTAssertGreaterThan(hosting.view.bounds.height, 1)
        if style == .fullScreen {
            // Fullscreen safe-area strips belong to the experience surface, never its modal backdrop.
            XCTAssertEqual(controller.view.backgroundColor, state.backgroundColor)
            if controller.carouselController == nil {
                XCTAssertEqual(controller.view.subviews.first?.backgroundColor, UIColor.clear)
            }
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
            if window.windowScene != nil {
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            } else {
                window.layer.render(in: context.cgContext)
            }
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "swiftui-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func surveyFixture(type: SurveyType) throws -> SurveyContent {
        let modules: [[String: Any]] = [
            [
                "id": 1, "type": "likert_scale", "question": "How was your experience?", "is_required": true,
                "metadata": ["type": "stars", "range": 5, "low_score": "Poor", "high_score": "Excellent"]
            ],
            [
                "id": 2, "type": "multiple_choice", "question": "What matters most?", "is_required": false,
                "metadata": [
                    "choices": [["id": "speed", "value": "Speed"], ["id": "quality", "value": "Quality"]],
                    "is_multi_select": true, "other_choice": ["enabled": true, "placeholder": "Tell us"]
                ]
            ],
            ["id": 3, "type": "open_text", "question": "Anything else?", "metadata": ["placeholder": "Your feedback"]],
            ["id": 4, "type": "single_input", "question": "Your email", "metadata": ["input_type": "email"]],
            [
                "id": 5, "type": "completed", "question": "Thank you!", "subheader": "Your feedback helps us improve.",
                "button_label": "Done", "metadata": ["enabled": true]
            ]
        ]
        let decoded = try JSONDecoder().decode(
            [SurveyStep].self,
            from: JSONSerialization.data(withJSONObject: modules))
        return SurveyContent(
            id: 200, type: type, modules: decoded,
            metadata: SurveyContentMetaData(buttonLabel: "Send feedback"),
            surveyTheme: MockContentFactory.makeSurveyMobileTheme(), screens: [],
            screenType: .all, localeCode: "en", timeDelay: 0)
    }
}
