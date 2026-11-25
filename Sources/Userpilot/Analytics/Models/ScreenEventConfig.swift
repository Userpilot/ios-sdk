//
//  ScreenEventConfig.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines ScreenEventConfig and its related feature models.
//

import Foundation

/// Flags for one screen request; reload intent remains on that event while it waits in the queue.
internal struct ScreenEventConfig {
    let startSession: Bool
    let isFakeReload: Bool
}
