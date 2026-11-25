//
//  UserpilotElementSelector.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines identities shared by native and wrapper targeting strategies.
//

import Foundation

/// Immutable identity supplied by a native or wrapper targeting strategy.
/// Keep only values here: Builder may serialize the selector on its background save queue.
/// Matching runs on main; selectors must not retain native views or the SDK instance.
@objc public protocol UserpilotElementSelector: AnyObject {
    /// Builder properties that the same strategy can inflate when an experience is received.
    func toMap() -> [String: String]

    /// Positive scores match; higher is more specific. Zero means no match.
    func evaluateMatch(_ target: UserpilotElementSelector) -> Int
}
