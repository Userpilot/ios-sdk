//
//  DebugEventChannel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Destination tab for a debugger event.
//

import Foundation

/// Destination tab for a debugger event.
internal enum DebugEventChannel: CaseIterable {
    case manual
    case autoCapture
    case internalSDK
}
