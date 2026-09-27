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
        // In production `Userpilot.init` opens routing; these tests build the opener directly, so
        // they must do it themselves or every link would sit in the pending slot. The holding
        // behaviour itself is covered by the routing-gate tests at the bottom of this file.
        linkOpener.processPendingDeepLink()
    }

    /// Runs `act`, then waits out the main-queue hop `LinkOpener.route` delivers through.
    ///
    /// The barrier is enqueued after that hop, and the main queue is FIFO, so when it fires the
    /// delivery has already happened — deterministic, with no sleeps.
    private func routing(_ act: () -> Void) {
        act()
        let delivered = expectation(description: "deep link routed")
        DispatchQueue.main.async { delivered.fulfill() }
        wait(for: [delivered], timeout: 1.0)
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
        routing { linkOpener.handleURL(url) }

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
        routing { linkOpener.handleURL(url) }

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
        routing { linkOpener.handleURL(url) }

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
        routing { linkOpener.handleURL(url) }

        // Assert
        XCTAssertTrue(urlOpener.topViewControllerCalled)
        XCTAssertFalse(urlOpener.openCalled)
    }

    func testHandleURL_httpLink_withoutInAppBrowser_opensExternally() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = false
        let url = URL(string: "http://example.com")!

        // Act
        routing { linkOpener.handleURL(url) }

        // Assert
        XCTAssertTrue(urlOpener.openCalled)
        XCTAssertEqual(urlOpener.lastOpenedURL, url)
    }

    func testHandleURL_httpsLink_withoutInAppBrowser_opensExternally() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = false
        let url = URL(string: "https://example.com")!

        // Act
        routing { linkOpener.handleURL(url) }

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
        routing { linkOpener.handleURL(url) }

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
        routing { linkOpener.handleURL(url) }

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

        routing { linkOpener.handleURL(url) }

        XCTAssertTrue(urlOpener.openCalled)
        XCTAssertEqual(urlOpener.lastOpenedURL, url)
    }

    // MARK: - Routing Gate Tests

    /// A fresh opener with routing still closed, as it is while the SDK is starting up.
    private func unopenedLinkOpener() -> LinkOpener {
        let opener = LinkOpener(container: mockUserpilot.container)
        opener.urlOpener = urlOpener
        return opener
    }

    func testHandleURL_beforeRoutingOpens_holdsTheLink() {
        // Arrange
        mockUserpilot.navigationDelegate = navigationDelegate
        var navigated = false
        navigationDelegate.onNavigate = { _ in navigated = true }
        let url = URL(string: "myapp://deeplink")!

        // Act
        routing { unopenedLinkOpener().handleURL(url) }

        // Assert — nothing is delivered by either route while the host may not be ready.
        XCTAssertFalse(navigated)
        XCTAssertFalse(urlOpener.openCalled)
    }

    func testProcessPendingDeepLink_deliversTheHeldLink() {
        // Arrange
        mockUserpilot.navigationDelegate = navigationDelegate
        var capturedURL: URL?
        navigationDelegate.onNavigate = { capturedURL = $0 }
        let url = URL(string: "myapp://deeplink")!
        let opener = unopenedLinkOpener()
        opener.handleURL(url)

        // Act
        routing { opener.processPendingDeepLink() }

        // Assert
        XCTAssertEqual(capturedURL, url)
    }

    func testProcessPendingDeepLink_deliversOnlyTheNewestHeldLink() {
        // Arrange
        mockUserpilot.navigationDelegate = navigationDelegate
        var captured: [URL] = []
        navigationDelegate.onNavigate = { captured.append($0) }
        let older = URL(string: "myapp://older")!
        let newer = URL(string: "myapp://newer")!
        let opener = unopenedLinkOpener()
        opener.handleURL(older)
        opener.handleURL(newer)

        // Act
        routing { opener.processPendingDeepLink() }

        // Assert — one slot: a newer tap supersedes an older, still-undelivered one.
        XCTAssertEqual(captured, [newer])
    }

    func testProcessPendingDeepLink_isIdempotent() {
        // Arrange
        mockUserpilot.navigationDelegate = navigationDelegate
        var captured: [URL] = []
        navigationDelegate.onNavigate = { captured.append($0) }
        let url = URL(string: "myapp://deeplink")!
        let opener = unopenedLinkOpener()
        opener.handleURL(url)

        // Act — the init backstop opens routing, then the host assigns a delegate and opens again.
        routing {
            opener.processPendingDeepLink()
            opener.processPendingDeepLink()
        }

        // Assert — the tap is delivered once, not once per trigger.
        XCTAssertEqual(captured, [url])
    }

    func testHandleURL_afterRoutingOpens_deliversImmediately() {
        // Arrange
        mockUserpilot.navigationDelegate = navigationDelegate
        var captured: [URL] = []
        navigationDelegate.onNavigate = { captured.append($0) }
        let first = URL(string: "myapp://first")!
        let second = URL(string: "myapp://second")!
        let opener = unopenedLinkOpener()
        opener.processPendingDeepLink()

        // Act — experience CTAs, which can only ever fire after the host is up.
        routing {
            opener.handleURL(first)
            opener.handleURL(second)
        }

        // Assert — no holding, and no single slot that could drop the second tap.
        XCTAssertEqual(captured, [first, second])
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
