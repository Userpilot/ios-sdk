//
//  UserpilotRemoteSourceUploadTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers the three-part capture upload request, its 30 s session, response mapping and safe logging.
//

import XCTest
@testable import Userpilot

final class UserpilotRemoteSourceUploadTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var logger: MockLogger!
    private var remoteSource: UserpilotRemoteSource!
    private let link = CaptureLink.from(
        captureID: "1b6c920c-dd09-4a4c-83c8-7130cb5fd5a6",
        platform: "ios",
        token: "secret-builder-token"
    )!
    private let uploadURL = URL(string: Environment.getCaptureUploadUrl())!
    private let document = Data(#"{"capture_id":"1b6c920c-dd09-4a4c-83c8-7130cb5fd5a6","schema_version":1}"#.utf8)
    private lazy var upload = CaptureUpload(
        captureID: link.captureID, screenshot: Data([0x89, 0x50, 0x4E, 0x47]), document: document
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        URLProtocolStub.reset()
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        logger = MockLogger()
        config.logger = logger
        userpilot = MockUserpilot.make(config: config)
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [URLProtocolStub.self]
        remoteSource = UserpilotRemoteSource(
            container: userpilot.container, session: URLSession(configuration: sessionConfig))
    }

    override func tearDownWithError() throws {
        URLProtocolStub.reset()
        userpilot = nil
        logger = nil
        remoteSource = nil
        try super.tearDownWithError()
    }

    func testPostsToTheGivenURLWithBearerToken() throws {
        stub(status: 201)

        XCTAssertNoThrow(try send().get(), "Any 2xx with an empty body is a saved capture")

        let sent = try XCTUnwrap(URLProtocolStub.requests.last)
        XCTAssertEqual(sent.request.httpMethod, "POST")
        XCTAssertEqual(sent.request.url, uploadURL, "The upload URL is used exactly as given")
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-builder-token")
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertFalse(sent.request.url?.absoluteString.contains("secret-builder-token") ?? true)
    }

    func testBodyHasExactlyTheThreeParts() throws {
        stub(status: 201)
        _ = send()

        let sent = try XCTUnwrap(URLProtocolStub.requests.last)
        let contentType = try XCTUnwrap(sent.request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary=Userpilot-"))
        let boundary = try XCTUnwrap(contentType.components(separatedBy: "boundary=").last)
        let parts = try multipartParts(of: sent.body, boundary: boundary)

        XCTAssertEqual(parts.map(\.headers), [
            "Content-Disposition: form-data; name=\"capture_id\"",
            "Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.png\"\r\n"
                + "Content-Type: image/png",
            "Content-Disposition: form-data; name=\"document\"; filename=\"capture.json\"\r\n"
                + "Content-Type: application/json"
        ])
        XCTAssertEqual(String(data: parts[0].content, encoding: .utf8), link.captureID)
        XCTAssertEqual(parts[1].content, upload.screenshot)
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: parts[2].content) as? NSDictionary)
        XCTAssertEqual(decoded, try XCTUnwrap(JSONSerialization.jsonObject(with: document) as? NSDictionary))
    }

    func testStatusAndDetailsMapToSafeCategories() {
        stub(status: 401, body: #"{"errors":[{"details":"invalid_token","message":"secret-builder-token"}]}"#)
        XCTAssertEqual(failure(of: send()), .invalidToken)

        stub(status: 401)
        XCTAssertEqual(failure(of: send()), .sessionExpired)

        stub(status: 503)
        XCTAssertEqual(failure(of: send()), .transient(statusCode: 503))

        stub(status: 429)
        XCTAssertEqual(failure(of: send()), .throttled)
    }

    func testNetworkFailureIsTransientWithoutStatus() {
        URLProtocolStub.response = (nil, nil, URLError(.notConnectedToInternet))
        XCTAssertEqual(failure(of: send()), .transient(statusCode: nil))
    }

    func testLogsCarryOnlyCategoryStatusAndDetails() {
        stub(status: 422, body: #"{"errors":[{"details":"invalid_document","message":"secret-builder-token"}]}"#)
        _ = send()
        stub(status: 200)
        _ = send()

        let logs = logger.renderedLines
        XCTAssertTrue(logs.contains("📸 Capture upload failed: rejected (status 422, invalid_document)"), "\(logs)")
        XCTAssertTrue(logs.contains("📸 Capture uploaded: saved (status 200)"), "\(logs)")
        XCTAssertFalse(logs.contains { $0.contains("secret-builder-token") })
        XCTAssertFalse(logs.contains { $0.contains("userpilot.io") })
    }

    // MARK: - Helpers

    private func stub(status: Int, body: String = "") {
        URLProtocolStub.response = (
            Data(body.utf8),
            HTTPURLResponse(url: uploadURL, statusCode: status, httpVersion: nil, headerFields: nil),
            nil
        )
    }

    private func send() -> Result<Void, CaptureUploadError> {
        let finished = expectation(description: "upload finished")
        var result: Result<Void, CaptureUploadError> = .failure(.cancelled)
        remoteSource.uploadCapture(upload, token: link.token, url: uploadURL) {
            result = $0
            finished.fulfill()
        }
        wait(for: [finished], timeout: 2)
        return result
    }

    private func failure(of result: Result<Void, CaptureUploadError>) -> CaptureUploadError? {
        guard case let .failure(error) = result else { return nil }
        return error
    }

    private struct Part {
        let headers: String
        let content: Data
    }

    /// Splits a multipart body on its boundary. Latin-1 maps every byte, so binary parts survive the round trip.
    private func multipartParts(of body: Data, boundary: String) throws -> [Part] {
        let text = try XCTUnwrap(String(data: body, encoding: .isoLatin1))
        XCTAssertTrue(text.hasSuffix("--\(boundary)--\r\n"))
        let sections = text.components(separatedBy: "--\(boundary)")
        // Leading empty text, the parts, then the closing "--\r\n".
        return try sections.dropFirst().dropLast().map { section in
            // Drops the CRLF after this boundary and the one before the next; Swift counts "\r\n" as one Character.
            XCTAssertTrue(section.hasPrefix("\r\n") && section.hasSuffix("\r\n"))
            let trimmed = String(section.dropFirst().dropLast())
            let pieces = trimmed.components(separatedBy: "\r\n\r\n")
            let headers = try XCTUnwrap(pieces.first)
            let content = pieces.dropFirst().joined(separator: "\r\n\r\n")
            return Part(headers: headers, content: try XCTUnwrap(content.data(using: .isoLatin1)))
        }
    }
}
