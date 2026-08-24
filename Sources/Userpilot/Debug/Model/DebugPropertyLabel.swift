//
//  DebugPropertyLabel.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// Turns snake_case debugger keys into short labels for the Config tab.
enum DebugPropertyLabel {
    static func humanize(_ key: String) -> String {
        let parts = key.split { $0 == "_" || $0 == "-" }.map(String.init)
        guard !parts.isEmpty else { return key }
        return parts.enumerated().map { index, part in
            let lower = part.lowercased()
            if Self.acronyms.contains(lower) {
                return lower.uppercased()
            }
            if index > 0 && Self.smallWords.contains(lower) {
                return lower
            }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }

    private static let acronyms: Set<String> = [
        "sdk", "apns", "fcm", "url", "id", "ui", "ios", "api", "nps", "os"
    ]

    private static let smallWords: Set<String> = [
        "and", "or", "of", "the", "from", "to"
    ]
}
