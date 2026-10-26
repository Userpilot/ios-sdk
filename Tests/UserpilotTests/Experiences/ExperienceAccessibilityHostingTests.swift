//
//  ExperienceAccessibilityHostingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 26/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Mounts real experiences under overridden text sizes and checks text scaling and accessibility.
//

import SwiftUI
import UIKit
import XCTest

@testable import Userpilot

final class ExperienceAccessibilityHostingTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "A11Y-\(UUID().uuidString)").defaultInstance(false))
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

    func testTextScalingFollowsTheFlagAndStopsAtTheCap() throws {
        let large = try contentHeight(scaling: true, category: .large)
        let capped = try contentHeight(scaling: true, category: .accessibilityLarge)
        let largest = try contentHeight(scaling: true, category: .accessibilityExtraExtraExtraLarge)
        XCTAssertGreaterThan(largest, large + 40, "Opted-in text grows with the user's size.")
        XCTAssertEqual(largest, capped, accuracy: 1, "Sizes above the cap render like the cap.")
        let offLarge = try contentHeight(scaling: false, category: .large)
        let offLargest = try contentHeight(scaling: false, category: .accessibilityExtraExtraExtraLarge)
        XCTAssertEqual(offLargest, offLarge, accuracy: 1, "Without the opt-in, text keeps its authored size.")
        XCTAssertEqual(offLarge, large, accuracy: 1)
    }

    /// The plan's squeeze check: header and footer sit outside the scroll area, so at the cap on the
    /// smallest landscape phone the scrolling body must keep usable room.
    func testSmallLandscapePhoneAtTheCapKeepsRoomForTheScrollingBody() throws {
        window.frame = CGRect(x: 0, y: 0, width: 667, height: 375)
        let (_, renderer) = try mountDialog(scaling: true, category: .accessibilityLarge)
        renderer.view.layoutIfNeeded()
        let body = try XCTUnwrap(renderer.contentController?.view.superview as? UIScrollView)
        attachWindow(name: "landscape-se-accessibility-large")
        XCTAssertGreaterThanOrEqual(body.bounds.height, 44, "The scrolling body keeps a touch target of room.")
    }

    func testTextSizeChangeWhileShownRemeasuresTheCard() throws {
        let (container, renderer) = try mountDialog(scaling: true, category: .large)
        let before = try XCTUnwrap(renderer.contentController).view.frame.height
        container.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityLarge), forChild: renderer)
        NotificationCenter.default.post(name: UIContentSizeCategory.didChangeNotification, object: nil)
        let grown = expectation(for: NSPredicate { _, _ in
            (renderer.contentController?.view.frame.height ?? 0) > before + 40
        }, evaluatedWith: nil)
        wait(for: [grown], timeout: 3)
        attachWindow(name: "text-size-changed-while-shown")
    }
}

extension ExperienceAccessibilityHostingTests {
    func testMultilineInputKeepsFiveHundredCharactersInTheFieldAndTheModel() throws {
        let mounted = try mountOpenText(category: .large)
        let (renderer, textView, step) = (mounted.renderer, mounted.textView, mounted.step)
        textView.insertText(String(repeating: "a", count: 510))
        let trimmed = expectation(for: NSPredicate { _, _ in textView.text.count == 500 }, evaluatedWith: nil)
        wait(for: [trimmed], timeout: 3)
        XCTAssertEqual(renderer.state.answer(for: step).text.count, 500)
        XCTAssertTrue(textView.becomeFirstResponder())
        XCTAssertTrue(renderer.view.firstResponder === textView, "The host's keyboard scroll can find the input.")
        textView.resignFirstResponder()
    }

    func testMultilineInputUsesTheResolvedFontAndAScaledHeight() throws {
        let textView = try mountOpenText(category: .accessibilityLarge).textView
        XCTAssertEqual(textView.font?.pointSize ?? 0,
                       UPExperienceStyle.scaledSize(16, for: .accessibilityLarge), accuracy: 0.01)
        XCTAssertEqual(textView.bounds.height,
                       UPExperienceStyle.scaledSize(120, for: .accessibilityLarge), accuracy: 1)
        XCTAssertEqual(textView.autocorrectionType, .no)
        XCTAssertEqual(textView.autocapitalizationType, UITextAutocapitalizationType.none)
    }

    private struct OpenText {
        let renderer: UPExperienceHostingController
        let textView: UITextView
        let step: SurveyStep
    }

