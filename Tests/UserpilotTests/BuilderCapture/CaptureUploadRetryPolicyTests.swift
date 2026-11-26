//
//  CaptureUploadRetryPolicyTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Plays failure sequences through the pure retry policy, the way the coordinator's upload run does.
//

import XCTest
@testable import Userpilot

final class CaptureUploadRetryPolicyTests: XCTestCase {
    private let server = CaptureUploadError.transient(statusCode: 503)
    private let offline = CaptureUploadError.transient(statusCode: nil)
    private let throttled = CaptureUploadError.throttled

    /// The waits between attempts until the policy ends the run.
    private func waits(_ failures: [CaptureUploadError]) -> [TimeInterval] {
        var waits: [TimeInterval] = []
        var throttledAlready = false
        for (index, error) in failures.enumerated() {
            guard let wait = CaptureUploadRetryPolicy.nextDelay(
                after: error, attempt: index + 1, throttledAlready: throttledAlready) else { return waits }
            if error == throttled { throttledAlready = true }
            waits.append(wait)
        }
        return waits
    }

    func testTransientFailuresWaitTwoFourAndEightSecondsAndTheFourthEndsTheRun() {
        XCTAssertEqual(waits(Array(repeating: server, count: 4)), [2, 4, 8])
        XCTAssertEqual(waits(Array(repeating: offline, count: 4)).count, 3)
    }

    func testTheFirstThrottleWaitsTenSecondsAndASecondOneEndsTheRun() {
        XCTAssertEqual(waits([throttled]), [10])
        XCTAssertEqual(waits([throttled, throttled, server]), [10])
    }

    func testAMixedRunStillStopsAtFourAttempts() {
        XCTAssertEqual(waits([server, throttled, server, server]), [2, 10, 8])
    }

    func testErrorsThatSendingAgainCannotFixEndTheRunAtOnce() {
        let failures: [CaptureUploadError] = [
            .invalidToken, .sessionExpired, .tooLarge, .rejected(statusCode: 422), .cancelled
        ]
        for failure in failures {
            XCTAssertNil(CaptureUploadRetryPolicy.nextDelay(after: failure, attempt: 1, throttledAlready: false),
                         "\(failure)")
        }
    }
}
