//
//  ElementMatch.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines ElementMatch and its related feature models.
//

import UIKit

// MARK: - Element Match

/// One scoring candidate produced by a selector match.
internal struct ElementMatch {

    /// The matched node.
    let node: ElementNode

    /// Summed weight of the properties that matched. Always greater than zero.
    let score: Int
}
