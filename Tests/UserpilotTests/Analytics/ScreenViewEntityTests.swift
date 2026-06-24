//
//  ScreenViewEntityTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class ScreenViewEntityTests: XCTestCase {

    func testInitializationStoresEventAndInitialSeenSets() {
        let event = Event(type: .screen("Home"))
        let entity = ScreenViewEntity(event: event, seenExperiences: [1, 2], seenSurveys: [3])

        XCTAssertEqual(entity.event.screenTitle, "Home")
        XCTAssertEqual(entity.seenExperiences, [1, 2])
        XCTAssertEqual(entity.seenSurveys, [3])
    }

    func testUpdateSeenExperiencesDeduplicatesIds() {
        let entity = ScreenViewEntity(event: Event(type: .screen("Home")))

        entity.updateSeenFlowExperiences(10)
        entity.updateSeenFlowExperiences(10)
        entity.updateSeenSurveyExperiences(20)
        entity.updateSeenSurveyExperiences(20)

        XCTAssertEqual(entity.seenExperiences, [10])
        XCTAssertEqual(entity.seenSurveys, [20])
    }

    func testResetStateClearsSeenSetsWithoutReplacingEvent() {
        let entity = ScreenViewEntity(
            event: Event(type: .screen("Home")),
            seenExperiences: [1],
            seenSurveys: [2]
        )

        entity.resetState()

        XCTAssertTrue(entity.seenExperiences.isEmpty)
        XCTAssertTrue(entity.seenSurveys.isEmpty)
        XCTAssertEqual(entity.event.screenTitle, "Home")
    }
}
