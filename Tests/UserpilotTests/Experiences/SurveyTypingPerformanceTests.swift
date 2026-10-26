//
//  SurveyTypingPerformanceTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 26/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Keystroke cost must not grow with the number of questions in a list survey.
//

import QuartzCore
import UIKit
import XCTest

@testable import Userpilot

final class SurveyTypingPerformanceTests: XCTestCase {
    private var userpilot: MockUserpilot!
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "TYPE-\(UUID().uuidString)").defaultInstance(false))
        userpilot.themeHandler.onMergeSurveyThemes = { _, theme in theme ?? MockContentFactory.makeSurveyTheme() }
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow()
        }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
        window = nil
        userpilot = nil
        super.tearDown()
    }

    func testKeystrokeCostDoesNotGrowWithTheNumberOfQuestions() throws {
        try XCTSkipIf(UIApplication.shared.connectedScenes.isEmpty, "Timing needs the app-hosted renderer.")
        let small = try millisecondsPerKeystroke(questions: 4)
        let large = try millisecondsPerKeystroke(questions: 24)
        let report = XCTAttachment(
            string: String(format: "4 questions: %.2f ms/key\n24 questions: %.2f ms/key", small, large))
        report.name = "survey-keystroke-probe"
        report.lifetime = .keepAlways
        add(report)
        // Before per-question observation this was 1.9× (4.12 vs 2.16 ms on the iOS 18.3 simulator).
        XCTAssertLessThan(
            large, small * 1.5, String(format: "24 questions %.2f ms vs 4 questions %.2f ms", large, small))
    }

    private func millisecondsPerKeystroke(questions: Int) throws -> Double {
        let modules: [[String: Any]] = (1...questions).map {
            ["id": $0, "type": "open_text", "question": "Question \($0)", "metadata": ["placeholder": "Answer \($0)"]]
        }
        let decoded = try JSONDecoder().decode([SurveyStep].self, from: JSONSerialization.data(withJSONObject: modules))
        let survey = SurveyContent(
            id: 300 + questions, type: .list, modules: decoded,
            metadata: SurveyContentMetaData(buttonLabel: "Send"),
            surveyTheme: MockContentFactory.makeSurveyMobileTheme(),
            screens: [], screenType: .all, localeCode: "en", timeDelay: 0)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let renderer = UPExperienceHostingController(
            state: ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container))), style: .fullScreen)
        window.rootViewController = renderer
        renderer.view.frame = window.bounds
        renderer.view.layoutIfNeeded()
        let ready = expectation(for: NSPredicate { _, _ in
            (renderer.contentController?.view.frame.height ?? 0) > 100
        }, evaluatedWith: nil)
        wait(for: [ready], timeout: 5)
        let textView = try XCTUnwrap(allViews(in: try XCTUnwrap(renderer.contentController).view)
            .compactMap { $0 as? UITextView }.first)
        let keystrokes = 30
        let start = CACurrentMediaTime()
        for _ in 0..<keystrokes {
            textView.insertText("a")
            RunLoop.current.run(until: Date())
            renderer.view.layoutIfNeeded()
        }
        return (CACurrentMediaTime() - start) * 1000 / Double(keystrokes)
    }

    private func allViews(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { allViews(in: $0) }
    }
}
