//
//  ThemeHandlerPersistenceTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies theme selection across storage and handler recreation, clearing and tenant boundaries.
//

import XCTest
@testable import Userpilot

final class ThemeHandlerPersistenceTests: XCTestCase {
    private var tokens: [String] = []

    override func tearDown() {
        for token in tokens {
            UserDefaults().removePersistentDomain(forName: Storage.suiteName(forToken: token))
        }
        tokens.removeAll()
        super.tearDown()
    }

    func testRecreatedHandler_fetchesPersistedTitle_forFirstFlowAndSurvey() throws {
        let token = makeToken()
        let handler = makeHandler(storage: makeStorage(token: token))
        handler.setAppTheme(name: "Brand Dark ")

        let storage = makeStorage(token: token)
        let restored = makeHandler(storage: storage)
        XCTAssertEqual(storage.appThemeName, "Brand Dark ")
        XCTAssertNil(restored.appTheme)
        XCTAssertEqual(restored.requiredThemeKey(for: try flow()), .title("Brand Dark "))
        let survey = try XCTUnwrap(
            MockContentFactory.makeSurveyContentPayload().toJSONString()?.toSurveyContent()?.surveyContent
        )
        XCTAssertEqual(restored.requiredThemeKey(for: .survey(content: survey)), .title("Brand Dark "))

        XCTAssertTrue(restored.saveAppTheme(reply(title: "Brand Dark "), title: "Brand Dark "))
        XCTAssertNotNil(restored.appTheme)
        XCTAssertNil(restored.requiredThemeKey(for: try flow()))
    }

    func testClearBeforeFirstContent_removesPersistedSelection_andIgnoresLateReply() throws {
        let token = makeToken()
        makeHandler(storage: makeStorage(token: token)).setAppTheme(name: "Dark")
        let restored = makeHandler(storage: makeStorage(token: token))

        restored.clearAppTheme()
        _ = restored.saveAppTheme(reply(title: "Dark"), title: "Dark")

        XCTAssertNil(restored.appTheme)
        XCTAssertEqual(restored.requiredThemeKey(for: try flow()), .id(1))
        let reopenedStorage = makeStorage(token: token)
        XCTAssertNil(reopenedStorage.appThemeName)
        XCTAssertEqual(makeHandler(storage: reopenedStorage).requiredThemeKey(for: try flow()), .id(1))
    }

    func testReplaceBeforeFirstContent_persistsLatestTitle_andRetriesAfterRestart() throws {
        let token = makeToken()
        makeHandler(storage: makeStorage(token: token)).setAppTheme(name: "Dark")
        let restored = makeHandler(storage: makeStorage(token: token))

        restored.setAppTheme(name: "Light")
        restored.resetAppThemes()
        XCTAssertEqual(restored.requiredThemeKey(for: try flow()), .title("Light"))
        restored.markAppThemeUnavailable("Light")
        XCTAssertEqual(restored.requiredThemeKey(for: try flow()), .id(1))

        let reopenedStorage = makeStorage(token: token)
        XCTAssertEqual(reopenedStorage.appThemeName, "Light")
        XCTAssertEqual(makeHandler(storage: reopenedStorage).requiredThemeKey(for: try flow()), .title("Light"))
    }

    func testSelection_survivesIdentityCleanup_andIsIsolatedByToken() throws {
        let token = makeToken()
        let storage = makeStorage(token: token)
        XCTAssertNil(storage.appThemeName)
        makeHandler(storage: storage).setAppTheme(name: "Dark")

        let otherToken = makeToken()
        let otherStorage = makeStorage(token: otherToken)
        XCTAssertNil(otherStorage.appThemeName)
        makeHandler(storage: otherStorage).setAppTheme(name: "Light")
        storage.clean()

        let restored = makeHandler(storage: makeStorage(token: token))
        XCTAssertEqual(restored.requiredThemeKey(for: try flow()), .title("Dark"))
        XCTAssertEqual(makeStorage(token: otherToken).appThemeName, "Light")
    }

    private func makeToken() -> String {
        let token = UUID().uuidString
        tokens.append(token)
        return token
    }

    private func makeStorage(token: String) -> Storage {
        let container = DIContainer()
        container.register(Userpilot.Config.self, value: Userpilot.Config(token: token).defaultInstance(false))
        return Storage(container: container)
    }

    private func makeHandler(storage: DataStoring) -> ThemeHandler {
        let container = DIContainer()
        container.register(DataStoring.self, value: storage)
        return ThemeHandler(container: container)
    }

    private func flow() throws -> ExperienceContent {
        let content = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload().toJSONString()?.toFlowContent()?.flowContent
        )
        return .flow(content: content)
    }

    private func reply(title: String) -> ThemeContent {
        ThemeContent(id: 9, title: title, themeData: ThemeData(carousel: nil, slideOut: nil, survey: nil))
    }
}
