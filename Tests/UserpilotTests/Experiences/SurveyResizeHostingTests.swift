//
//  SurveyResizeHostingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies native survey container resizing through rendered frames and real step changes.
//

import UIKit
import XCTest

@testable import Userpilot

final class SurveyResizeHostingTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var window: UIWindow!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw XCTSkip("Survey resize presentation requires an app-hosted UIWindowScene.")
        }
        userpilot = MockUserpilot(config: Userpilot.Config(token: "RESIZE-\(UUID().uuidString)").defaultInstance(false))
        userpilot.themeHandler.onMergeSurveyThemes = { _, theme in theme ?? MockContentFactory.makeSurveyTheme() }
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        userpilot = nil
        super.tearDown()
    }

    func testBottomSheetGrowAndShrinkKeepBottomAnchored() throws { try verifyResize(style: .bottomSheet) }
    func testDialogGrowAndShrinkKeepCenterAnchored() throws { try verifyResize(style: .dialog) }

    func testRapidStepsRetargetFromRenderedHeight() throws {
        for style in [UPExperienceHostingController.Style.bottomSheet, .dialog] {
            let (renderer, card) = try present(style: style)
            let initial = card.frame
            let recorder = CardAnimationRecorder(card: card)
            let retargeted = expectation(description: "second step during growth")
            recorder.didSample = { [weak recorder, weak renderer] in
                guard let recorder, let height = recorder.frames.last?.height,
                    height > initial.height + 2, height < initial.height + 65 else { return }
                recorder.didSample = nil
                renderer?.state.submitSurvey()
                retargeted.fulfill()
            }
            recorder.start()
            renderer.state.submitSurvey()
            wait(for: [retargeted], timeout: 3)
            waitUntilSettled(card, height: initial.height)
            recorder.stop()
            XCTAssertTrue(recorder.frames.contains { $0.height > initial.height + 2 })
            XCTAssertLessThan(recorder.frames.map(\.height).max() ?? 0, initial.height + 100,
                              "Retargeting must not jump to the abandoned tall destination.")
            assertAnchor(recorder.frames, initial: initial, style: style)
            attach(recorder.frames, name: "survey-\(style)-rapid-retarget")
            dismiss(renderer)
        }
    }

    func testCloseDuringResizeFreezesHeightUntilNativeRemoval() throws {
        for style in [UPExperienceHostingController.Style.bottomSheet, .dialog] {
            let (renderer, card) = try present(style: style)
            let initialHeight = card.bounds.height
            let recorder = CardAnimationRecorder(card: card)
            var closingHeight: CGFloat?
            var closeIndex = 0
            let removed = expectation(description: "native removal after interrupted resize")
            recorder.didSample = { [weak recorder, weak renderer] in
                guard let recorder, let height = recorder.frames.last?.height,
                    height > initialHeight + 2, closingHeight == nil else { return }
                closingHeight = height
                closeIndex = recorder.frames.count
                renderer?.triggerCloseExperience(manualClose: true) { removed.fulfill() }
                NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
            }
            recorder.start()
            renderer.state.submitSurvey()
            wait(for: [removed], timeout: 3)
            recorder.stop()
            let height = try XCTUnwrap(closingHeight)
            let exit = Array(recorder.frames.dropFirst(closeIndex))
            XCTAssertGreaterThan(exit.count, 2)
            if style == .bottomSheet {
                for frame in exit { XCTAssertEqual(frame.height, height, accuracy: 1) }
                for (old, next) in zip(exit, exit.dropFirst()) { XCTAssertGreaterThanOrEqual(next.minY, old.minY - 1) }
            } else {
                // Dialog exit intentionally scales to 96%; it must never grow to the abandoned target.
                for frame in exit { XCTAssertLessThanOrEqual(frame.height, height + 1) }
                let center = try XCTUnwrap(exit.first).midY
                for frame in exit { XCTAssertEqual(frame.midY, center, accuracy: 1) }
            }
            XCTAssertNil(renderer.presentingViewController)
            attach(recorder.frames, name: "survey-\(style)-close-during-resize")
        }
    }
}

