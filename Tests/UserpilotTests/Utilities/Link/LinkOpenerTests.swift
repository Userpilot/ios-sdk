//
//  LinkOpenerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all
final class LinkOpenerTests: XCTestCase {

    private var linkOpener: LinkOpener!
    private var mockUserpilot: MockUserpilot!
    private var urlOpener: MockURLOpener!
    private var navigationDelegate: MockNavigationDelegate!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        mockUserpilot = MockUserpilot(config: config)
        linkOpener = LinkOpener(container: mockUserpilot.container)
        urlOpener = MockURLOpener()
        linkOpener.urlOpener = urlOpener
        navigationDelegate = MockNavigationDelegate()
    }

    override func tearDown() {
        linkOpener = nil
        mockUserpilot = nil
        urlOpener = nil
        navigationDelegate = nil
        super.tearDown()
    }

    // MARK: - Navigation Delegate Tests

    func testHandleURL_withNavigationDelegate_usesDelegate() {
        // Arrange
        mockUserpilot.navigationDelegate = navigationDelegate
        let url = URL(string: "https://example.com")!
        var capturedURL: URL?
        navigationDelegate.onNavigate = { url in
            capturedURL = url
        }

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertEqual(capturedURL, url)
        XCTAssertFalse(urlOpener.openCalled)
        XCTAssertFalse(urlOpener.topViewControllerCalled)
    }

    func testHandleURL_withNavigationDelegate_doesNotCallURLOpener() {
        // Arrange
        mockUserpilot.navigationDelegate = navigationDelegate
        let url = URL(string: "myapp://deeplink")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertFalse(urlOpener.openCalled)
    }

    // MARK: - Web Link Tests

    func testHandleURL_httpLink_withInAppBrowser_opensInSafariVC() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = true
        let url = URL(string: "http://example.com")!
        urlOpener.topViewControllerToReturn = UIViewController()

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(urlOpener.topViewControllerCalled)
        XCTAssertFalse(urlOpener.openCalled)
    }

    func testHandleURL_httpsLink_withInAppBrowser_opensInSafariVC() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = true
        let url = URL(string: "https://example.com")!
        urlOpener.topViewControllerToReturn = UIViewController()

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(urlOpener.topViewControllerCalled)
        XCTAssertFalse(urlOpener.openCalled)
    }

    func testHandleURL_httpLink_withoutInAppBrowser_opensExternally() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = false
        let url = URL(string: "http://example.com")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(urlOpener.openCalled)
        XCTAssertEqual(urlOpener.lastOpenedURL, url)
    }

    func testHandleURL_httpsLink_withoutInAppBrowser_opensExternally() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = false
        let url = URL(string: "https://example.com")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(urlOpener.openCalled)
        XCTAssertEqual(urlOpener.lastOpenedURL, url)
    }

    func testHandleURL_inAppBrowserWithoutTopViewController_fallsBackToExternal() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = true
        let url = URL(string: "https://example.com")!
        urlOpener.topViewControllerToReturn = nil

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(urlOpener.topViewControllerCalled)
        XCTAssertTrue(urlOpener.openCalled)
        XCTAssertEqual(urlOpener.lastOpenedURL, url)
    }

    // MARK: - Scheme Link Tests

    func testHandleURL_mailtoScheme_opensExternally() {
        assertOpensExternally("mailto:test@example.com")
    }

    func testHandleURL_telScheme_opensExternally() {
        assertOpensExternally("tel:+1234567890")
    }

    func testHandleURL_smsScheme_opensExternally() {
        assertOpensExternally("sms:+1234567890")
    }

    func testHandleURL_customScheme_opensExternally() {
        assertOpensExternally("myapp://action/something")
    }

    // MARK: - Edge Cases

    func testHandleURL_uppercaseHTTP_treatedAsWebLink() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = true
        urlOpener.topViewControllerToReturn = UIViewController()
        let url = URL(string: "HTTP://EXAMPLE.COM")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(urlOpener.topViewControllerCalled)
        XCTAssertFalse(urlOpener.openCalled)
    }

    func testHandleURL_urlWithQueryParameters_handledCorrectly() {
        assertOpensExternally("https://example.com/path?param1=value1&param2=value2")
    }

    func testHandleURL_urlWithFragment_handledCorrectly() {
        assertOpensExternally("https://example.com/page#section")
    }

    private func assertOpensExternally(_ urlString: String) {
        let url = URL(string: urlString)!
        mockUserpilot.config.useInAppBrowser = false

        linkOpener.handleURL(url)

        XCTAssertTrue(urlOpener.openCalled)
        XCTAssertEqual(urlOpener.lastOpenedURL, url)
    }
}

private final class MockURLOpener: TopControllerGetting, URLOpening {
    var hasActiveWindowScenes = true
    var topViewControllerCalled = false
    var topViewControllerToReturn: UIViewController?
    var openCalled = false
    var lastOpenedURL: URL?

    func topViewController() -> UIViewController? {
        topViewControllerCalled = true
        return topViewControllerToReturn
    }

    func open(_ url: URL) {
        openCalled = true
        lastOpenedURL = url
    }
}
// swiftlint:enable all
