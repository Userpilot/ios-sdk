//
//  ExperienceDecodingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies typed payload rejection, diagnostics and optional appearance values.
//

import XCTest
@testable import Userpilot

final class ExperienceDecodingTests: XCTestCase {
    func testNumericStringsRejectEachExperienceAndLogTheFieldPath() throws {
        struct TestCase {
            let payload: [String: Any]
            let root: String
            let field: String
            let value: String
        }
        var slideOutPayload = MockContentFactory.makeFlowContentPayload()
        var slideOut = try XCTUnwrap(slideOutPayload["mobile_contents"] as? [String: Any])
        slideOut["type"] = "slideout"
        slideOutPayload["mobile_contents"] = slideOut
        let cases = [
            TestCase(
                payload: MockContentFactory.makeFlowContentPayload(), root: "mobile_contents", field: "id", value: "77"
            ),
            TestCase(payload: slideOutPayload, root: "mobile_contents", field: "id", value: "77"),
            TestCase(
                payload: MockContentFactory.makeFlowContractPayload(), root: "mobile_contents",
                field: "steps_count", value: "3"
            ),
            TestCase(
                payload: MockContentFactory.makeSurveyContentPayload(), root: "surveys", field: "time_delay", value: "0"
            ),
            TestCase(payload: MockContentFactory.makeNPSContentPayload(), root: "nps", field: "time_delay", value: "0")
        ]
        for testCase in cases {
            var modified = testCase.payload
            var content = try XCTUnwrap(testCase.payload[testCase.root] as? [String: Any])
            content[testCase.field] = testCase.value
            modified[testCase.root] = content
            let logger = decodingLogger(expectingPath: "\(testCase.root).\(testCase.field)")
            XCTAssertTrue(try XCTUnwrap(modified.toJSONString()).experienceCandidates(logger: logger).isEmpty)
            XCTAssertEqual(logger.loggedErrors.count, 1)
        }
    }

    func testInvalidOptionalThemeNumberRejectsResponseAndLogsTheFieldPath() throws {
        let json = """
        {"id":1,"theme_data":{"carousel":{"button":{"border_radius":"12"}}}}
        """
        let logger = decodingLogger(expectingPath: "theme_data.carousel.button.border_radius")
        XCTAssertNil(json.toMobileTheme(logger: logger))
        XCTAssertEqual(logger.loggedErrors.count, 1)
    }

    func testOptionalThemeNumbersPreserveAbsenceNullZeroAndFalse() throws {
        for button in [[:], ["border_radius": NSNull()], ["border_radius": 0]] as [[String: Any]] {
            let payload: [String: Any] = [
                "id": 1, "theme_data": ["carousel": ["button": button, "backdrop": ["enabled": false]]]
            ]
            let theme = try XCTUnwrap(payload.toJSONString()?.toMobileTheme()?.themeData?.carousel)
            XCTAssertEqual(theme.backdrop?.enabled, false)
            if button["border_radius"] is Int {
                XCTAssertEqual(theme.button?.borderRadius, 0)
            } else {
                XCTAssertNil(theme.button?.borderRadius)
            }
        }
    }

    func testOptionalThemeEnumAcceptsMissingNullAndWireNameButRejectsUnknown() throws {
        for dismiss in [[:], ["color_type": NSNull()], ["color_type": "manual"]] as [[String: Any]] {
            let payload: [String: Any] = ["theme_data": ["carousel": ["dismiss_content": dismiss]]]
            XCTAssertNotNil(payload.toJSONString()?.toMobileTheme())
        }
        let json = """
        {"theme_data":{"carousel":{"dismiss_content":{"color_type":"unknown"}}}}
        """
        XCTAssertNil(json.toMobileTheme())
    }

    func testMalformedFlowLeavesValidSurveyCandidateAvailable() throws {
        var payload = MockContentFactory.makeSurveyContentPayload()
        var flow = try XCTUnwrap(MockContentFactory.makeFlowContentPayload()["mobile_contents"] as? [String: Any])
        flow["id"] = "77"
        payload["mobile_contents"] = flow
        let candidates = try XCTUnwrap(payload.toJSONString()).experienceCandidates()
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.asSurveyContent()?.id, 12)
    }

    /// The backend sends `theme_id` and `id` with one value; flow, survey and Android all read `id`.
    func testFlowThemeIDDecodesFromIDKey() throws {
        var payload = MockContentFactory.makeFlowContentPayload()
        var flow = try XCTUnwrap(payload["mobile_contents"] as? [String: Any])
        flow["theme_data"] = ["id": 11, "theme_data": NSNull()]
        payload["mobile_contents"] = flow
        let candidates = try XCTUnwrap(payload.toJSONString()).experienceCandidates()
        XCTAssertEqual(candidates.first?.asFlowContent()?.baseThemeId, 11)
    }

    /// Payloads from before mobile Flows have none of the Flow keys and keep decoding as before.
    func testCarouselPayloadDecodesWithoutFlowFields() throws {
        let json = try XCTUnwrap(MockContentFactory.makeFlowContentPayload().toJSONString())
        let flow = try XCTUnwrap(json.experienceCandidates().first?.asFlowContent())
        XCTAssertEqual(flow.type, .carousel)
        XCTAssertNil(flow.stepsCount)
        XCTAssertFalse(flow.steps.isEmpty)
        for step in flow.steps {
            XCTAssertNil(step.position)
            XCTAssertNil(step.stepType)
            XCTAssertNil(step.settings)
            XCTAssertNil(step.target)
        }
    }

    private func decodingLogger(expectingPath path: String) -> MockLogger {
        let logger = MockLogger()
        // Inspect arguments directly: MockLogger's printf formatter does not support OSLog privacy markers.
        logger.onError = { _, arguments in
            XCTAssertTrue(String(describing: arguments).contains(path))
        }
        return logger
    }

}
