//
//  UserpilotConfig+Extensions.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/06/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
//  Config helpers for wrapper SDKs that pass extra setup flags through
//  `Userpilot.Config.additionalProperties`.
//
// 

import Foundation

internal extension Userpilot.Config {
    /// `true` when this config belongs to a supported wrapper SDK integration.
    ///
    /// Wrapper SDKs, such as React Native, Flutter, and Ionic, pass
    /// `WrapperSDKConstants.pluginType` through `additionalProperties` so the
    /// native SDK can skip UIKit swizzling and accept wrapper-provided
    /// autocapture events instead.
    var isWrapperSDK: Bool {
        additionalProperties.hasPropertyValue(
            WrapperSDKConstants.pluginType,
            expectedValue: WrapperSDKConstants.pluginTypeReactNative
        ) ||
        additionalProperties.hasPropertyValue(
            WrapperSDKConstants.pluginType,
            expectedValue: WrapperSDKConstants.pluginTypeIonic
        ) ||
        additionalProperties.hasPropertyValue(
            WrapperSDKConstants.pluginType,
            expectedValue: WrapperSDKConstants.pluginTypeFlutter
        )
    }

    /// `true` when the wrapper layer is responsible for screen autocapture.
    var isWrapperScreenAutoCaptureEnabled: Bool {
        additionalProperties.hasPropertyValue(
            WrapperSDKConstants.enableScreenAutoCapture,
            expectedValue: true
        )
    }

    /// `true` when the wrapper layer is responsible for interaction autocapture.
    var isWrapperInteractionAutoCaptureEnabled: Bool {
        additionalProperties.hasPropertyValue(
            WrapperSDKConstants.enableInteractionAutoCapture,
            expectedValue: true
        )
    }
}