private extension SurveyResizeHostingTests {
    func verifyResize(style: UPExperienceHostingController.Style) throws {
        let (renderer, card) = try present(style: style)
        let initial = card.frame
        let grow = CardAnimationRecorder(card: card)
        grow.start()
        renderer.state.submitSurvey()
        assertStep(renderer, index: 1)
        let grown = expectation(for: NSPredicate { _, _ in
            card.bounds.height > initial.height + 100 && card.layer.animationKeys()?.isEmpty != false
        }, evaluatedWith: nil)
        wait(for: [grown], timeout: 3)
        grow.stop()
        let largeHeight = card.bounds.height
        XCTAssertTrue(grow.frames.contains { $0.height > initial.height + 1 && $0.height < largeHeight - 1 },
                      "Growth needs intermediate rendered heights, not only a final bounds update.")
        assertAnchor(grow.frames, initial: initial, style: style)
        assertUnscaledRegions(grow)
        let shrink = CardAnimationRecorder(card: card)
        shrink.start()
        renderer.state.submitSurvey()
        assertStep(renderer, index: 2)
        waitUntilSettled(card, height: initial.height)
        shrink.stop()
        XCTAssertTrue(shrink.frames.contains { $0.height > initial.height + 1 && $0.height < largeHeight - 1 },
                      "Shrink needs intermediate rendered heights.")
        assertAnchor(shrink.frames, initial: initial, style: style)
        assertUnscaledRegions(shrink)
        attach(grow.frames, name: "survey-\(style)-grow")
        attach(shrink.frames, name: "survey-\(style)-shrink")
        dismiss(renderer)
    }

    func present(style: UPExperienceHostingController.Style) throws -> (UPExperienceHostingController, UIView) {
        let survey = try fixture()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let state = ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container)))
        let renderer = UPExperienceHostingController(state: state, style: style)
        renderer.modalPresentationStyle = .overFullScreen
        window.rootViewController = UIViewController()
        window.rootViewController?.present(renderer, animated: false)
        let card = try XCTUnwrap(renderer.view.subviews.last)
        let entered = expectation(for: NSPredicate { _, _ in
            card.alpha == 1 && card.transform == .identity && card.layer.animationKeys()?.isEmpty != false
        }, evaluatedWith: nil)
        wait(for: [entered], timeout: 3)
        return (renderer, card)
    }

    func waitUntilSettled(_ card: UIView, height: CGFloat) {
        let settled = expectation(for: NSPredicate { _, _ in
            abs(card.bounds.height - height) < 1 && card.layer.animationKeys()?.isEmpty != false
        }, evaluatedWith: nil)
        wait(for: [settled], timeout: 3)
    }

    func assertAnchor(_ frames: [CGRect], initial: CGRect, style: UPExperienceHostingController.Style) {
        XCTAssertGreaterThan(frames.count, 3)
        for frame in frames {
            if style == .bottomSheet { XCTAssertEqual(frame.maxY, initial.maxY, accuracy: 1) }
            if style == .dialog { XCTAssertEqual(frame.midY, initial.midY, accuracy: 1) }
        }
    }

    func assertStep(_ renderer: UPExperienceHostingController, index: Int) {
        guard case .survey(let model) = renderer.state.content else { return XCTFail("Expected survey") }
        XCTAssertEqual(model.currentStep, index)
    }

    func assertUnscaledRegions(_ recorder: CardAnimationRecorder) {
        for heights in [recorder.headerHeights, recorder.footerHeights] {
            guard let initial = heights.first else { return XCTFail("Missing header/footer frames") }
            for height in heights { XCTAssertEqual(height, initial, accuracy: 1) }
        }
    }

    func dismiss(_ renderer: UPExperienceHostingController) {
        let removed = expectation(description: "fixture removed")
        renderer.triggerCloseExperience(manualClose: true) { removed.fulfill() }
        wait(for: [removed], timeout: 3)
    }

    func attach(_ frames: [CGRect], name: String) {
        let attachment = XCTAttachment(string: frames.map { String(describing: $0) }.joined(separator: "\n"))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func fixture() throws -> SurveyContent {
        let choices = (1...7).map { ["id": "choice-\($0)", "value": "Choice \($0)"] }
        let short: [String: Any] = [
            "type": "single_input", "question": "Your email", "metadata": ["input_type": "email"]
        ]
        var first = short
        first["id"] = 1
        var last = short
        last["id"] = 3
        let modules: [[String: Any]] = [first, [
            "id": 2, "type": "multiple_choice", "question": "Which details matter to you?",
            "metadata": ["choices": choices, "is_multi_select": true]
        ], last]
        let decoded = try JSONDecoder().decode([SurveyStep].self, from: JSONSerialization.data(withJSONObject: modules))
        return SurveyContent(id: 400, type: .step, modules: decoded,
                             metadata: SurveyContentMetaData(buttonLabel: "Next"),
                             surveyTheme: MockContentFactory.makeSurveyMobileTheme(), screens: [],
                             screenType: .all, localeCode: "en", timeDelay: 0)
    }
}