    private func mountOpenText(category: UIContentSizeCategory) throws -> OpenText {
        let survey = try MockContentFactory.makeQuestionSurvey(type: .list)
        let step = try XCTUnwrap(survey.modules.first { $0.type == .openText })
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let state = ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container)), textScaling: true)
        let (_, renderer) = try mount(state, style: .fullScreen, category: category)
        let content = try XCTUnwrap(renderer.contentController)
        let textView = try XCTUnwrap(allViews(in: content.view).compactMap { $0 as? UITextView }.first {
            !($0 is UPExperienceLinkText.LinkTextView)
        })
        return OpenText(renderer: renderer, textView: textView, step: step)
    }

    /// SwiftUI headings can't be inspected outside an assistive client; a heading with a link is a
    /// UIKit text view, so its header trait is checked here.
    func testHeadingWithALinkKeepsTheHeaderTrait() throws {
        var payload = MockContentFactory.makeRichTextFlowPayload()
        var content = try XCTUnwrap(payload["mobile_contents"] as? [String: Any])
        var step = try XCTUnwrap((content["steps"] as? [[String: Any]])?.first)
        let heading: [String: Any] = [
            "type": "heading", "attrs": ["__type__": "heading", "level": "h2"],
            "content": [["type": "text", "text": "Read the guide",
                         "marks": [["type": "link", "attrs": ["href": MockContentFactory.termsURL]]]]]
        ]
        step["sections"] = [["lines": [heading]]] + ((step["sections"] as? [[String: Any]]) ?? [])
        content["steps"] = [step]
        payload["mobile_contents"] = content
        let flow = try XCTUnwrap(payload.toJSONString()?.toFlowContent()?.flowContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let (_, renderer) = try mount(
            ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container))), style: .dialog)
        let links = allViews(in: try XCTUnwrap(renderer.contentController).view)
            .compactMap { $0 as? UPExperienceLinkText.LinkTextView }
        let headingView = try XCTUnwrap(links.first { $0.text == "Read the guide" })
        XCTAssertTrue(headingView.accessibilityTraits.contains(.header))
        XCTAssertFalse(links.filter { $0 !== headingView }.contains { $0.accessibilityTraits.contains(.header) })
    }

    func testFlowRichTextAndLinkLinesUseTheResolvedFont() throws {
        let large = try richTextFlow(category: .large)
        let capped = try richTextFlow(category: .accessibilityExtraExtraExtraLarge)
        XCTAssertGreaterThan(capped.height, large.height + 100, "Flow text scales once opted in.")
        let linkView = try XCTUnwrap(capped.links.first)
        let font = try XCTUnwrap(linkView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertEqual(font.pointSize, UPExperienceStyle.scaledSize(16, for: .accessibilityLarge), accuracy: 0.01)
        XCTAssertEqual(large.links.count, 2, "Only the two lines with links use a text view.")
        XCTAssertGreaterThanOrEqual(linkView.bounds.height, linkView.sizeThatFits(
            CGSize(width: linkView.bounds.width, height: .greatestFiniteMagnitude)).height - 1,
            "The pinned height fits the scaled text.")
        attachWindow(name: "rich-text-accessibility-large")
    }

    private func richTextFlow(
        category: UIContentSizeCategory
    ) throws -> (height: CGFloat, links: [UPExperienceLinkText.LinkTextView]) {
        let flow = try XCTUnwrap(
            MockContentFactory.makeRichTextFlowPayload().toJSONString()?.toFlowContent()?.flowContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let state = ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container)), textScaling: true)
        let (_, renderer) = try mount(state, style: .dialog, category: category)
        let content = try XCTUnwrap(renderer.contentController)
        return (content.view.frame.height,
                allViews(in: content.view).compactMap { $0 as? UPExperienceLinkText.LinkTextView })
    }

    /// Mounts a step-survey dialog as a child so the test can override the user's text size.
    func mountDialog(
        scaling: Bool, category: UIContentSizeCategory,
        survey: SurveyContent? = nil
    ) throws -> (UIViewController, UPExperienceHostingController) {
        let survey = try survey ?? MockContentFactory.makeQuestionSurvey(type: .step)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let state = ExperienceRenderState(
            .survey(SurveyViewModel(container: userpilot.container)), textScaling: scaling)
        return try mount(state, style: .dialog, category: category)
    }

    func mount(
        _ state: ExperienceRenderState, style: UPExperienceHostingController.Style,
        category: UIContentSizeCategory = .large
    ) throws -> (UIViewController, UPExperienceHostingController) {
        let renderer = UPExperienceHostingController(state: state, style: style)
        let container = UIViewController()
        window.rootViewController = container
        container.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: category), forChild: renderer)
        container.addChild(renderer)
        container.view.addSubview(renderer.view)
        renderer.view.frame = container.view.bounds
        renderer.didMove(toParent: container)
        renderer.view.layoutIfNeeded()
        let laidOut = expectation(for: NSPredicate { _, _ in
            (renderer.contentController?.view.frame.height ?? 0) > 50 || renderer.carouselController != nil
        }, evaluatedWith: nil)
        wait(for: [laidOut], timeout: 3)
        return (container, renderer)
    }

    func contentHeight(scaling: Bool, category: UIContentSizeCategory) throws -> CGFloat {
        let (_, renderer) = try mountDialog(scaling: scaling, category: category)
        renderer.view.layoutIfNeeded()
        return try XCTUnwrap(renderer.contentController).view.frame.height
    }

    func allViews(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { allViews(in: $0) }
    }

    func attachWindow(name: String) {
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
}
