//
//  WrapperSDKConstants.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Configuration keys shared with wrapper integrations.
//

/// Keys used by wrapper SDKs (React Native, Flutter, Ionic) in `additionalProperties`.
internal enum WrapperSDKConstants {
    static let pluginType = "PluginType"
    static let pluginTypeReactNative = "ReactNative"
    static let pluginTypeFlutter = "Flutter"
    static let pluginTypeIonic = "Ionic"
    static let pluginTypeCordova = "Cordova"
    static let pluginTypeMAUI = "MAUI"
    static let enableScreenAutoCapture = "WrapperEnableScreenAutoCapture"
    static let enableInteractionAutoCapture = "WrapperEnableInteractionAutoCapture"
}
