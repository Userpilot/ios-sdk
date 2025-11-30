//
//  SurveyLogicHandlerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

class SurveyLogicHandlerTests: XCTestCase {

    func makeSurveyStep(id: Int) -> SurveyStep {
        SurveyStep(
            id: id,
            isRequired: nil,
            logic: nil,
            metadata: nil,
            question: nil,
            subheader: nil,
            type: .openText,
            buttonLabel: nil
        )
    }

    func test_noLogic_goesToNextStep() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        // Act
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [],
            answer: nil,
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)
    }

    func test_operandEquals_conditionMet_goToModule() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        let logic = SurveyLogic(
            action: .goToModule,
            metadata: LogicMetadata(value: .string("yes")),
            moduleId: 2,
            operand: .equals
        )

        // Act
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logic],
            answer: "yes",
            surveySteps: surveySteps
        )

        // Assert
        // Should go to step with id == moduleId (2)
        XCTAssertEqual(result.0, 1)
        XCTAssertFalse(result.1)
    }

    func test_operandNotEquals_conditionMet_endSurvey() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2), makeSurveyStep(id: 3)]

        let logic = SurveyLogic(
            action: .endSurvey,
            metadata: LogicMetadata(value: .string("no")),
            moduleId: nil,
            operand: .notEquals
        )

        // Act
        // Answer different from "no" triggers conditionMet
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logic],
            answer: "yes",
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, surveySteps.count - 1) // last step index
        XCTAssertTrue(result.1) // survey ended
    }

    func test_operandContains_conditionMet_goToNextModule() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        let logic = SurveyLogic(
            action: .goToNextModule,
            metadata: LogicMetadata(value: .string("apple")),
            moduleId: nil,
            operand: .contains
        )

        let answer = "apple pie"

        // Act
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logic],
            answer: answer,
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)
    }

    func test_operandAll_conditionMet() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        let logic = SurveyLogic(
            action: .goToNextModule,
            metadata: LogicMetadata(value: .array(["a", "b"])),
            moduleId: nil,
            operand: .all
        )

        let answer = ["a", "b", "c"]

        // Act
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logic],
            answer: answer,
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)
    }

    func test_operandAny_conditionMet() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        let logic = SurveyLogic(
            action: .goToNextModule,
            metadata: LogicMetadata(value: .array(["a", "b"])),
            moduleId: nil,
            operand: .any
        )

        let answer = ["x", "b", "y"]

        // Act
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logic],
            answer: answer,
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)
    }

    func test_operandGreaterThan_conditionMet() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        let logic = SurveyLogic(
            action: .goToNextModule,
            metadata: LogicMetadata(value: .string("10")),
            moduleId: nil,
            operand: .greaterThan
        )

        let answer = 15

        // Act
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logic],
            answer: answer,
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)
    }

    func test_operandLessThan_conditionMet() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        let logic = SurveyLogic(
            action: .goToNextModule,
            metadata: LogicMetadata(value: .string("10")),
            moduleId: nil,
            operand: .lessThan
        )

        let answer = 5

        // Act
        let result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logic],
            answer: answer,
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)
    }

    func test_operandNotKnown_andKnown() {
        // Arrange
        let currentStep = 0
        let surveySteps = [makeSurveyStep(id: 1), makeSurveyStep(id: 2)]

        let logicNotKnown = SurveyLogic(
            action: .goToNextModule,
            metadata: nil,
            moduleId: nil,
            operand: .notKnown
        )

        let logicKnown = SurveyLogic(
            action: .goToNextModule,
            metadata: nil,
            moduleId: nil,
            operand: .known
        )

        // Act
        // nil answer triggers notKnown condition
        var result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logicNotKnown],
            answer: nil,
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)

        // Act
        // known operand always triggers
        result = SurveyLogicHandler.getNextQuestionIndex(
            currentStep: currentStep,
            stepLogic: [logicKnown],
            answer: "anything",
            surveySteps: surveySteps
        )

        // Assert
        XCTAssertEqual(result.0, currentStep + 1)
        XCTAssertFalse(result.1)
    }
}
