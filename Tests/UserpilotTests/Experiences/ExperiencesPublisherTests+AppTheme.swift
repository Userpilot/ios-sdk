//
//  ExperiencesPublisherTests+AppTheme.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies that a selected app theme is fetched by title and falls back to the content's own theme.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {

    func testAppThemeIsRequestedByTitleBeforeDisplay() throws {
        var savedTitles: [String] = []
        userpilot.themeHandler.onRequiredThemeKey = { _ in savedTitles.isEmpty ? .title("Dark") : nil }
        userpilot.themeHandler.onSaveAppTheme = { theme, title in
            savedTitles.append(title)
            return theme.title == title
        }
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        let request = try XCTUnwrap(userpilot.analyticsPublisher.requests.last)
        let event = try XCTUnwrap(request.event as? ThemeContentEvent)
        XCTAssertEqual(event.key, .title("Dark"))
        XCTAssertEqual(event.eventPayload["theme_title"] as? String, "Dark")
        XCTAssertNil(event.eventPayload["theme_id"])
        XCTAssertFalse(displayDelay.hasAction)

        request.completion?(Message(payload: ["id": 9, "title": "Dark", "theme_data": [:]]), true)
        publisher.mockWaitForQueue()

        XCTAssertEqual(savedTitles, ["Dark"])
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testEmptyAppThemeReplyFallsBackToContentTheme() throws {
        let themes = userpilot.themeHandler
        themes.onGetThemeById = { _ in nil }
        themes.onRequiredThemeKey = { [weak themes] _ in
            themes?.unavailableAppThemes.isEmpty == false ? .id(1) : .title("Dark")
        }
        receiveScreen(MockContentFactory.makeFlowContentPayload())

        try XCTUnwrap(userpilot.analyticsPublisher.requests.last).completion?(Message(payload: [:]), true)
        publisher.mockWaitForQueue()

        XCTAssertEqual(themes.unavailableAppThemes, ["Dark"])
        XCTAssertFalse(displayDelay.hasAction)
        let fallback = try XCTUnwrap(userpilot.analyticsPublisher.requests.last)
        XCTAssertEqual((fallback.event as? ThemeContentEvent)?.key, .id(1))

        fallback.completion?(Message(payload: ["id": 1, "theme_data": [:]]), true)
        publisher.mockWaitForQueue()
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testFailedAppThemeRequestShowsContentWithItsCachedTheme() throws {
        let themes = userpilot.themeHandler
        themes.onRequiredThemeKey = { [weak themes] _ in
            themes?.unavailableAppThemes.isEmpty == false ? nil : .title("Dark")
        }
        receiveScreen(MockContentFactory.makeFlowContentPayload())

        try XCTUnwrap(userpilot.analyticsPublisher.requests.last).completion?(Message(), false)
        publisher.mockWaitForQueue()

        XCTAssertEqual(themes.unavailableAppThemes, ["Dark"])
        XCTAssertEqual(userpilot.analyticsPublisher.requests.count, 1)
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testSocketOpenResetsAppThemes() {
        publisher.onSocketOpened()

        XCTAssertEqual(userpilot.themeHandler.resetAppThemesCount, 1)
    }
}
