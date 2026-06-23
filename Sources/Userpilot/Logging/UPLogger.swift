//
//  UPLogger.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// `Logging` wrapper that prepends `[<token>]` to every SDK log line.
//

import Foundation
import os.log

/// `Logging` wrapper that prepends `[<token>]` to every SDK log line.
///
/// Centralizes multi-tenant log tagging: callers keep using `logger.info(...)`,
/// `logger.error(...)`, etc. without knowing about the token, but in the
/// console every line is unambiguously attributed to the Userpilot instance
/// that produced it. Each `Userpilot.Config` builds its own logger via
/// `logging(enabled:)`, so two Userpilot instances in the same process get
/// two distinct tag prefixes for free.
///
/// Implementation notes:
/// * Forwards into the underlying `OSLog` through a fixed `[%{public}@] %{public}@`
///   format string, with the token + the pre-formatted user message as the
///   two args. This is the only way to inject a runtime prefix while keeping
///   `os_log`'s `StaticString` contract.
/// * Pre-formats the caller's `message`/`args` into a runtime `String` using
///   `String(format:arguments:)`. OSLog privacy modifiers (`%{public}@`,
///   `%{private}@`) are stripped to their plain counterparts because
///   `String(format:)` doesn't understand them; the SDK logs only emit
///   `%{public}` markers so no production privacy guarantee is lost.
internal final class UPLogger: Logging {

    private let underlyingLog: OSLog
    private let token: String

    /// Fixed format string used when forwarding to `os_log` so the per-message
    /// token prefix is always present without callers having to construct it.
    private static let prefixedFormat: StaticString = "[%{public}@] %{public}@"

    init(category: String, token: String) {
        self.underlyingLog = OSLog(userpilotCategory: category)
        self.token = token
    }

    func debug(_ message: StaticString, _ args: CVarArg...) {
        forward(message, type: .debug, args: args)
    }

    func info(_ message: StaticString, _ args: CVarArg...) {
        forward(message, type: .info, args: args)
    }

    func log(_ message: StaticString, _ args: CVarArg...) {
        forward(message, type: .default, args: args)
    }

    func error(_ message: StaticString, _ args: CVarArg...) {
        forward(message, type: .error, args: args)
    }

    func fault(_ message: StaticString, _ args: CVarArg...) {
        forward(message, type: .fault, args: args)
    }

    private func forward(
        _ message: StaticString,
        type: OSLogType,
        args: [CVarArg]
    ) {
        tryCatch {
            let formatted = Self.formattedMessage(message, args: args)
            os_log(Self.prefixedFormat, log: underlyingLog, type: type, token, formatted)
        }
    }

    /// Renders `message` + `args` to a `String`, stripping OSLog privacy
    /// annotations (`{public}` / `{private}`) so `String(format:)` understands
    /// the format specifiers.
    private static func formattedMessage(_ message: StaticString, args: [CVarArg]) -> String {
        let raw = "\(message)"
        if args.isEmpty {
            return raw
        }
        let template = raw
            .replacingOccurrences(of: "%{public}", with: "%")
            .replacingOccurrences(of: "%{private}", with: "%")
        return String(format: template, arguments: args)
    }
}
