//
//  UPLogger.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  `Logging` wrapper that prepends `[<token>]` to every SDK log line.
//

import Foundation
import os.log

/**
 Logging protocol to log SDK logs
 */
internal protocol Logging {
    func debug(_ message: StaticString, _ args: CVarArg...)
    func info(_ message: StaticString, _ args: CVarArg...)
    func log(_ message: StaticString, _ args: CVarArg...)
    func error(_ message: StaticString, _ args: CVarArg...)
    func fault(_ message: StaticString, _ args: CVarArg...)
}

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
/// * Keeps the fixed token prefix and existing formatting for ordinary messages.
/// * A message containing an explicit private argument is forwarded as a private
///   message. Pre-formatting combines its arguments into one String, so protecting
///   that whole String keeps private values out of the public log without parsing
///   or rewriting printf arguments.
internal final class UPLogger: Logging {

    private let underlyingLog: OSLog
    private let token: String

    /// Fixed format string used when forwarding to `os_log` so the per-message
    /// token prefix is always present without callers having to construct it.
    static func prefixedFormat(for message: StaticString) -> StaticString {
        "\(message)".contains("%{private}") ? "[%{public}@] %{private}@" : "[%{public}@] %{public}@"
    }

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
            os_log(Self.prefixedFormat(for: message), log: underlyingLog, type: type, token, formatted)
        }
    }

    /// Renders `message` + `args` to a `String`, stripping OSLog privacy
    /// annotations (`{public}` / `{private}`) so `String(format:)` understands
    /// the format specifiers.
    static func formattedMessage(_ message: StaticString, args: [CVarArg]) -> String {
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
