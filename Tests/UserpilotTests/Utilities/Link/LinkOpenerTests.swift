//
//  LinkOpenerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import SafariServices
import XCTest

@testable import Userpilot

class LinkOpenerTests: XCTestCase {

    var linkOpener: LinkOpener!
    var mockUserpilot: MockUserpilot!
    var mockLinkOpener: MockLinkOpener!
    var mockNavigationDelegate: MockNavigationDelegate!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        mockUserpilot = MockUserpilot(config: config)

        // Create a real LinkOpener instance for testing (not using the mock from container)
        linkOpener = LinkOpener(container: mockUserpilot.container)

        mockLinkOpener = MockLinkOpener()
        linkOpener.urlOpener = mockLinkOpener

        mockNavigationDelegate = MockNavigationDelegate()
    }

    override func tearDown() {
        linkOpener = nil
        mockUserpilot = nil
        mockLinkOpener = nil
        mockNavigationDelegate = nil
        super.tearDown()
    }

    // MARK: - Navigation Delegate Tests

    func testHandleURL_withNavigationDelegate_usesDelegate() {
        // Arrange
        mockUserpilot.navigationDelegate = mockNavigationDelegate
        let url = URL(string: "https://example.com")!
        var capturedURL: URL?
        mockNavigationDelegate.onNavigate = { url in
            capturedURL = url
        }

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertEqual(capturedURL, url)
        XCTAssertFalse(mockLinkOpener.openCalled)
        XCTAssertNil(mockLinkOpener.topViewControllerCalled)
    }

    func testHandleURL_withNavigationDelegate_doesNotCallURLOpener() {
        // Arrange
        mockUserpilot.navigationDelegate = mockNavigationDelegate
        let url = URL(string: "myapp://deeplink")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertFalse(mockLinkOpener.openCalled)
    }

    // MARK: - Web Link Tests (HTTP/HTTPS)

    func testHandleURL_httpLink_withInAppBrowser_opensInSafariVC() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = true
        let url = URL(string: "http://example.com")!
        let mockVC = UIViewController()
        mockLinkOpener.mockTopViewController = mockVC

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.topViewControllerCalled == true)
        XCTAssertFalse(mockLinkOpener.openCalled)
    }

    func testHandleURL_httpsLink_withInAppBrowser_opensInSafariVC() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = true
        let url = URL(string: "https://example.com")!
        let mockVC = UIViewController()
        mockLinkOpener.mockTopViewController = mockVC

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.topViewControllerCalled == true)
        XCTAssertFalse(mockLinkOpener.openCalled)
    }

    func testHandleURL_httpLink_withoutInAppBrowser_opensExternally() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = false
        let url = URL(string: "http://example.com")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    func testHandleURL_httpsLink_withoutInAppBrowser_opensExternally() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = false
        let url = URL(string: "https://example.com")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    func testHandleURL_inAppBrowser_noTopViewController_fallsBackToExternal() {
        // Arrange
        mockUserpilot.config.useInAppBrowser = true
        let url = URL(string: "https://example.com")!
        mockLinkOpener.mockTopViewController = nil  // No top VC available

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.topViewControllerCalled == true)
        XCTAssertTrue(mockLinkOpener.openCalled)  // Falls back to external
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    // MARK: - Scheme Link Tests

    func testHandleURL_mailtoScheme_opensExternally() {
        // Arrange
        let url = URL(string: "mailto:test@example.com")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    func testHandleURL_telScheme_opensExternally() {
        // Arrange
        let url = URL(string: "tel:+1234567890")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    func testHandleURL_customScheme_opensExternally() {
        // Arrange
        let url = URL(string: "myapp://action/something")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    func testHandleURL_smsScheme_opensExternally() {
        // Arrange
        let url = URL(string: "sms:+1234567890")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    // MARK: - Edge Cases

    func testHandleURL_uppercaseHTTP_treatedAsWebLink() {
        // Arrange
        let url = URL(string: "HTTP://EXAMPLE.COM")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
    }

    func testHandleURL_mixedCaseHTTPS_treatedAsWebLink() {
        // Arrange
        let url = URL(string: "HtTpS://example.com")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
    }

    func testHandleURL_urlWithQueryParameters_handledCorrectly() {
        // Arrange
        let url = URL(string: "https://example.com/path?param1=value1&param2=value2")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }

    func testHandleURL_urlWithFragment_handledCorrectly() {
        // Arrange
        let url = URL(string: "https://example.com/page#section")!

        // Act
        linkOpener.handleURL(url)

        // Assert
        XCTAssertTrue(mockLinkOpener.openCalled)
        XCTAssertEqual(mockLinkOpener.lastOpenedURL, url)
    }
}
