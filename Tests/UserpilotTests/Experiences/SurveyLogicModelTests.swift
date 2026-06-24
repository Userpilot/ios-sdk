//
//  SurveyLogicModelTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class SurveyLogicModelTests: XCTestCase {

    func testDecodesStringMetadataValue() throws {
        let logic = try decodeLogic("""
        {
          "action": "go_to_module",
          "metadata": { "value": "yes" },
          "module_id": 42,
          "operand": "equals"
        }
        """)

        XCTAssertEqual(logic.action, .goToModule)
        XCTAssertEqual(logic.moduleId, 42)
        XCTAssertEqual(logic.operand, .equals)
        guard case let .string(value) = logic.metadata?.value else {
            return XCTFail("Expected string metadata")
        }
        XCTAssertEqual(value, "yes")
    }

    func testDecodesArrayMetadataValue() throws {
        let logic = try decodeLogic("""
        {
          "action": "end_survey",
          "metadata": { "value": ["a", "b"] },
          "operand": "contains"
        }
        """)

        XCTAssertEqual(logic.action, .endSurvey)
        XCTAssertNil(logic.moduleId)
        XCTAssertEqual(logic.operand, .contains)
        guard case let .array(value) = logic.metadata?.value else {
            return XCTFail("Expected array metadata")
        }
        XCTAssertEqual(value, ["a", "b"])
    }

    func testAllActionAndOperandRawValuesDecode() throws {
        XCTAssertEqual(try decodeLogic("{ \"action\": \"go_to_next_module\" }").action, .goToNextModule)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"not_known\" }").operand, .notKnown)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"known\" }").operand, .known)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"not_contains\" }").operand, .notContains)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"not_equals\" }").operand, .notEquals)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"greater_than\" }").operand, .greaterThan)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"less_than\" }").operand, .lessThan)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"all\" }").operand, .all)
        XCTAssertEqual(try decodeLogic("{ \"operand\": \"any\" }").operand, .any)
    }

    func testInvalidMetadataValueFailsDecode() {
        XCTAssertThrowsError(try decodeLogic("""
        {
          "metadata": { "value": { "unsupported": true } }
        }
        """))
    }

    private func decodeLogic(_ json: String) throws -> SurveyLogic {
        try JSONDecoder().decode(SurveyLogic.self, from: Data(json.utf8))
    }
}
