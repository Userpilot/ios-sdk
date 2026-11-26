//
//  SwiftUIViewRecord.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Records reflected view titles and weak hosts for interactive title matching.
//

import UIKit
import SwiftUI

internal struct SwiftUIViewRecord: CustomStringConvertible {
    let title: String
    let viewType: String   // "Button" | "NavigationLink" | "Text" | "UserpilotLabel" | <type>
    let depth: Int
    let order: Int         // pre-order traversal index
    /// Identifies the source for single-host refreshes without retaining its screen.
    weak var host: UIViewController?

    /// View types that represent a tappable control. Stage B intersects
    /// display-list text against the titles of these records.
    static let interactiveTypes: Set<String> = [
        "Button", "NavigationLink", "Toggle", "Menu", "Link", "UserpilotLabel"
    ]

    var isInteractive: Bool { Self.interactiveTypes.contains(viewType) }

    var description: String { "[\(order) d=\(depth)] \(viewType): \"\(title)\"" }
}
