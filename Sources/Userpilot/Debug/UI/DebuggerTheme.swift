//
//  DebuggerTheme.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

/// Visual tokens and copy for the in-app debugger. Matches the Android overlay.
enum DebuggerTheme {
    static let brand = UIColor(red: 103 / 255, green: 101 / 255, blue: 232 / 255, alpha: 1)
    static let dim = UIColor(red: 0, green: 0, blue: 0, alpha: 0x99 / 255)
    static let surface = UIColor.white
    static let text = UIColor.black
    static let icon = UIColor(red: 12 / 255, green: 3 / 255, blue: 16 / 255, alpha: 1)
    static let secondary = UIColor(red: 101 / 255, green: 101 / 255, blue: 103 / 255, alpha: 1)
    static let headerBackground = UIColor(red: 235 / 255, green: 235 / 255, blue: 235 / 255, alpha: 1)
    static let divider = UIColor.black.withAlphaComponent(0.1)

    static let panelCorner: CGFloat = 16
    static let panelMargin: CGFloat = 12
    static let panelHeightFraction: CGFloat = 0.92
    static let fadeDuration: TimeInterval = 0.2
    static let fabSize: CGFloat = 56
    static let fabMargin: CGFloat = 16
    static let fabInitialYFraction: CGFloat = 0.72
}

enum DebuggerStrings {
    static let panelTitle = "Debugger"
    static let fabLabel = "UP"
    static let fabAccessibility = "Open Userpilot debugger"
    static let closeAccessibility = "Close debugger panel"
    static let tabConfig = "Config"
    static let tabUser = "User"
    static let tabManual = "Manual"
    static let tabAuto = "Auto"
    static let tabSDK = "SDK"
    static let emptyEvents = "No events yet"
    static let copied = "Copied"
}
