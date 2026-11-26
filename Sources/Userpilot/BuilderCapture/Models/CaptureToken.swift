//
//  CaptureToken.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Holds the short-lived Builder capture credential in memory and keeps it out of every description.
//

import Foundation

/// Short-lived Builder credential from the capture link. Memory only; never logged, stored or printed.
/// The raw value leaves this type only through `bearerHeader()`, which the remote source sends.
internal final class CaptureToken {
    private let value: String

    /// Nil for a missing or blank value, which makes the capture link invalid.
    init?(_ value: String?) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.value = value
    }

    /// The `Authorization` header value for the capture upload request.
    func bearerHeader() -> String {
        "Bearer \(value)"
    }
}

// MARK: - Equality

/// Compares by value so identical deferred links collapse into one pending deep-link action.
extension CaptureToken: Hashable {
    static func == (lhs: CaptureToken, rhs: CaptureToken) -> Bool {
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

// MARK: - Redacted descriptions

extension CaptureToken: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String { "CaptureToken(<redacted>)" }
    var debugDescription: String { description }
    /// `dump` and debugger mirrors would otherwise list the stored value.
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
