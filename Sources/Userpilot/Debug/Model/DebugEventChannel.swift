//
//  DebugEventChannel.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// Destination tab for a debugger event.
internal enum DebugEventChannel: CaseIterable {
    case manual
    case autoCapture
    case internalSDK
}
