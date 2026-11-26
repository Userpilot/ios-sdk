//
//  FlowContentTooltipStepsTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class FlowContentTooltipStepsTests: XCTestCase {

    func testTooltipSteps_sortsByOrder() {
        let content = TooltipFixture.flowContent(stepCount: 3, orders: [2, 0, 1])
        XCTAssertEqual(content.tooltipSteps?.map(\.order), [0, 1, 2])
        // ids follow the array, so sorting by order reorders them 1, 2, 0.
        XCTAssertEqual(content.tooltipSteps?.map(\.id), [1, 2, 0])
    }

    // The stdlib sort is stable in practice, so an input that is already in
    // tie-break order would pass even without the `offset` comparison. These two
    // tests therefore put duplicates out of position: they guard the contract
    // (ties keep payload order), not current stdlib behaviour. Do not delete the
    // tie-break in `tooltipSteps` as redundant.
    func testTooltipSteps_duplicateOrdersKeepEveryStepInPayloadOrder() {
        // ids 0,1,2 carry orders 1,0,0: the order-0 pair (ids 1, 2) comes first
        // in payload order, then id 0.
        let content = TooltipFixture.flowContent(stepCount: 3, orders: [1, 0, 0])
        XCTAssertEqual(content.tooltipSteps?.count, 3)
        XCTAssertEqual(content.tooltipSteps?.map(\.id), [1, 2, 0])
    }

    func testTooltipSteps_severalDuplicateGroupsKeepPayloadOrderWithinEach() {
        // order 0: id 4; order 1: ids 1, 3, 5; order 2: ids 0, 2.
        let content = TooltipFixture.flowContent(stepCount: 6, orders: [2, 1, 2, 1, 0, 1])
        XCTAssertEqual(content.tooltipSteps?.map(\.id), [4, 1, 3, 5, 0, 2])
    }

    func testTooltipSteps_nonContiguousOrdersStillSort() {
        let content = TooltipFixture.flowContent(stepCount: 3, orders: [5, 2, 9])
        XCTAssertEqual(content.tooltipSteps?.map(\.order), [2, 5, 9])
    }

    func testTooltipSteps_refusesEmpty() {
        XCTAssertNil(TooltipFixture.flowContent(stepCount: 0).tooltipSteps)
    }

    func testTooltipSteps_refusesNonTooltipContent() {
        let carousel = FlowContent(
            id: 1, type: .carousel, steps: [TooltipFixture.step(id: 0, order: 0)],
            mobileTheme: ContentMobileTheme(id: 1, themeData: ExperienceTheme()),
            screens: [], screenType: .all, localeCode: "en")
        XCTAssertNil(carousel.tooltipSteps)
    }

    func testTooltipSteps_keepsASingleStep() {
        XCTAssertEqual(TooltipFixture.flowContent(stepCount: 1).tooltipSteps?.count, 1)
    }
}
