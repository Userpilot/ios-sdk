//
//  ScreenSessionStateMachineTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class ScreenSessionStateMachineTests: XCTestCase {

    func testPureScreenRetainsOriginalMetadataWithoutAnalyticsDecorations() throws {
        let metadata: [String: Any] = ["custom.key": ["enabled": true], "count": 3]
        let entity = ScreenSessionStateMachine(
            event: Event(type: .screen("Manual title"), properties: metadata),
            seenExperiences: [1], seenSurveys: [2]
        )
        let pure = entity.screenPayload
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pure)) as? NSDictionary)
        XCTAssertEqual(encoded, ["title": "Manual title", "metadata": metadata] as NSDictionary)
        let decorated = pure.toDictionary(adding: ["fake_reload": true, "seen_contents": [1]])
        XCTAssertEqual((decorated["metadata"] as? [String: Any])?["fake_reload"] as? Bool, true)
        XCTAssertNil(pure.metadata["fake_reload"])
        XCTAssertEqual(entity.seenExperiences, [1])
        XCTAssertEqual(entity.seenSurveys, [2])
    }

    func testInitializationStoresEventAndInitialSeenSets() {
        let event = Event(type: .screen("Home"))
        let entity = ScreenSessionStateMachine(event: event, seenExperiences: [1, 2], seenSurveys: [3])

        XCTAssertEqual(entity.event.screenTitle, "Home")
        XCTAssertEqual(entity.seenExperiences, [1, 2])
        XCTAssertEqual(entity.seenSurveys, [3])
    }

    func testUpdateSeenExperiencesDeduplicatesIds() {
        let entity = ScreenSessionStateMachine(event: Event(type: .screen("Home")))

        entity.updateSeenFlowExperiences(10)
        entity.updateSeenFlowExperiences(10)
        entity.updateSeenSurveyExperiences(20)
        entity.updateSeenSurveyExperiences(20)

        XCTAssertEqual(entity.seenExperiences, [10])
        XCTAssertEqual(entity.seenSurveys, [20])
    }

    func testResetStateClearsSeenSetsWithoutReplacingEvent() {
        let entity = ScreenSessionStateMachine(
            event: Event(type: .screen("Home")),
            seenExperiences: [1],
            seenSurveys: [2]
        )

        entity.resetState()

        XCTAssertTrue(entity.seenExperiences.isEmpty)
        XCTAssertTrue(entity.seenSurveys.isEmpty)
        XCTAssertEqual(entity.event.screenTitle, "Home")
    }

    // MARK: - Shown Flow steps in seen_contents

    func testAShownFlowStep_isKeptApartFromSeenContentAndSurveys() {
        let entity = ScreenSessionStateMachine(event: Event(type: .screen("Home")))

        entity.recordFlowStepSeen(401)
        entity.recordFlowStepSeen(401)

        XCTAssertEqual(entity.flowSeenContent, [401])
        XCTAssertTrue(entity.seenExperiences.isEmpty)
        XCTAssertTrue(entity.seenSurveys.isEmpty)
    }

    func testResetState_clearsShownFlowSteps() {
        let entity = ScreenSessionStateMachine(event: Event(type: .screen("Home")))
        entity.recordFlowStepSeen(401)

        entity.resetState()

        XCTAssertTrue(entity.flowSeenContent.isEmpty)
    }

    func testMergedSeenContents_deduplicatesContentAndStepIds() {
        XCTAssertEqual(mergedSeenContents(seenFlowIds: [10, 401], flowSeenContent: [401, 402]), [10, 401, 402])
    }

    func testMergedSeenContents_keepsEitherSideAlone() {
        XCTAssertEqual(mergedSeenContents(seenFlowIds: [10], flowSeenContent: []), [10])
        XCTAssertEqual(mergedSeenContents(seenFlowIds: [], flowSeenContent: [401]), [401])
        XCTAssertTrue(mergedSeenContents(seenFlowIds: [], flowSeenContent: []).isEmpty)
    }
}
