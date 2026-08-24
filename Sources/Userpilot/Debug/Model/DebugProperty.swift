//
//  DebugProperty.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// Flattened key/value row shown in config, user, and event-detail lists.
internal struct DebugProperty: Equatable {
    let key: String
    let value: String
}

/// Named group of `DebugProperty` rows.
internal struct DebugSection: Equatable {
    let title: String
    let rows: [DebugProperty]
}

/// Immutable snapshot consumed by a debugger list tab.
internal struct DebugSnapshot: Equatable {
    let sections: [DebugSection]

    func toListItems() -> [DebugListItem] {
        guard !sections.isEmpty else { return [] }
        var items: [DebugListItem] = []
        items.reserveCapacity(sections.reduce(0) { $0 + $1.rows.count + 1 })
        for section in sections {
            items.append(.header(section.title))
            for row in section.rows {
                items.append(.row(key: row.key, value: row.value))
            }
        }
        return items
    }
}

/// Single-pass config/user list item.
internal enum DebugListItem: Equatable {
    case header(String)
    case row(key: String, value: String)
}
