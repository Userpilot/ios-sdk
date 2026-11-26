//
//  CaptureUploadErrorTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pins the single response mapping: the HTTP status decides, `errors[0].details` splits 401 and
//  explains 422.
//

import XCTest
@testable import Userpilot

final class CaptureUploadErrorTests: XCTestCase {

    func testEveryResponseRowMapsToItsCategory() {
        XCTAssertEqual(map(401, "invalid_token"), .invalidToken)
        XCTAssertEqual(map(401, "session_expired"), .sessionExpired)
        XCTAssertEqual(map(401), .sessionExpired)
        XCTAssertEqual(map(413), .tooLarge)
        XCTAssertEqual(map(422, "The screenshot must be a PNG image."),
                       .rejected(statusCode: 422, reason: "The screenshot must be a PNG image."))
        XCTAssertEqual(map(400), .rejected(statusCode: 400))
        XCTAssertEqual(map(404), .rejected(statusCode: 404))
        XCTAssertEqual(map(418), .rejected(statusCode: 418))
        XCTAssertEqual(map(429), .throttled)
        XCTAssertEqual(map(500), .transient(statusCode: 500))
        XCTAssertEqual(map(503), .transient(statusCode: 503))
    }

    func testUnknown401DetailsIsSessionExpired() {
        XCTAssertEqual(map(401, "something_new"), .sessionExpired)
    }

    func testRequestTimeoutIsTransientAndForbiddenIsRejected() {
        XCTAssertEqual(map(408), .transient(statusCode: 408))
        XCTAssertEqual(map(403, "invalid_token"), .rejected(statusCode: 403))
    }

    func testDetailsAreReadOnlyFromTheFirstError() {
        let body = #"{"errors":[{"code":"unauthorized","details":"invalid_token"},{"details":"session_expired"}]}"#
        XCTAssertEqual(CaptureUploadError.details(in: Data(body.utf8)), "invalid_token")
        XCTAssertNil(CaptureUploadError.details(in: Data(#"{"errors":[]}"#.utf8)))
    }

    func testBodyWithoutErrorsOrNotJSONHasNoDetails() {
        XCTAssertNil(CaptureUploadError.details(in: Data(#"{"details":"invalid_token"}"#.utf8)))
        XCTAssertNil(CaptureUploadError.details(in: Data(#"{"reason":"invalid_token"}"#.utf8)))
        XCTAssertNil(CaptureUploadError.details(in: Data("<html>".utf8)))
        XCTAssertNil(CaptureUploadError.details(in: Data()))
        XCTAssertNil(CaptureUploadError.details(in: nil))
    }

    func testTransportResultMapping() throws {
        let url = try XCTUnwrap(URL(string: "https://appex.userpilot.io/upload"))
        let created = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)
        let unauthorized = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)
        let body = Data(#"{"errors":[{"details":"invalid_token"}]}"#.utf8)

        typealias Mapping = CaptureUploadError
        XCTAssertNoThrow(try Mapping.result(data: nil, response: created, error: nil).get())
        XCTAssertEqual(failure(of: Mapping.result(data: body, response: unauthorized, error: nil)), .invalidToken)
        XCTAssertEqual(failure(of: Mapping.result(data: nil, response: nil, error: URLError(.timedOut))),
                       .transient(statusCode: nil))
        XCTAssertEqual(failure(of: Mapping.result(data: nil, response: nil, error: URLError(.cancelled))),
                       .cancelled)
    }

    func testLogDescriptionCarriesOnlyCategoryStatusAndDetails() {
        XCTAssertEqual(CaptureUploadError.sessionExpired.logDescription(statusCode: 401, details: "session_expired"),
                       "sessionExpired (status 401, session_expired)")
        let server = CaptureUploadError.transient(statusCode: 503)
        XCTAssertEqual(server.logDescription(statusCode: 503, details: nil), "transient (status 503)")
        let offline = CaptureUploadError.transient(statusCode: nil)
        XCTAssertEqual(offline.logDescription(statusCode: nil, details: nil), "transient")
    }

    private func map(_ statusCode: Int, _ details: String? = nil) -> CaptureUploadError {
        CaptureUploadError.from(statusCode: statusCode, details: details)
    }

    private func failure(of result: Result<Void, CaptureUploadError>) -> CaptureUploadError? {
        guard case let .failure(error) = result else { return nil }
        return error
    }
}
