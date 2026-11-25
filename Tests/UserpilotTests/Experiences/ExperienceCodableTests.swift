//
//  ExperienceCodableTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies experience encoding preserves backend keys and custom value shapes.
//

import XCTest
@testable import Userpilot

final class ExperienceCodableTests: XCTestCase {

    func testFlowEnvelopeRoundTripPreservesWireKeysAndStepContent() throws {
        let (decoded, json) = try roundTrip(MockContentFactory.makeFlowContentPayload(), as: FlowContentData.self)
        let content = try XCTUnwrap(decoded.flowContent)
        let encoded = try XCTUnwrap(json["mobile_contents"] as? [String: Any])

        XCTAssertEqual(content.id, 77)
        XCTAssertEqual(content.steps.first?.id, 114)
        XCTAssertNotNil(encoded["theme_data"])
        XCTAssertEqual(encoded["screen_type"] as? String, "all")
        XCTAssertNil(json["flowContent"])
        XCTAssertNil(encoded["mobileTheme"])
    }

    func testSurveyEnvelopeRoundTripPreservesQuestionIdentity() throws {
        let (decoded, json) = try roundTrip(MockContentFactory.makeSurveyContentPayload(), as: SurveyContentData.self)
        XCTAssertEqual(decoded.surveyContent?.id, 12)
        XCTAssertEqual(decoded.surveyContent?.modules.first?.type, .likert)
        XCTAssertNotNil(json["surveys"])
        XCTAssertNil(json["surveyContent"])
    }

    func testNPSEnvelopeRoundTripPreservesContentKeys() throws {
        let (decoded, json) = try roundTrip(MockContentFactory.makeNPSContentPayload(), as: NPSContentData.self)
        let encoded = try XCTUnwrap(json["nps"] as? [String: Any])
        let content = try XCTUnwrap(encoded["content"] as? [String: Any])

        XCTAssertEqual(decoded.npsContent?.content.survey.key, "nps_score")
        XCTAssertNotNil(encoded["theme_data"])
        XCTAssertNotNil(content["follow_up"])
        XCTAssertNil(json["npsContent"])
        XCTAssertNil(content["followUp"])
    }

    func testThemeRoundTripPreservesExplicitZeroAndFalse() throws {
        let payload: [String: Any] = [
            "id": 99,
            "theme_data": ["carousel": [
                "button": ["border_radius": 0],
                "backdrop": ["enabled": false]
            ]]
        ]
        let (decoded, json) = try roundTrip(payload, as: ThemeContent.self)
        XCTAssertEqual(decoded.themeData?.carousel?.button?.borderRadius, 0)
        XCTAssertEqual(decoded.themeData?.carousel?.backdrop?.enabled, false)
        XCTAssertNotNil(json["theme_data"])
        XCTAssertNil(json["themeData"])
    }

    /// The renderer's projected configuration is never decoded, so it never reaches the encoded step either.
    func testTooltipFlowRoundTripPreservesTheStepsTargetAndSettingsOnly() throws {
        let (decoded, json) = try roundTrip(
            MockContentFactory.makeTooltipFlowPayload(stepCount: 1), as: FlowContentData.self
        )
        let content = try XCTUnwrap(decoded.flowContent)
        let step = try XCTUnwrap(content.steps.first)
        XCTAssertEqual(content.type, .flow)
        XCTAssertEqual(step.target?.toStepTargeting().selector?.effectiveProperties["accessibility_identifier"],
                       "tooltip-target-0")
        XCTAssertEqual(step.settings?.position, .below)
        XCTAssertNil(step.targeting)
        XCTAssertNil(step.presentation)

        let flow = try XCTUnwrap(json["mobile_contents"] as? [String: Any])
        let steps = try XCTUnwrap(flow["steps"] as? [[String: Any]])
        let encoded = try XCTUnwrap(steps.first)
        XCTAssertEqual(Set(encoded.keys), [
            "id", "order", "position", "step_type", "sections", "button_action", "settings", "target"
        ])
        let selector = try XCTUnwrap((encoded["target"] as? [String: Any])?["selector"] as? [String: Any])
        XCTAssertEqual(selector["accessibility_identifier"] as? String, "tooltip-target-0")
    }

    func testSurveyLogicRoundTripPreservesScalarAndArrayValues() throws {
        for value: Any in ["choice-1", ["choice-1", "choice-2"]] {
            let payload: [String: Any] = [
                "action": "go_to_module", "module_id": 101,
                "operand": "equals", "metadata": ["value": value]
            ]
            let (decoded, json) = try roundTrip(payload, as: SurveyLogic.self)
            let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
            XCTAssertEqual(decoded.moduleId, 101)
            XCTAssertEqual(json["module_id"] as? Int, 101)
            XCTAssertTrue(NSDictionary(dictionary: metadata).isEqual(to: ["value": value]))
        }
    }

    private func roundTrip<T: Codable>(_ payload: [String: Any], as type: T.Type) throws -> (T, [String: Any]) {
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(type, from: data)
        let encoded = try JSONEncoder().encode(decoded)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        return (try JSONDecoder().decode(type, from: encoded), json)
    }
}
