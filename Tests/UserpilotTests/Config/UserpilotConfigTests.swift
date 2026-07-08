//
//  UserpilotConfigTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class UserpilotConfigTests: XCTestCase {

    func testDefaults() {
        let config = Userpilot.Config(token: "TOKEN")

        XCTAssertEqual(config.token, "TOKEN")
        XCTAssertTrue(config.additionalProperties.isEmpty)
        XCTAssertFalse(config.isWrapperSDK)
        XCTAssertFalse(config.isWrapperScreenAutoCaptureEnabled)
        XCTAssertFalse(config.isWrapperInteractionAutoCaptureEnabled)
        XCTAssertNil(config.appFramework)
        XCTAssertFalse(config.disableRequestPushPermission)
        XCTAssertFalse(config.useInAppBrowser)
        XCTAssertFalse(config.enableScreenAutoCapture)
        XCTAssertTrue(config.enableScreenTitleCapture)
        XCTAssertFalse(config.enableInteractionAutoCapture)
        XCTAssertTrue(config.enableInteractionTextCapture)
        XCTAssertTrue(config.enableInteractionAccessibilityLabelCapture)
        XCTAssertFalse(config.enableInteractionValueCapture)
        XCTAssertTrue(config.ignoreTapForTextInputEditingActions)
        XCTAssertTrue(config.preferUIKitOverSwiftUIForNavigationBar)
        XCTAssertTrue(config.isDefault)
        XCTAssertFalse(config.allowReceiveEventsFromExternalSource)
        XCTAssertTrue(config.attachedBundleIdentifiers.isEmpty)
        XCTAssertEqual(config.attachedWindows.allObjects.count, 0)
        XCTAssertTrue(config.attachedViewControllerClasses.isEmpty)
    }

    func testChainableTogglesMutateConfigAndReturnSelf() {
        let config = Userpilot.Config(token: "TOKEN")

        let returned = config
            .appFramework(.SwiftUI)
            .disableRequestPushNotificationsPermission()
            .enableUseInAppBrowser()
            .enableScreenAutoCapture()
            .enableScreenTitleCapture(false)
            .enableInteractionAutoCapture()
            .enableInteractionTextCapture(false)
            .enableInteractionAccessibilityLabelCapture(false)
            .enableInteractionValueCapture()
            .ignoreTapForTextInputEditingActions(false)
            .preferUIKitOverSwiftUIForNavigationBar(false)
            .defaultInstance(false)
            .allowReceiveEventsFromExternalSource()

        XCTAssertTrue(returned === config)
        XCTAssertEqual(config.appFramework, .SwiftUI)
        XCTAssertTrue(config.disableRequestPushPermission)
        XCTAssertTrue(config.useInAppBrowser)
        XCTAssertTrue(config.enableScreenAutoCapture)
        XCTAssertFalse(config.enableScreenTitleCapture)
        XCTAssertTrue(config.enableInteractionAutoCapture)
        XCTAssertFalse(config.enableInteractionTextCapture)
        XCTAssertFalse(config.enableInteractionAccessibilityLabelCapture)
        XCTAssertTrue(config.enableInteractionValueCapture)
        XCTAssertFalse(config.ignoreTapForTextInputEditingActions)
        XCTAssertFalse(config.preferUIKitOverSwiftUIForNavigationBar)
        XCTAssertFalse(config.isDefault)
        XCTAssertTrue(config.allowReceiveEventsFromExternalSource)
    }

    func testAttachScopesAreAdditiveAndDeduplicatedWhereApplicable() {
        let config = Userpilot.Config(token: "TOKEN")
        let windowA = UIWindow()
        let windowB = UIWindow()

        config
            .attach(bundles: [Bundle.main, Bundle.main])
            .attach(windows: [windowA])
            .attach(windows: [windowB])
            .attach(viewControllerClasses: [UIViewController.self])
            .attach(viewControllerClasses: [UINavigationController.self])

        XCTAssertEqual(config.attachedBundleIdentifiers, [Bundle.main.bundleIdentifier].compactMap { $0 }.asSet())
        XCTAssertTrue(config.attachedWindows.contains(windowA))
        XCTAssertTrue(config.attachedWindows.contains(windowB))
        XCTAssertEqual(config.attachedViewControllerClasses.count, 2)
        XCTAssertTrue(config.attachedViewControllerClasses.contains { $0 === UIViewController.self })
        XCTAssertTrue(config.attachedViewControllerClasses.contains { $0 === UINavigationController.self })
    }

    func testWrapperAdditionalPropertiesHelpersReadPluginAndAutocaptureFlags() {
        let config = Userpilot.Config(token: "TOKEN")
            .additionalProperties([
                WrapperSDKConstants.pluginType: WrapperSDKConstants.pluginTypeFlutter,
                WrapperSDKConstants.enableScreenAutoCapture: false,
                WrapperSDKConstants.enableInteractionAutoCapture: true
            ])

        XCTAssertTrue(config.isWrapperSDK)
        XCTAssertFalse(config.isWrapperScreenAutoCaptureEnabled)
        XCTAssertTrue(config.isWrapperInteractionAutoCaptureEnabled)
    }

    func testWrapperAdditionalPropertiesHelpersDetectSupportedWrappersOnly() {
        let reactNativeConfig = Userpilot.Config(token: "TOKEN")
            .additionalProperties([WrapperSDKConstants.pluginType: WrapperSDKConstants.pluginTypeReactNative])
        let ionicConfig = Userpilot.Config(token: "TOKEN")
            .additionalProperties([WrapperSDKConstants.pluginType: WrapperSDKConstants.pluginTypeIonic])
        let unknownConfig = Userpilot.Config(token: "TOKEN")
            .additionalProperties([WrapperSDKConstants.pluginType: "Expo"])

        XCTAssertTrue(reactNativeConfig.isWrapperSDK)
        XCTAssertTrue(ionicConfig.isWrapperSDK)
        XCTAssertFalse(unknownConfig.isWrapperSDK)
    }
}

private extension Array where Element: Hashable {
    func asSet() -> Set<Element> {
        Set(self)
    }
}
