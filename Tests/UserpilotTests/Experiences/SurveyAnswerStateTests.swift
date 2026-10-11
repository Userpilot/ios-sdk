//
//  SurveyAnswerStateTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Locks the legacy answer payload and validation rules during declarative rendering migration.
//

import XCTest

@testable import Userpilot

final class SurveyAnswerStateTests: XCTestCase {
    func testOtherChoicePayloadIncludesTextButBranchValueUsesRawID() throws {
        let step = try question(
            type: "multiple_choice",
            metadata: [
                "is_multi_select": false, "choices": [["id": "a", "value": "A"]],
                "other_choice": ["enabled": true]
            ])
        var answer = SurveyAnswerState()
        answer.toggleChoice(1, for: step)
        answer.otherText = "Detailed answer"
        XCTAssertEqual(answer.answer(for: step) as? String, ThemeHandler.DefaultValues.surveyOtherChoice)
        XCTAssertEqual(
            answer.payload(for: step)?["value"] as? [String],
            [ThemeHandler.DefaultValues.surveyOtherChoice + "Detailed answer"])
    }

    func testChoiceToggleRetainsBackendOrderAndSwitchesSingleSelection() throws {
        let metadata: [String: Any] = ["choices": [["id": "a"], ["id": "b"]], "is_multi_select": true]
        let multi = try question(type: "multiple_choice", metadata: metadata)
        var answer = SurveyAnswerState()
        answer.toggleChoice(1, for: multi)
        answer.toggleChoice(0, for: multi)
        XCTAssertEqual(answer.answer(for: multi) as? [String], ["a", "b"])
        let single = try question(type: "multiple_choice", metadata: ["choices": [["id": "a"], ["id": "b"]]])
        answer.toggleChoice(0, for: single)
        XCTAssertEqual(answer.answer(for: single) as? String, "a")
    }

    func testRequiredValidationAndNativePhonePayload() throws {
        let step = try question(type: "single_input", metadata: ["input_type": "phone_number"])
        var answer = SurveyAnswerState()
        XCTAssertFalse(answer.isValid(for: step))
        XCTAssertEqual(answer.payload(for: step)?["value"] as? String, "+1")
        answer.countryCode = "+44"
        answer.updateText("1234", for: step)
        XCTAssertTrue(answer.isValid(for: step))
        XCTAssertEqual(answer.payload(for: step)?["value"] as? String, "+441234")
        answer.updateText("1234x", for: step)
        XCTAssertEqual(answer.text, "1234")
    }

    func testOpenTextAndGeneralInputKeepExistingLengthLimits() throws {
        let open = try question(type: "open_text")
        let single = try question(type: "single_input", metadata: ["input_type": "general", "max_length": 12])
        var answer = SurveyAnswerState()
        answer.updateText(String(repeating: "a", count: 600), for: open)
        XCTAssertEqual(answer.text.count, 500)
        answer.updateText(String(repeating: "a", count: 40), for: single)
        XCTAssertEqual(answer.text.count, 12)
    }

    func testOptionalInvalidEmailPreservesLegacyAdmissionAndDateRequiresTenCharacters() throws {
        let email = try question(type: "single_input", required: false, metadata: ["input_type": "email"])
        let date = try question(type: "single_input", metadata: ["input_type": "date"])
        var answer = SurveyAnswerState()
        answer.text = "invalid"
        XCTAssertTrue(answer.isValid(for: email))
        XCTAssertFalse(answer.isValid(for: date))
        answer.updateText("09102026", for: date)
        XCTAssertEqual(answer.text, "09/10/2026")
        XCTAssertTrue(answer.isValid(for: date))
    }

    private func question(type: String, required: Bool = true, metadata: [String: Any] = [:]) throws -> SurveyStep {
        let payload: [String: Any] = ["id": 123, "type": type, "is_required": required, "metadata": metadata]
        return try JSONDecoder().decode(SurveyStep.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}
