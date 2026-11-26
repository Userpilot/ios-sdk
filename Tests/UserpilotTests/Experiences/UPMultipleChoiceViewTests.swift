//
//  UPMultipleChoiceViewTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies that optional choice IDs cannot introduce null or invented answer identities.
//

import XCTest
@testable import Userpilot

final class UPMultipleChoiceViewTests: XCTestCase {

    func testSingleSelectionOmitsMissingIDAndSubmitsIdentifiedChoice() throws {
        let view = try makeView(multiSelect: false)
        view.choices[0].isSelected = true

        XCTAssertNil(view.getAnswerPayload())
        XCTAssertFalse(view.isValidAnswer())

        view.choices[0].isSelected = false
        view.choices[1].isSelected = true

        XCTAssertEqual(view.getAnswer() as? String, "choice-1")
        XCTAssertEqual(view.getAnswerPayload()?["value"] as? [String], ["choice-1"])
        XCTAssertTrue(view.isValidAnswer())
    }

    func testMultipleSelectionOmitsMissingIDsFromSubmittedAnswers() throws {
        let view = try makeView(multiSelect: true)
        view.choices[0].isSelected = true
        view.choices[1].isSelected = true

        XCTAssertEqual(view.getAnswer() as? [String], ["choice-1"])
        XCTAssertEqual(view.getAnswerPayload()?["value"] as? [String], ["choice-1"])
    }

    private func makeView(multiSelect: Bool) throws -> UPMultipleChoiceView {
        let json = """
        {"id":101,"type":"multiple_choice","is_required":true,"metadata":{
            "is_multi_select":\(multiSelect),
            "choices":[{"value":"Missing ID"},{"id":"choice-1","value":"First"}]
        }}
        """
        let step = try JSONDecoder().decode(SurveyStep.self, from: Data(json.utf8))
        let view = UPMultipleChoiceView(margin: 0)
        view.surveyStep = step
        view.choices = try XCTUnwrap(step.metadata?.choices)
        return view
    }
}
