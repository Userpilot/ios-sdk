//
//  FlowContentStepsCountDecodingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The position rule's bound comes only from `steps_count`: a Flow without one accepts any position from 1.
//

import XCTest
@testable import Userpilot

extension FlowContentDecodingTests {

    func testWithoutStepsCount_anyPositionFromOneDecodes() throws {
        var payload = MockContentFactory.makeFlowContractPayload()
        var flow = try XCTUnwrap(payload["mobile_contents"] as? [String: Any])
        var steps = try XCTUnwrap(flow["steps"] as? [[String: Any]])
        steps[2]["position"] = 9
        flow["steps"] = steps
        flow["steps_count"] = nil
        payload["mobile_contents"] = flow
        let json = try XCTUnwrap(payload.toJSONString())

        let decoded = try XCTUnwrap(json.experienceCandidates().first?.asFlowContent(), "Flow did not decode")

        XCTAssertEqual(decoded.steps.map(\.position), [1, 2, 9])
    }
}
