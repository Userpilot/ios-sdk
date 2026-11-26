//
//  String+CaptureResolution.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Bounds captured host text while preserving its existing normalization rules.
//

import Foundation

// MARK: - Captured text bounding

internal extension String {

    /// Normalizes captured host text for publishing: every run of whitespace/newlines becomes a
    /// single space, and anything past `Constants.AutoCapture.maxTargetTextLength` is cut and
    /// suffixed with `Constants.AutoCapture.targetTextTruncationSuffix`.
    ///
    /// Captured text is arbitrary host content — a cell can render a whole JSON document — so it
    /// is bounded before it reaches a payload.
    func userpilotBoundedText() -> String {
        let collapsed = split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        guard collapsed.count > Constants.AutoCapture.maxTargetTextLength else { return collapsed }
        let keep = Constants.AutoCapture.maxTargetTextLength
            - Constants.AutoCapture.targetTextTruncationSuffix.count
        return collapsed.prefix(keep) + Constants.AutoCapture.targetTextTruncationSuffix
    }
}
