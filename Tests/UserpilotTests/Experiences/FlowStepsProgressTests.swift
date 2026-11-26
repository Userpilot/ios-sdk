//
//  FlowStepsProgressTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the progress rule the Flow step renderers share: shown only for a real sequence, and its index
//  kept inside the drawn steps whatever `position` and `steps_count` the server sent.
//

import XCTest
@testable import Userpilot

final class FlowStepsProgressTests: XCTestCase {

    func testProgress_showsOnlyForMoreThanOneStep() {
        let shown = [3, 2, 1, 0, -2].map { FlowStepsProgress(stepsCount: $0, stepIndex: 0).isShown }

        XCTAssertEqual(shown, [true, true, false, false, false])
    }

    func testTheIndex_staysInsideTheSteps_whateverThePayloadSays() {
        let indexes = [1, 7, -1].map { FlowStepsProgress(stepsCount: 3, stepIndex: $0).index }

        XCTAssertEqual(indexes, [1, 2, 0])
        XCTAssertEqual(FlowStepsProgress(stepsCount: 0, stepIndex: 4).index, 0)
    }
}
