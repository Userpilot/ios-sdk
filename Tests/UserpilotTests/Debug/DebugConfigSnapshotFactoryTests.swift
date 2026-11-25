//
//  DebugConfigSnapshotFactoryTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class DebugConfigSnapshotFactoryTests: XCTestCase {

    func testSnapshot_includesSdkTokenSocketPushDeepLinkAndFontsSections() {
        let config = Userpilot.Config(token: "NX-DEBUG")
            .logging(enabled: true)
            .enableScreenAutoCapture()
        let storage = MockStorage()
        storage.socketURL = "wss://example.userpilot.io"
        storage.pushToken = "apns-token-1"
        let fonts = StubFontCatalog(appFonts: ["CustomSans"], systemFonts: ["Helvetica"])
        let factory = DebugConfigSnapshotFactory(
            config: config,
            storage: storage,
            fontCatalog: fonts,
            owner: nil
        )

        let snapshot = factory.create()
        let titles = snapshot.sections.map(\.title)
        let allKeys = snapshot.sections.flatMap { $0.rows.map(\.key) }

        XCTAssertEqual(titles, ["SDK", "Network", "Push", "Autocapture", "Deep link", "Fonts"])
        for key in [
            "Token",
            "SDK Version",
            "Socket URL",
            "APNS Token",
            "Default Scheme",
            "Host",
            "Example Experience Preview",
            "App Fonts",
            "System Fonts",
            "Enable Screen Auto Capture"
        ] {
            XCTAssertTrue(allKeys.contains(key), "missing key \(key)")
        }
        XCTAssertEqual(row(snapshot, "Token"), "NX-DEBUG")
        XCTAssertEqual(row(snapshot, "Socket URL"), "wss://example.userpilot.io")
        XCTAssertEqual(row(snapshot, "APNS Token"), "apns-token-1")
        XCTAssertEqual(row(snapshot, "Default Scheme"), "userpilot-nx-debug")
        XCTAssertEqual(row(snapshot, "Host"), "sdk")
        XCTAssertEqual(row(snapshot, "Enable Screen Auto Capture"), "true")
        XCTAssertEqual(row(snapshot, "Logging Enabled"), "true")
        XCTAssertEqual(row(snapshot, "App Fonts"), "CustomSans")
    }

    func testSnapshot_exposesNativeWrapperAndPlatformCaptureOptionsAndOwnership() {
        let config = Userpilot.Config(token: "NX-DEBUG")
        let window = UIWindow()
        config.attachedWindows.add(window)
        config.attachedViewControllerClasses = [UINavigationController.self]
        let factory = DebugConfigSnapshotFactory(
            config: config, storage: MockStorage(),
            fontCatalog: StubFontCatalog(appFonts: [], systemFonts: []), owner: nil
        )
        for enabled in [false, true] {
            config.enableScreenAutoCapture = enabled
            config.enableScreenTitleCapture = enabled
            config.enableInteractionAutoCapture = enabled
            config.enableInteractionTextCapture = enabled
            config.enableInteractionAccessibilityLabelCapture = enabled
            config.enableInteractionValueCapture = enabled
            config.enableSwiftUIButtonAutoCapture = enabled
            config.ignoreTapForTextInputEditingActions = enabled
            config.preferUIKitOverSwiftUIForNavigationBar = enabled
            config.additionalProperties = [
                "PluginType": "Flutter",
                "WrapperEnableScreenAutoCapture": enabled,
                "WrapperEnableInteractionAutoCapture": enabled
            ]
            let snapshot = factory.create()
            XCTAssertEqual(row(snapshot, "Is Wrapper SDK"), "true")
            for key in [
                "Enable Screen Auto Capture", "Enable Screen Title Capture", "Enable Interaction Auto Capture",
                "Enable Interaction Text Capture", "Enable Interaction Accessibility Label Capture",
                "Enable Interaction Value Capture", "Enable Wrapper Screen Auto Capture",
                "Enable Wrapper Interaction Auto Capture", "Enable SwiftUI Button Auto Capture",
                "Ignore Tap For Text Input Editing Actions", "Prefer UIKit Over SwiftUI For Navigation Bar"
            ] {
                XCTAssertEqual(row(snapshot, key), String(enabled), key)
            }
            XCTAssertEqual(row(snapshot, "Attached Window Count"), "1")
            XCTAssertEqual(row(snapshot, "Attached Windows"), "UIWindow")
            XCTAssertEqual(row(snapshot, "Attached View Controller Classes"), "UINavigationController")
        }
        withExtendedLifetime(window) {}
    }

    func testHumanize_convertsSnakeCaseToReadableLabel() {
        XCTAssertEqual(DebugPropertyLabel.humanize("sdk_version"), "SDK Version")
        XCTAssertEqual(DebugPropertyLabel.humanize("apns_token"), "APNS Token")
        XCTAssertEqual(DebugPropertyLabel.humanize("liquid_glass_sheets_and_dialogs"), "Liquid Glass Sheets and Dialogs")
        XCTAssertEqual(DebugPropertyLabel.humanize("token"), "Token")
    }

    private func row(_ snapshot: DebugSnapshot, _ key: String) -> String? {
        snapshot.sections.flatMap(\.rows).first(where: { $0.key == key })?.value
    }
}

private struct StubFontCatalog: DebugFontCataloging {
    let appFonts: [String]
    let systemFonts: [String]

    func appFontNames() -> [String] { appFonts }
    func systemFontNames() -> [String] { systemFonts }
}

// swiftlint:enable all
