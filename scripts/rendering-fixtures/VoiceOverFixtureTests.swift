//
//  VoiceOverFixtureTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 26/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  What VoiceOver reads. XCUITest is an assistive client, so SwiftUI builds its real accessibility tree.
//

import XCTest

final class VoiceOverFixtureTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
    }

    override func tearDown() {
        app.terminate()
        app = nil
        super.tearDown()
    }

    func testOnlyTheChosenOptionAndRatingAreSelected() {
        launch("survey-list")
        XCTAssertTrue(app.buttons["3"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["3"].isSelected, "The chosen star")
        XCTAssertFalse(app.buttons["1"].isSelected, "A filled star is not the answer")
        XCTAssertTrue(app.buttons["Speed"].isSelected)
        XCTAssertFalse(app.buttons["Quality"].isSelected)
        // XCUITest also lists SwiftUI elements hidden from VoiceOver, so the hidden placeholder and
        // checkbox symbols can't be asserted here; they are in the manual VoiceOver pass.
        attach(app.debugDescription, name: "survey-list-accessibility-tree")
    }

    func testLinksAndImagesAreExposed() {
        launch("rich-text")
        XCTAssertTrue(app.staticTexts["Heading one"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.links.matching(NSPredicate(format: "label == %@", "privacy policy")).count, 2)
        XCTAssertTrue(app.links["terms"].exists)
        XCTAssertTrue(app.images["Bullet icon"].exists, "Alt text makes the image an image element")
        // XCUITest doesn't expose the header trait; headings are in the manual VoiceOver pass (rotor).
        attach(app.debugDescription, name: "rich-text-accessibility-tree")
    }

    func testAccessibilityAuditAtTheLargestTextSize() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit needs iOS 17") }
        for fixture in [["-carousel-fixture"], ["-experience-fixture", "survey-list"], ["-experience-fixture", "rich-text"]] {
            app.launchArguments = fixture + ["-text-scaling",
                                             "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            _ = app.buttons.firstMatch.waitForExistence(timeout: 10)
            screenshot("audit-\(fixture.last ?? "fixture")-largest-text")
            var issues: [String] = []
            try app.performAccessibilityAudit(
                for: [.dynamicType, .textClipped, .sufficientElementDescription, .hitRegion, .trait]
            ) { issue in
                issues.append("\(issue.auditType): \(issue.compactDescription) — \(issue.element?.debugDescription ?? "")")
                // Text deliberately stops growing at the ~2× cap (Config.enableTextScaling), so the audit
                // reports Dynamic Type as "partially" supported above it. Anything else fails the test.
                return issue.auditType == .dynamicType && issue.compactDescription.contains("partially")
            }
            attach(issues.joined(separator: "\n"), name: "audit-\(fixture.last ?? "fixture")")
            app.terminate()
        }
    }

    private func launch(_ kind: String) {
        app.launchArguments = ["-experience-fixture", kind]
        app.launch()
    }

    private func attach(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
